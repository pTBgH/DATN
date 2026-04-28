#!/usr/bin/env bash
# scripts/zta-deploy-hubble-export.sh
#
# Deploy Hubble flow → Elasticsearch sink (PR #21).
#
# Two phases (cilium patch is now OPT-IN):
#   A. (--enable-cilium-export only) Patch cilium-config to enable
#      hubble-export-file (writes JSON flows to
#      /var/run/cilium/hubble/events.log on each node), restart cilium DS.
#   B. Apply filebeat DaemonSet that reads that file and ships to ES.
#
# IMPORTANT — cilium DS restart is risky on Kind cluster (4 nodes, slow
# rollout, can cascade control-plane CrashLoopBackOff). Default behavior:
# DEPLOY SHIPPER ONLY. The user must explicitly opt-in to the cilium
# patch via --enable-cilium-export. If the rollout fails, we automatically
# revert the patch.
#
# Usage:
#   bash scripts/zta-deploy-hubble-export.sh                        # shipper only (default)
#   bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export # full pipeline
#   bash scripts/zta-deploy-hubble-export.sh --uninstall            # remove
#
# Environment:
#   ES_NS=monitoring  (default; ES from PR #7 lives in ns 'monitoring', NOT 'data')
#   ES_HOST=elasticsearch.monitoring.svc.cluster.local:9200
#   ES_SERVICE=elasticsearch  (override if ES service has a different name)
#   CILIUM_NS=kube-system
#   SHIPPER_NS=monitoring
#
# Resource budget:
#   - Cilium agents: +negligible CPU, ~10Mi extra RAM (hubble export buffer)
#   - filebeat DS:   ~30m CPU / 96-192Mi RAM × 4 nodes = ~400-800Mi total
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

CILIUM_NS="${CILIUM_NS:-kube-system}"
SHIPPER_NS="${SHIPPER_NS:-monitoring}"
ES_NS="${ES_NS:-monitoring}"
ES_SERVICE="${ES_SERVICE:-elasticsearch}"
ES_HOST="${ES_HOST:-${ES_SERVICE}.${ES_NS}.svc.cluster.local:9200}"
HUBBLE_EXPORT_PATH="/var/run/cilium/hubble/events.log"
MANIFESTS_DIR="$SCRIPT_DIR/infras/k8s-yaml/hubble-export"
CILIUM_ROLLOUT_TIMEOUT="${CILIUM_ROLLOUT_TIMEOUT:-600s}"

UNINSTALL=0
ENABLE_CILIUM_EXPORT=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --enable-cilium-export) ENABLE_CILIUM_EXPORT=1 ;;
    --shipper-only) ;;  # back-compat: this is the default now
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \?//'; exit 0 ;;
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
blue "   mode:        $([ "$ENABLE_CILIUM_EXPORT" -eq 1 ] && echo 'cilium-export + shipper' || echo 'shipper-only (cilium patch skipped)')"
blue "============================================================"

set_cilium_serial_rollout() {
  yellow "    Ensuring cilium DS rolls one node at a time (maxUnavailable=1)..."
  kubectl -n "$CILIUM_NS" patch ds cilium --type=merge -p '{
    "spec": {
      "updateStrategy": {
        "type": "RollingUpdate",
        "rollingUpdate": {
          "maxUnavailable": 1
        }
      }
    }
  }' 2>&1 | sed 's/^/    /'
}

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

  yellow "[3/3] Restarting cilium DS (this may take 5-10 min)..."
  set_cilium_serial_rollout
  kubectl -n "$CILIUM_NS" rollout restart ds cilium
  yellow "    NOTE: not waiting for rollout — let it complete in background."
  yellow "    Check: kubectl -n $CILIUM_NS rollout status ds cilium"
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
if kubectl -n "$ES_NS" get svc "$ES_SERVICE" >/dev/null 2>&1; then
  green "    ✓ Elasticsearch service found at $ES_HOST"
else
  yellow "    ⚠ Elasticsearch service '$ES_SERVICE' not found in ns '$ES_NS'."
  yellow "      Override with ES_NS / ES_SERVICE env vars."
  yellow "      filebeat will retry indefinitely; check kubectl -n $SHIPPER_NS logs ds/hubble-flow-shipper later."
fi

