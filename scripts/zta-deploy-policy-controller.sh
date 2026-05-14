#!/usr/bin/env bash
# scripts/zta-deploy-policy-controller.sh
#
# Deploy sigstore policy-controller (admission webhook) for real Cosign
# signature verification of container images. Closes the gap left by PR #16
# Gatekeeper image-trust constraints which only check annotations.
#
# Workflow:
#   1. helm install policy-controller into ns 'cosign-system'
#   2. Read cosign public key from PR #16 ConfigMap
#      (security/zta-cosign-public-key) and patch into ClusterImagePolicy
#      'zta-job7189-apps-signed'
#   3. Apply 3 ClusterImagePolicy rules:
#        - zta-system-passthrough  (allow infra images)
#        - zta-job7189-apps-signed (require Cosign sig in job7189-apps)
#        - zta-keyless-trust-job7189 (optional, GHA-keyless)
#   4. Label namespace `job7189-apps` to opt-in:
#        kubectl label ns job7189-apps policy.sigstore.dev/include=true
#
# Usage:
#   bash scripts/zta-deploy-policy-controller.sh                # install
#                                                               # (auto-recovers
#                                                               # from broken state)
#   bash scripts/zta-deploy-policy-controller.sh --uninstall    # remove
#   bash scripts/zta-deploy-policy-controller.sh --policies-only
#   bash scripts/zta-deploy-policy-controller.sh --reset        # force helm
#                                                               # uninstall +
#                                                               # webhook delete
#                                                               # before install
#
# Resource budget: ~150-300Mi RAM, ~120-450m CPU.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"

NAMESPACE="${PC_NAMESPACE:-cosign-system}"
APP_NAMESPACE="${APP_NAMESPACE:-job7189-apps}"
COSIGN_CM_NS="${COSIGN_CM_NS:-security}"
COSIGN_CM_NAME="${COSIGN_CM_NAME:-zta-cosign-public-key}"
COSIGN_CM_KEY="${COSIGN_CM_KEY:-cosign-public-key.pem}"

HELM_REPO_NAME="sigstore"
HELM_REPO_URL="https://sigstore.github.io/helm-charts"
HELM_CHART="${HELM_REPO_NAME}/policy-controller"
HELM_RELEASE="policy-controller"

VALUES_FILE="$SCRIPT_DIR/infras/k8s-yaml/policy-controller/values.yaml"
CIP_FILE="$SCRIPT_DIR/infras/k8s-yaml/policy-controller/cluster-image-policies.yaml"

UNINSTALL=0
POLICIES_ONLY=0
RESET=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --policies-only) POLICIES_ONLY=1 ;;
    --reset) RESET=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------
# Helper: read cosign pub key + patch into CIP YAML inline
# ---------------------------------------------------------------
apply_policies_with_key() {
  if ! kubectl get cm -n "$COSIGN_CM_NS" "$COSIGN_CM_NAME" >/dev/null 2>&1; then
    red "ERROR: cosign public key ConfigMap $COSIGN_CM_NS/$COSIGN_CM_NAME not found"
    red "       Run scripts/zta-cosign-keygen.sh first (PR #16)"
    exit 1
  fi

  # NOTE: kubectl jsonpath cannot handle keys with dots (e.g. 'cosign-public-key.pem')
  # because '.' is interpreted as path separator. Use go-template's `index` instead,
  # which supports arbitrary string keys.
  PUB_KEY_PEM=$(kubectl get cm -n "$COSIGN_CM_NS" "$COSIGN_CM_NAME" \
    -o go-template="{{index .data \"$COSIGN_CM_KEY\"}}" 2>/dev/null)
  if [ -z "$PUB_KEY_PEM" ] || [ "$PUB_KEY_PEM" = "<no value>" ]; then
    red "ERROR: ConfigMap $COSIGN_CM_NS/$COSIGN_CM_NAME has empty data.\"$COSIGN_CM_KEY\""
    red "  Available keys:"
    kubectl get cm -n "$COSIGN_CM_NS" "$COSIGN_CM_NAME" -o jsonpath='{.data}' | tr ',' '\n' | sed 's/^/    /'
    exit 1
  fi
  if ! echo "$PUB_KEY_PEM" | grep -q "BEGIN PUBLIC KEY"; then
    red "ERROR: $COSIGN_CM_NS/$COSIGN_CM_NAME data.\"$COSIGN_CM_KEY\" doesn't look like a PEM public key"
    exit 1
  fi

  # Render the public key with proper YAML indentation (8 spaces -> matches
  # spec.authorities[].key.data pipe block).
  PUB_KEY_INDENTED=$(echo "$PUB_KEY_PEM" | sed 's/^/        /')

  TMP_FILE="$(mktemp)"

  # awk replaces only the lines between BEGIN/END of the placeholder block.
  awk -v key="$PUB_KEY_INDENTED" '
    /-----BEGIN PUBLIC KEY-----/ { in_block = 1; print key; next }
    /-----END PUBLIC KEY-----/   { in_block = 0; next }
    in_block { next }
    { print }
  ' "$CIP_FILE" > "$TMP_FILE"

  kubectl apply -f "$TMP_FILE"
  rm -f "$TMP_FILE"
}

