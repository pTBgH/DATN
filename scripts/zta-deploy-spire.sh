#!/usr/bin/env bash
# scripts/zta-deploy-spire.sh
#
# Deploy SPIRE (SPIFFE Runtime Environment) for workload attestation.
# Replaces "long-lived ServiceAccount tokens" with short-lived SVIDs
# (X.509 / JWT) issued via the SPIFFE Workload API.
#
# Lifts CISA ZTMM Devices: Initial → Advanced.
#
# Usage:
#   bash scripts/zta-deploy-spire.sh                # install (auto-recovers
#                                                   # from broken state)
#   bash scripts/zta-deploy-spire.sh --uninstall    # remove all
#   bash scripts/zta-deploy-spire.sh --crds-only    # apply ClusterSPIFFEID
#   bash scripts/zta-deploy-spire.sh --reset        # force helm uninstall +
#                                                   # PVC delete before install
#
# Prerequisites:
#   - kubectl, helm
#   - StorageClass available (Kind has 'standard' by default)
#   - ZTA labels applied (PR #9) — ClusterSPIFFEID podSelector uses cilium.zta/*
#
# Resource budget (4-node Kind):
#   spire-server:                200-300m CPU / 256-384Mi RAM
#   spire-agent (DS, 4 nodes):   50-200m × 4 / 96-192Mi × 4 (~0.4-0.8Gi RAM)
#   spire-controller-manager:    50-200m / 96-192Mi
#   spiffe-csi-driver (DS):      20-100m × 4 / 32-64Mi × 4
#   ─────────────────────────────────────────────────────
#   Total:                       ~700m-1.5 CPU, ~700Mi-1.2Gi RAM
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"

NAMESPACE="${SPIRE_NAMESPACE:-spire}"
HELM_REPO_URL="https://spiffe.github.io/helm-charts-hardened/"
HELM_REPO_NAME="spiffe-hardened"
SPIRE_CRDS_CHART="${HELM_REPO_NAME}/spire-crds"
SPIRE_CHART="${HELM_REPO_NAME}/spire"
VALUES_FILE="$SCRIPT_DIR/infras/k8s-yaml/spire/values.yaml"
CLUSTER_SPIFFE_IDS="$SCRIPT_DIR/infras/k8s-yaml/spire/cluster-spiffe-ids.yaml"

UNINSTALL=0
CRDS_ONLY=0
RESET=0

for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --crds-only) CRDS_ONLY=1 ;;
    --reset) RESET=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

ensure_spire_tokenreview_rbac() {
  local server_sa="${SPIRE_SERVER_SA:-spire-server}"

  blue "    Ensuring spire-server can create TokenReview requests..."
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: zta-spire-server-tokenreview
rules:
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create", "get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: zta-spire-server-tokenreview
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: zta-spire-server-tokenreview
subjects:
- kind: ServiceAccount
  name: ${server_sa}
  namespace: ${NAMESPACE}
EOF

  if ! kubectl auth can-i create tokenreviews.authentication.k8s.io \
      --as="system:serviceaccount:${NAMESPACE}:${server_sa}" >/dev/null; then
    red "  ✗ spire-server ServiceAccount still cannot create tokenreviews"
    red "    Check: kubectl get clusterrolebinding zta-spire-server-tokenreview -o yaml"
    exit 1
  fi
}

blue "============================================================"
blue " ZTA Step 2.3.8 — SPIRE Workload Attestation"
blue "   namespace:    $NAMESPACE"
blue "   trustDomain:  zta.job7189"
blue "   clusterName:  kind-job7189"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/6] Removing ClusterSPIFFEID resources..."
  kubectl delete -f "$CLUSTER_SPIFFE_IDS" --ignore-not-found 2>&1 | sed 's/^/    /' || true

  yellow "[2/6] Uninstalling spire helm release..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q '^spire\s'; then
    helm uninstall spire -n "$NAMESPACE" || true
  fi

  yellow "[3/6] Uninstalling spire-crds helm release..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q '^spire-crds\s'; then
    helm uninstall spire-crds -n "$NAMESPACE" || true
  fi

  yellow "[4/6] Force-deleting orphan SPIRE pods (helm uninstall sometimes leaves CrashLoop pods alive)..."
  kubectl -n "$NAMESPACE" delete pod --all --grace-period=0 --force --ignore-not-found 2>/dev/null || true

  yellow "[5/6] Removing leftover PVC + helm hook jobs..."
  kubectl -n "$NAMESPACE" delete pvc --all --ignore-not-found 2>/dev/null || true
  kubectl -n "$NAMESPACE" delete job --all --ignore-not-found 2>/dev/null || true

  yellow "[6/6] Removing namespace..."
  kubectl delete ns "$NAMESPACE" --ignore-not-found

  green "✓ SPIRE removed"
  exit 0