# ---------------------------------------------------------------
# Phase A: enable hubble-export in cilium-config (OPT-IN only)
# ---------------------------------------------------------------
revert_cilium_patch() {
  red "  → Reverting cilium-config patch to recover cluster..."
  kubectl -n "$CILIUM_NS" patch cm cilium-config --type=json -p '[
    {"op":"remove","path":"/data/hubble-export-file-path"},
    {"op":"remove","path":"/data/hubble-export-file-max-size-mb"},
    {"op":"remove","path":"/data/hubble-export-file-max-backups"}
  ]' 2>/dev/null || true
  set_cilium_serial_rollout
  kubectl -n "$CILIUM_NS" rollout restart ds cilium 2>&1 | sed 's/^/    /' || true
  red "    cilium-config reverted; cilium DS restarting in background."
  red "    Wait for rollout: kubectl -n $CILIUM_NS rollout status ds cilium"
}

if [ "$ENABLE_CILIUM_EXPORT" -eq 1 ]; then
  blue "[A/3] Patching cilium-config: enable hubble-export-file..."
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
)" 2>&1 | sed 's/^/    /'

    blue "[A2/3] Restarting cilium DS to pick up new config (timeout: $CILIUM_ROLLOUT_TIMEOUT)..."
    yellow "    NOTE: 4-node restart can cascade control-plane CrashLoop briefly."
    set_cilium_serial_rollout
    yellow "    NOTE: If it doesn't recover after $CILIUM_ROLLOUT_TIMEOUT, the patch will be reverted."
    kubectl -n "$CILIUM_NS" rollout restart ds cilium

    if ! kubectl -n "$CILIUM_NS" rollout status ds cilium --timeout="$CILIUM_ROLLOUT_TIMEOUT"; then
      red "  ✗ cilium rollout did not complete within $CILIUM_ROLLOUT_TIMEOUT"
      red "    Common causes:"
      red "      - cilium-operator stuck (kubectl -n $CILIUM_NS describe pod -l io.cilium/app=operator)"
      red "      - control-plane stuck waiting for CNI (kube-controller-manager / kube-scheduler CrashLoop)"
      red "      - hubble-export-file-path option unsupported by this Cilium version"
      revert_cilium_patch
      exit 1
    fi
    green "    ✓ cilium DS restarted with hubble export enabled"
  fi
else
  yellow "[A/3] Skipping cilium-config patch (default; pass --enable-cilium-export to enable)"
  yellow "       The filebeat shipper will deploy but find no events.log until cilium is patched."
fi

# ---------------------------------------------------------------
# Phase B: deploy filebeat shipper
# ---------------------------------------------------------------
blue "[B/3] Applying filebeat shipper manifests..."
# Patch ES_HOST into the configmap on the fly (envsubst-style)
kubectl apply -f "$MANIFESTS_DIR/00-namespace-and-rbac.yaml" 2>&1 | sed 's/^/    /'
ES_HOST_ESCAPED=$(echo "$ES_HOST" | sed 's,/,\\/,g')
sed "s,elasticsearch.data.svc.cluster.local:9200,$ES_HOST,g" "$MANIFESTS_DIR/10-configmap.yaml" \
  | kubectl apply -f - 2>&1 | sed 's/^/    /'
kubectl apply -f "$MANIFESTS_DIR/20-daemonset.yaml" 2>&1 | sed 's/^/    /'

blue "[B2/3] Waiting for filebeat DaemonSet rollout..."
if ! kubectl -n "$SHIPPER_NS" rollout status ds hubble-flow-shipper --timeout=300s; then
  red "  ✗ filebeat rollout did not complete"
  red "    Check: kubectl -n $SHIPPER_NS describe ds hubble-flow-shipper"
  red "           kubectl -n $SHIPPER_NS logs ds/hubble-flow-shipper --tail=40"
  exit 1
fi

green "============================================================"
green " ✓ Hubble flow sink deployed"
green "============================================================"
echo
echo "Verify hubble-config (if --enable-cilium-export was used):"
echo "  kubectl -n $CILIUM_NS get cm cilium-config -o jsonpath='{.data.hubble-export-file-path}'"
echo "  kubectl -n $CILIUM_NS exec ds/cilium -c cilium-agent -- ls -la /var/run/cilium/hubble/"
echo
echo "Verify filebeat → ES:"
echo "  kubectl -n $SHIPPER_NS logs ds/hubble-flow-shipper --tail=20 | grep -i 'connection\\|publish'"
echo "  kubectl -n $ES_NS exec es-0 -- curl -s http://localhost:9200/_cat/indices/hubble-flows-*"
echo
if [ "$ENABLE_CILIUM_EXPORT" -eq 0 ]; then
  yellow "NOTE: cilium-config NOT patched. To complete the pipeline:"
  yellow "      bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export"
fi
echo
echo "Run 09-verify-zta.sh — Test 4l checks pipeline health."