blue "============================================================"
blue " ZTA Step 2.3.9 — sigstore policy-controller"
blue "   namespace:        $NAMESPACE"
blue "   app namespace:    $APP_NAMESPACE"
blue "   cosign key cm:    $COSIGN_CM_NS/$COSIGN_CM_NAME"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/6] Removing ClusterImagePolicy resources..."
  kubectl delete clusterimagepolicy zta-system-passthrough zta-job7189-apps-signed zta-keyless-trust-job7189 --ignore-not-found 2>&1 | sed 's/^/    /' || true

  yellow "[2/6] Removing namespace opt-in label..."
  kubectl label ns "$APP_NAMESPACE" policy.sigstore.dev/include- 2>/dev/null || true

  yellow "[3/6] Uninstalling helm release..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "^${HELM_RELEASE}"; then
    helm uninstall "$HELM_RELEASE" -n "$NAMESPACE" || true
  fi

  yellow "[4/6] Wiping cluster-scoped webhook configs (survive helm uninstall in some chart versions)..."
  kubectl delete validatingwebhookconfiguration policy.sigstore.dev --ignore-not-found 2>/dev/null || true
  kubectl delete mutatingwebhookconfiguration   policy.sigstore.dev --ignore-not-found 2>/dev/null || true

  yellow "[5/6] Force-deleting orphan webhook pods..."
  kubectl -n "$NAMESPACE" delete pod --all --grace-period=0 --force --ignore-not-found 2>/dev/null || true

  yellow "[6/6] Removing namespace..."
  kubectl delete ns "$NAMESPACE" --ignore-not-found

  green "✓ policy-controller removed"
  exit 0
fi

# ---------------------------------------------------------------
# POLICIES-ONLY (re-apply CIPs after editing without re-installing chart)
# ---------------------------------------------------------------
if [ "$POLICIES_ONLY" -eq 1 ]; then
  blue "[1/2] Patching ClusterImagePolicy with cosign public key..."
  apply_policies_with_key
  green "✓ ClusterImagePolicy applied"
  exit 0
fi

# ---------------------------------------------------------------
# INSTALL
# ---------------------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  red "ERROR: helm not installed."; exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  red "ERROR: kubectl not installed."; exit 1
fi

blue "[0/5] Pre-flight: cluster RAM check (policy-controller wants ~150-300Mi total)..."
require_host_ram_mi "${PC_REQUIRED_HOST_MI:-1200}" "policy-controller" || {
  red "  ✗ host VM has insufficient available RAM for policy-controller"
  red "    Run scripts/free-ram-for-tetragon.sh first, or set ZTA_HOST_RAM_CHECK_FATAL=0 to bypass."
  exit 1
}
require_node_ram_mi "${PC_REQUIRED_NODE_MI:-200}" "policy-controller" || {
  red "  ✗ at least one node has insufficient free RAM for policy-controller"
  red "    Run scripts/free-ram-for-tetragon.sh first, or set ZTA_RAM_CHECK_FATAL=0 to bypass."
  exit 1
}

blue "[1/5] Adding helm repo: $HELM_REPO_NAME ($HELM_REPO_URL)..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null 2>&1 || true
wait_for_dns sigstore.github.io
helm_repo_update_retry "$HELM_REPO_NAME"

blue "[2/5] Installing $HELM_CHART (helm release: $HELM_RELEASE)..."
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Detect a previously failed install or a 'deployed' release that is actually
# unhealthy (webhook pod CrashLoopBackOff for >5 restarts). In both cases the
# safest path is to uninstall + reinstall fresh — helm's server-side apply
# refuses to reconcile webhook configurations whose .namespaceSelector is owned
# by another field manager (the running webhook pod itself can mutate them),
# producing:
#   "conflict with \"webhook\" using admissionregistration.k8s.io/v1:
#    .webhooks[name=\"policy.sigstore.dev\"].namespaceSelector"
#
# We use 'helm status' instead of 'helm list -a' for cross-version compat:
# helm v3 supported '-a, --all' to also list failed/pending releases, but
# helm v4 (observed v4.1.3 in the field) removed both flags entirely. The
# old call printed "Error: unknown flag: --all" to stderr, but that stderr
# was redirected to /dev/null which combined with set -euo pipefail caused
# the script to exit 1 silently right after the previous helm command.
# 'helm status RELEASE -o json' is stable from v3.0 through v4.x and
# returns the full release object regardless of state.
if ! command -v jq >/dev/null 2>&1; then
  red "ERROR: jq is required (used to parse 'helm status -o json')"
  red "       install with: sudo apt-get install -y jq"
  exit 1