fi

# ---------------------------------------------------------------
# CRDs-only path (re-apply ClusterSPIFFEID after editing)
# ---------------------------------------------------------------
if [ "$CRDS_ONLY" -eq 1 ]; then
  blue "[1/1] Applying ClusterSPIFFEID resources..."
  kubectl apply -f "$CLUSTER_SPIFFE_IDS"
  green "✓ ClusterSPIFFEID applied"
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

blue "[0/5] Pre-flight: cluster RAM check (SPIRE wants ~700Mi-1.2Gi total)..."
require_host_ram_mi "${SPIRE_REQUIRED_HOST_MI:-1500}" "spire" || {
  red "  ✗ host VM has insufficient available RAM for spire"
  red "    Run scripts/free-ram-for-tetragon.sh first, or set ZTA_HOST_RAM_CHECK_FATAL=0 to bypass."
  exit 1
}
require_node_ram_mi "${SPIRE_REQUIRED_NODE_MI:-450}" "spire" || {
  red "  ✗ at least one node has insufficient free RAM for spire"
  red "    Run scripts/free-ram-for-tetragon.sh first, or set ZTA_RAM_CHECK_FATAL=0 to bypass."
  exit 1
}

blue "[1/5] Adding helm repo: spiffe helm-charts-hardened..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null 2>&1 || true
wait_for_dns spiffe.github.io
helm_repo_update_retry "$HELM_REPO_NAME"

blue "[2/5] Installing spire-crds (CRDs first — ClusterSPIFFEID etc.)..."
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
ensure_spire_tokenreview_rbac
helm upgrade --install spire-crds "$SPIRE_CRDS_CHART" \
  -n "$NAMESPACE" \
  --wait --timeout="${SPIRE_CRDS_HELM_TIMEOUT:-600s}"

# Recover from a previous failed install: chart leaves orphan ConfigMaps when
# install fails (e.g. namespace mismatch), which then break helm upgrade with
# "release: failed" status. Uninstall stale release before re-install.
#
# Use `helm list -o json` + jq for robust parsing — the human-readable table
# format has a multi-word UPDATED column ("2026-05-01 14:13:47.000 +0000 UTC")
# which fooled the previous awk-based parser. Also `helm list -o json` is
# stable across helm v3.x while the long-form `--all` flag has been observed
# to be rejected on some helm builds with "Error: unknown flag: --all" — use
# the short form `-a` which has been valid since helm v3.0.
#
# We do NOT redirect stderr to /dev/null on this command. If helm itself
# fails (network, kubeconfig, RBAC), set -euo pipefail will halt the script
# AND the error will be visible in the caller's log instead of being silently
# swallowed (which is what hid the real failure during the 2026-05-01 rebuild).
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for SPIRE deploy (used to parse 'helm list -o json')" >&2
  echo "       install with: sudo apt-get install -y jq" >&2
  exit 1
fi
SPIRE_RELEASE_STATUS=$(helm list -n "$NAMESPACE" -a -o json \
  | jq -r '.[] | select(.name=="spire") | .status' \
  | head -1)
