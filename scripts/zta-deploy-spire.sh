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
#   bash scripts/zta-deploy-spire.sh                # install
#   bash scripts/zta-deploy-spire.sh --uninstall    # remove all
#   bash scripts/zta-deploy-spire.sh --crds-only    # apply ClusterSPIFFEID
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

for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --crds-only) CRDS_ONLY=1 ;;
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
  yellow "[1/4] Removing ClusterSPIFFEID resources..."
  kubectl delete -f "$CLUSTER_SPIFFE_IDS" --ignore-not-found 2>&1 | sed 's/^/    /' || true

  yellow "[2/4] Uninstalling spire helm release..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q '^spire\s'; then
    helm uninstall spire -n "$NAMESPACE" || true
  fi

  yellow "[3/4] Uninstalling spire-crds helm release..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q '^spire-crds\s'; then
    helm uninstall spire-crds -n "$NAMESPACE" || true
  fi

  yellow "[4/4] Removing namespace..."
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

blue "[1/5] Adding helm repo: spiffe helm-charts-hardened..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null 2>&1 || true
wait_for_dns spiffe.github.io
helm_repo_update_retry "$HELM_REPO_NAME"

blue "[2/5] Installing spire-crds (CRDs first — ClusterSPIFFEID etc.)..."
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
ensure_spire_tokenreview_rbac
helm upgrade --install spire-crds "$SPIRE_CRDS_CHART" \
  -n "$NAMESPACE" \
  --wait --timeout="${SPIRE_CRDS_HELM_TIMEOUT:-300s}"

# Recover from a previous failed install: chart leaves orphan ConfigMaps when
# install fails (e.g. namespace mismatch), which then break helm upgrade with
# "release: failed" status. Uninstall stale release before re-install.
if helm list -n "$NAMESPACE" --all 2>/dev/null | awk 'NR>1 {print $1, $8}' | grep -E '^spire (failed|pending-install|uninstalling)$' >/dev/null; then
  yellow "    detected stale failed 'spire' release — cleaning up before re-install"
  helm uninstall spire -n "$NAMESPACE" 2>/dev/null || true
  # Remove orphan ConfigMaps left by failed install
  kubectl -n "$NAMESPACE" delete cm -l app.kubernetes.io/managed-by=Helm --ignore-not-found 2>/dev/null || true
  sleep 3
fi

blue "[3/5] Installing spire (server + agent + controller-manager)..."
helm upgrade --install spire "$SPIRE_CHART" \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait --timeout="${SPIRE_HELM_TIMEOUT:-900s}" || {
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
  yellow "    bash scripts/zta-deploy-spire.sh --uninstall"
  yellow "    bash scripts/zta-deploy-spire.sh"
  exit 1
}

blue "[4/5] Waiting for spire-server StatefulSet rollout..."
kubectl -n "$NAMESPACE" rollout status statefulset/spire-server --timeout=240s || {
  red "  ✗ spire-server rollout failed"
  kubectl -n "$NAMESPACE" describe pod -l app.kubernetes.io/name=spire-server | tail -30
  exit 1
}
kubectl -n "$NAMESPACE" rollout status daemonset/spire-agent --timeout=240s || true
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