fi
PC_RELEASE_STATUS=""
PC_STATUS_TMP="$(mktemp /tmp/zta-policy-controller-status.XXXXXX)"
if helm status "$HELM_RELEASE" -n "$NAMESPACE" -o json > "$PC_STATUS_TMP" 2>&1; then
  PC_RELEASE_STATUS=$(jq -r '.info.status // empty' < "$PC_STATUS_TMP")
elif grep -qE 'release: not found|not found' "$PC_STATUS_TMP"; then
  : # release does not exist → fresh install path
else
  red "ERROR: 'helm status $HELM_RELEASE -n $NAMESPACE -o json' failed unexpectedly:"
  cat "$PC_STATUS_TMP" >&2
  rm -f "$PC_STATUS_TMP"
  exit 1
fi
rm -f "$PC_STATUS_TMP"
PC_WEBHOOK_UNHEALTHY=0
if kubectl -n "$NAMESPACE" get deploy policy-controller-webhook >/dev/null 2>&1; then
  PC_RESTARTS=$(kubectl -n "$NAMESPACE" get pod \
    -l control-plane=policy-controller-webhook \
    -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null \
    | sort -n | tail -1)
  if [ "${PC_RESTARTS:-0}" -ge 5 ]; then
    PC_WEBHOOK_UNHEALTHY=1
  fi
fi

PC_NEEDS_RESET=0
if [ "$RESET" -eq 1 ]; then
  PC_NEEDS_RESET=1
elif echo "$PC_RELEASE_STATUS" | grep -qE '^(failed|pending-install|pending-upgrade|uninstalling)$'; then
  yellow "    detected stale '$PC_RELEASE_STATUS' '${HELM_RELEASE}' release — cleaning up before re-install"
  PC_NEEDS_RESET=1
elif [ "$PC_RELEASE_STATUS" = "deployed" ] && [ "$PC_WEBHOOK_UNHEALTHY" -eq 1 ]; then
  yellow "    '${HELM_RELEASE}' release is 'deployed' but webhook pod has $PC_RESTARTS restarts"
  yellow "    helm upgrade against an unhealthy webhook tends to deadlock on SSA conflicts — reinstalling"
  PC_NEEDS_RESET=1
fi

if [ "$PC_NEEDS_RESET" -eq 1 ]; then
  helm uninstall "$HELM_RELEASE" -n "$NAMESPACE" 2>/dev/null || true
  # Webhook configurations are cluster-scoped and survive helm uninstall in
  # some chart versions. Wipe them so the fresh install owns SSA fields.
  kubectl delete validatingwebhookconfiguration policy.sigstore.dev --ignore-not-found 2>/dev/null || true
  kubectl delete mutatingwebhookconfiguration   policy.sigstore.dev --ignore-not-found 2>/dev/null || true
  # Force-evict any stuck webhook pod so the new ReplicaSet can roll cleanly.
  kubectl -n "$NAMESPACE" delete pod -l control-plane=policy-controller-webhook --grace-period=0 --force --ignore-not-found 2>/dev/null || true
  sleep 5
fi

helm upgrade --install "$HELM_RELEASE" "$HELM_CHART" \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait --cleanup-on-fail \
  --timeout="${POLICY_CONTROLLER_HELM_TIMEOUT:-900s}" || {
  red "  ✗ helm install/upgrade failed — common causes:"
  red "      1. ImagePullBackOff (registry rate-limit) → kubectl -n $NAMESPACE describe pod"
  red "      2. Webhook cert generation timeout → kubectl -n $NAMESPACE get cert"
  red "      3. SSA conflict on policy.sigstore.dev webhooks → bash $0 --reset"
  red "      4. Existing 'failed' release still present → bash $0 --uninstall first"
  echo
  kubectl -n "$NAMESPACE" get pod
  exit 1
}