SPIRE_SERVER_HEALTHY=1
if kubectl -n "$NAMESPACE" get statefulset spire-server >/dev/null 2>&1; then
  SPIRE_SERVER_READY=$(kubectl -n "$NAMESPACE" get statefulset spire-server \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  SPIRE_SERVER_DESIRED=$(kubectl -n "$NAMESPACE" get statefulset spire-server \
    -o jsonpath='{.status.replicas}' 2>/dev/null)
  if [ "${SPIRE_SERVER_READY:-0}" != "${SPIRE_SERVER_DESIRED:-1}" ]; then
    SPIRE_SERVER_HEALTHY=0
  fi
fi

# Drop any pre-upgrade hook job left from a previous failed run — helm refuses
# to re-run a hook job that already terminated unsuccessfully and will block
# the entire upgrade with "pre-upgrade hooks failed: ... Job Failed."
for hook_job in spire-server-pre-upgrade spire-agent-pre-upgrade; do
  if kubectl -n "$NAMESPACE" get job "$hook_job" >/dev/null 2>&1; then
    yellow "    cleaning up stale helm hook job $NAMESPACE/$hook_job"
    kubectl -n "$NAMESPACE" delete job "$hook_job" --ignore-not-found 2>/dev/null || true
  fi
done

NEEDS_RESET=0
if [ "$RESET" -eq 1 ]; then
  NEEDS_RESET=1
elif echo "$SPIRE_RELEASE_STATUS" | grep -qE '^(failed|pending-install|pending-upgrade|uninstalling)$'; then
  yellow "    detected stale '$SPIRE_RELEASE_STATUS' 'spire' release — cleaning up before re-install"
  NEEDS_RESET=1
elif [ "$SPIRE_RELEASE_STATUS" = "deployed" ] && [ "$SPIRE_SERVER_HEALTHY" -eq 0 ]; then
  yellow "    'spire' release is 'deployed' but spire-server StatefulSet is not Ready"
  yellow "    helm pre-upgrade hooks will fail against an unhealthy server — performing clean reinstall"
  NEEDS_RESET=1
fi

if [ "$NEEDS_RESET" -eq 1 ]; then
  helm uninstall spire -n "$NAMESPACE" 2>/dev/null || true
  # Remove orphan ConfigMaps left by failed install
  kubectl -n "$NAMESPACE" delete cm -l app.kubernetes.io/managed-by=Helm --ignore-not-found 2>/dev/null || true
  # Clear leftover spire-server PVC so the statefulset boots a clean trust store
  kubectl -n "$NAMESPACE" delete pvc -l app.kubernetes.io/name=spire-server --ignore-not-found 2>/dev/null || true
  # Force-remove any stuck pod so the new StatefulSet can take its place quickly
  kubectl -n "$NAMESPACE" delete pod -l app.kubernetes.io/name=spire-server --grace-period=0 --force --ignore-not-found 2>/dev/null || true
  sleep 5
fi

blue "[3/5] Installing spire (server + agent + controller-manager)..."
# --cleanup-on-fail: if a chart resource (Job hook, StatefulSet) fails to
# come Ready in time, helm cleans up the partially-applied manifest set
# instead of leaving orphan pods/PVCs that block subsequent re-runs.
helm upgrade --install spire "$SPIRE_CHART" \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait --cleanup-on-fail \
  --timeout="${SPIRE_HELM_TIMEOUT:-1500s}" || {
  red "  ✗ helm install/upgrade failed — common causes:"
  red "      1. namespaces 'spire-system'/'spire-server' not found"
  red "         → ensure values.yaml sets global.spire.namespaces.{system,server}.name=$NAMESPACE"
  red "      2. PVC not bound (missing default StorageClass)"
  red "         → kubectl get sc; expect rancher.io/local-path on Kind"
  red "      3. Image pull rate-limited"
  red "         → kubectl -n $NAMESPACE describe pod | grep -i 'image'"
  echo
  kubectl -n "$NAMESPACE" get pod
  echo
  yellow "  Recover with:"
  yellow "    bash scripts/zta-deploy-spire.sh --reset       # auto cleanup + reinstall"
  yellow "    bash scripts/zta-deploy-spire.sh --uninstall   # full removal then re-run install"
  exit 1
}

blue "[4/5] Waiting for spire-server StatefulSet rollout..."
kubectl -n "$NAMESPACE" rollout status statefulset/spire-server --timeout=480s || {
  red "  ✗ spire-server rollout failed"
  kubectl -n "$NAMESPACE" describe pod -l app.kubernetes.io/name=spire-server | tail -30
  exit 1
}
kubectl -n "$NAMESPACE" rollout status daemonset/spire-agent --timeout=480s || true
green "    ✓ spire-server + spire-agent ready"

blue "[5/5] Applying ClusterSPIFFEID workload identity rules..."
sleep 5     # give controller-manager a moment to register CRDs
kubectl apply -f "$CLUSTER_SPIFFE_IDS"

# Brief wait for controller-manager to register entries with spire-server
sleep 8

green "============================================================"
green " ✓ SPIRE installed"
green "============================================================"
echo
echo "Verify:"
echo "  kubectl -n $NAMESPACE get pod"
echo "  kubectl -n $NAMESPACE get clusterspiffeid"
echo "  kubectl -n $NAMESPACE exec -it statefulset/spire-server -- /opt/spire/bin/spire-server entry show -socketPath /tmp/spire-server/private/api.sock"
echo
echo "List SVIDs issued:"
echo "  kubectl -n $NAMESPACE logs -l app.kubernetes.io/name=spire-controller-manager --tail=20 | grep -i 'spiffe://'"
echo
echo "Run 09-verify-zta.sh — Test 4i checks SPIRE health."
