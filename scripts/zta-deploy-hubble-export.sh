#!/usr/bin/env bash
# scripts/zta-deploy-hubble-export.sh
#
# Deploy Hubble flow → Elasticsearch sink (PR #21).
#
# Two phases:
#   A. Patch cilium-config to enable hubble-export-file (writes JSON flows
#      to /var/run/cilium/hubble/events.log on each node), restart cilium DS.
#   B. Apply filebeat DaemonSet that reads that file and ships to ES.
#
# Usage:
#   bash scripts/zta-deploy-hubble-export.sh                    # full deploy
#   bash scripts/zta-deploy-hubble-export.sh --shipper-only     # skip cilium patch
#   bash scripts/zta-deploy-hubble-export.sh --uninstall        # remove
#
# Resource budget:
#   - Cilium agents: +negligible CPU, ~10Mi extra RAM (hubble export buffer)
#   - filebeat DS:   ~30m CPU / 96-192Mi RAM × 4 nodes = ~400-800Mi total
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

CILIUM_NS="${CILIUM_NS:-kube-system}"
SHIPPER_NS="${SHIPPER_NS:-monitoring}"
ES_NS="${ES_NS:-data}"
ES_HOST="${ES_HOST:-elasticsearch.data.svc.cluster.local:9200}"
HUBBLE_EXPORT_PATH="/var/run/cilium/hubble/events.log"
MANIFESTS_DIR="$SCRIPT_DIR/infras/k8s-yaml/hubble-export"

UNINSTALL=0
SHIPPER_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --shipper-only) SHIPPER_ONLY=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Step 2.3.11 — Hubble flow → Elasticsearch sink"
blue "   ES target:   $ES_HOST"
blue "   shipper ns:  $SHIPPER_NS"
blue "   cilium ns:   $CILIUM_NS"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/3] Removing filebeat DaemonSet + ConfigMap + RBAC..."
  kubectl delete -f "$MANIFESTS_DIR" --ignore-not-found 2>&1 | sed 's/^/    /'

  yellow "[2/3] Reverting cilium-config (disable hubble export)..."
  kubectl -n "$CILIUM_NS" patch cm cilium-config --type=json -p '[
    {"op":"remove","path":"/data/hubble-export-file-path"},
    {"op":"remove","path":"/data/hubble-export-file-max-size-mb"},
    {"op":"remove","path":"/data/hubble-export-file-max-backups"}
  ]' 2>/dev/null || true

  yellow "[3/3] Restarting cilium DS..."
  kubectl -n "$CILIUM_NS" rollout restart ds cilium
  green "✓ Hubble flow sink removed"
  exit 0
fi

# ---------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------
if ! kubectl -n "$CILIUM_NS" get ds cilium >/dev/null 2>&1; then
  red "ERROR: Cilium DS not found in ns '$CILIUM_NS'."
  exit 1
fi
if ! kubectl -n "$ES_NS" get svc elasticsearch >/dev/null 2>&1; then
  yellow "WARNING: elasticsearch service not found in ns '$ES_NS'."
  yellow "         filebeat will retry indefinitely; ensure ES is reachable at $ES_HOST"
fi

# ---------------------------------------------------------------
# Phase A: enable hubble-export in cilium-config
# ---------------------------------------------------------------
if [ "$SHIPPER_ONLY" -eq 0 ]; then
  blue "[1/3] Patching cilium-config: enable hubble-export-file..."
  CURRENT_PATH=$(kubectl -n "$CILIUM_NS" get cm cilium-config \
    -o jsonpath='{.data.hubble-export-file-path}' 2>/dev/null || echo "")
  if [ "$CURRENT_PATH" = "$HUBBLE_EXPORT_PATH" ]; then
    yellow "    already enabled (hubble-export-file-path=$HUBBLE_EXPORT_PATH)"
  else
    kubectl -n "$CILIUM_NS" patch cm cilium-config --type=merge -p "$(cat <<EOF
{
  "data": {
    "hubble-export-file-path": "$HUBBLE_EXPORT_PATH",
    "hubble-export-file-max-size-mb": "10",
    "hubble-export-file-max-backups": "5"
  }
}
EOF
)"
    blue "[1b/3] Restarting cilium DS to pick up new config (~30-60s)..."
    kubectl -n "$CILIUM_NS" rollout restart ds cilium
    if ! kubectl -n "$CILIUM_NS" rollout status ds cilium --timeout=180s; then
      red "  ✗ cilium rollout did not complete — flows may not export"
      red "    Check: kubectl -n $CILIUM_NS describe ds cilium"
      exit 1
    fi
    green "    ✓ cilium DS restarted with hubble export enabled"
  fi
else
  yellow "[1/3] Skipping cilium-config patch (--shipper-only)"
fi

# ---------------------------------------------------------------
# Phase B: deploy filebeat shipper
# ---------------------------------------------------------------
blue "[2/3] Applying filebeat shipper manifests..."
kubectl apply -f "$MANIFESTS_DIR" 2>&1 | sed 's/^/    /'

blue "[3/3] Waiting for filebeat DaemonSet rollout..."
if ! kubectl -n "$SHIPPER_NS" rollout status ds hubble-flow-shipper --timeout=180s; then
  red "  ✗ filebeat rollout failed — common causes:"
  red "      1. ImagePullBackOff (docker.elastic.co/beats/filebeat)"
  red "         → kubectl -n $SHIPPER_NS describe pod -l app=hubble-flow-shipper"
  red "      2. SecurityContextConstraint blocks runAsUser=0"
  red "         → check Pod Security Admission level on $SHIPPER_NS ns"
  red "      3. ES unreachable (CNP blocking egress)"
  red "         → kubectl -n $SHIPPER_NS logs ds/hubble-flow-shipper --tail=30"
  exit 1
fi

green "============================================================"
green " ✓ Hubble flow → Elasticsearch sink deployed"
green "============================================================"
echo
echo "Verify exports flowing:"
echo "  # Each cilium agent writes flow JSON to host /var/run/cilium/hubble/events.log"
echo "  kubectl -n $CILIUM_NS exec ds/cilium -- ls -la /var/run/cilium/hubble/"
echo
echo "Verify filebeat shipping:"
echo "  kubectl -n $SHIPPER_NS logs ds/hubble-flow-shipper --tail=20 | grep -E '(elasticsearch|harvested)'"
echo
echo "Query ES index from any pod with curl:"
echo "  kubectl -n $ES_NS exec -it deploy/elasticsearch -- \\"
echo "    curl -s http://localhost:9200/_cat/indices/hubble-flows-* | head"
echo
echo "Run 09-verify-zta.sh — Test 4l checks shipper health."