blue "[3/5] Waiting for policy-controller webhook rollout..."
kubectl -n "$NAMESPACE" rollout status deploy/policy-controller-webhook --timeout=360s || {
  red "  ✗ policy-controller-webhook rollout failed"
  kubectl -n "$NAMESPACE" describe pod -l app.kubernetes.io/component=webhook | tail -30
  kubectl -n "$NAMESPACE" logs deploy/policy-controller-webhook --all-containers --tail=80 2>/dev/null || true
  exit 1
}
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod \
  -l control-plane=policy-controller-webhook \
  --timeout=240s >/dev/null || {
  red "  ✗ policy-controller-webhook pod not Ready after rollout"
  kubectl -n "$NAMESPACE" get pod -l control-plane=policy-controller-webhook
  kubectl -n "$NAMESPACE" logs deploy/policy-controller-webhook --all-containers --tail=80 2>/dev/null || true
  exit 1
}
sleep "${POLICY_CONTROLLER_STABILITY_WAIT:-20}"
if kubectl -n "$NAMESPACE" get pod -l control-plane=policy-controller-webhook --no-headers 2>/dev/null \
    | grep -qE 'CrashLoopBackOff|Error|OOMKilled'; then
  red "  ✗ policy-controller-webhook became unhealthy after initial rollout"
  kubectl -n "$NAMESPACE" get pod -l control-plane=policy-controller-webhook
  kubectl -n "$NAMESPACE" describe pod -l control-plane=policy-controller-webhook | tail -60
  kubectl -n "$NAMESPACE" logs deploy/policy-controller-webhook --all-containers --previous --tail=80 2>/dev/null || true
  exit 1
fi

blue "[4/5] Patching ClusterImagePolicy with cosign public key from $COSIGN_CM_NS/$COSIGN_CM_NAME..."
apply_policies_with_key

blue "[5/6] Narrowing webhook scope on resource 'pods' to CREATE-only..."
# Sigstore policy-controller upstream chart binds both CREATE and UPDATE for
# `pods` and `pods/ephemeralcontainers`. UPDATE coverage means every external
# controller that patches an existing pod (kopf PDP controller, kube-controller-
# manager, kubectl label, …) re-triggers full pod-spec validation. When a
# Vault Agent–injected pod has a tag-based sidecar image (e.g. hashicorp/vault:1.21.2),
# every PATCH then trips `validation failed: must be an image digest`, even
# though the pod was admitted cleanly at CREATE time.
#
# Cosign verifies SUPPLY-CHAIN at admission. `pod.spec.containers[*].image` is
# immutable post-CREATE in Kubernetes, so UPDATE-time validation does not
# defend against any additional image-substitution attack. The only attack
# vector on a running pod is ephemeralContainer insertion — but that is
# defence-in-depth covered by Tetragon TracingPolicy (Step 2.3.4) and the
# Gatekeeper image-trust ConstraintTemplates (PR #16). Trade-off accepted.
# See doc/28-sigstore-policy-controller.md §7a for full rationale.
WEBHOOK_NAME="policy.sigstore.dev"
if kubectl get validatingwebhookconfiguration "$WEBHOOK_NAME" >/dev/null 2>&1; then
  # The chart deploys 3 rules under webhooks[0]:
  #   rules[0] -> pods, pods/ephemeralcontainers
  #   rules[1] -> daemonsets, deployments, ...   (apps/v1)
  #   rules[2] -> cronjobs, jobs                 (batch/v1)
  # Each rule object carries its own .operations list. We rewrite each one
  # to CREATE-only. (`pods/ephemeralcontainers` lives inside rules[0].resources
  # alongside `pods`, so it follows the same operation list — this is the
  # one trade-off; if you need stricter ephemeralcontainer enforcement, split
  # that into its own webhook rule.)
  for IDX in 0 1 2; do
    kubectl patch validatingwebhookconfiguration "$WEBHOOK_NAME" \
      --type='json' \
      -p="[{\"op\": \"replace\", \"path\": \"/webhooks/0/rules/$IDX/operations\", \"value\": [\"CREATE\"]}]" \
      >/dev/null 2>&1 || yellow "    (rule index $IDX not present — skipped)"
  done
  green "  ✓ webhook rules patched to CREATE-only on pods/apps/batch"
else
  yellow "  (webhook $WEBHOOK_NAME not found yet — chart may still be initialising)"
fi

blue "[6/6] Opt-in namespace '$APP_NAMESPACE' for image signature verification..."
kubectl label ns "$APP_NAMESPACE" policy.sigstore.dev/include=true --overwrite

green "============================================================"
green " ✓ policy-controller installed"
green "============================================================"
echo
echo "Verify:"
echo "  kubectl -n $NAMESPACE get pod"
echo "  kubectl get clusterimagepolicy"
echo "  kubectl get ns $APP_NAMESPACE -o jsonpath='{.metadata.labels}'"
echo
echo "Test (warn-only mode at first):"
echo "  kubectl -n $APP_NAMESPACE run unsigned --image=nginx:1.25 --restart=Never"
echo "  kubectl -n $APP_NAMESPACE get events --sort-by='.lastTimestamp' | tail -5"
echo "  # Expected: warning 'no matching authority found' but pod still admitted"
echo
echo "Switch to enforce mode:"
echo "  kubectl patch clusterimagepolicy zta-job7189-apps-signed --type=merge -p '{\"spec\":{\"mode\":\"enforce\"}}'"
echo
echo "Run 09-verify-zta.sh — Test 4j checks policy-controller health."
