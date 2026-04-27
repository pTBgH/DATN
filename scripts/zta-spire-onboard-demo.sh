#!/usr/bin/env bash
# scripts/zta-spire-onboard-demo.sh
#
# Deploy the SPIRE workload integration demo (PR #20).
#
# Workflow:
#   1. Apply spire-demo-workload Deployment + ClusterSPIFFEID
#   2. Wait for pod Ready
#   3. Tail logs for ~30s — show SVID being fetched via Workload API
#
# Prerequisite: PR #17 SPIRE deployed (bash scripts/zta-deploy-spire.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

NAMESPACE="${NAMESPACE:-security}"
WORKLOAD_NAME="spire-demo-workload"
MANIFEST="$SCRIPT_DIR/infras/k8s-yaml/spire/spire-demo-workload.yaml"

UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Step 2.3.10 — SPIRE Workload Integration demo"
blue "   namespace:    $NAMESPACE"
blue "   workload:     $WORKLOAD_NAME"
blue "============================================================"

if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/2] Removing demo workload + ClusterSPIFFEID..."
  kubectl delete -f "$MANIFEST" --ignore-not-found 2>&1 | sed 's/^/    /'
  green "✓ removed"
  exit 0
fi

# Sanity: SPIRE installed?
if ! kubectl get statefulset -n spire spire-server >/dev/null 2>&1; then
  red "ERROR: spire-server not deployed. Run scripts/zta-deploy-spire.sh first."
  exit 1
fi
if ! kubectl get csidrivers csi.spiffe.io >/dev/null 2>&1; then
  red "ERROR: csi.spiffe.io driver not registered. spire chart probably failed."
  exit 1
fi

blue "[1/3] Applying $MANIFEST..."
kubectl apply -f "$MANIFEST"

blue "[2/3] Waiting for $WORKLOAD_NAME pod Ready..."
if ! kubectl -n "$NAMESPACE" rollout status deploy/$WORKLOAD_NAME --timeout=180s; then
  red "  ✗ rollout failed — common causes:"
  red "      1. ImagePullBackOff (ghcr.io/spiffe/spire-agent rate-limited)"
  red "         → kubectl -n $NAMESPACE describe pod -l app=$WORKLOAD_NAME"
  red "      2. CSI volume failed to mount (spiffe-csi-driver DS not Ready)"
  red "         → kubectl -n spire get pod -l app.kubernetes.io/name=spiffe-csi-driver"
  red "      3. ClusterSPIFFEID not yet processed by controller-manager"
  red "         → kubectl -n spire logs deploy/spire-spire-controller-manager --tail=20"
  exit 1
fi

blue "[3/3] Tailing logs for 30s — expect 'svid_acquired' line..."
echo
sleep 5
kubectl -n "$NAMESPACE" logs deploy/$WORKLOAD_NAME --tail=20 || true
echo
green "============================================================"
green " ✓ SPIRE workload integration demo running"
green "============================================================"
echo
echo "Verify SVID:"
echo "  kubectl -n $NAMESPACE logs deploy/$WORKLOAD_NAME --tail=10 | grep svid_acquired"
echo
echo "List SPIRE entries (parent/spiffe_id):"
echo "  kubectl -n spire exec statefulset/spire-server -c spire-server -- \\"
echo "    /opt/spire/bin/spire-server entry show \\"
echo "    -socketPath /tmp/spire-server/private/api.sock 2>&1 \\"
echo "    | grep -E 'sa/$WORKLOAD_NAME|^Entry ID|^Selector'"
echo
echo "Expected SPIFFE ID: spiffe://zta.job7189/ns/$NAMESPACE/sa/$WORKLOAD_NAME"
echo
echo "Run 09-verify-zta.sh — Test 4k checks integration health."
