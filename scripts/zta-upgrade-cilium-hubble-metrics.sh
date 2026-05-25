#!/usr/bin/env bash
# =============================================================================
# zta-upgrade-cilium-hubble-metrics.sh
#
# Phase 3 (PR-Q): upgrade existing Cilium release to enable Hubble Prometheus
# metrics with the labelsContext required by the Tier-2 alerts in
# `infras/k8s-yaml/prometheus-rules.yaml`:
#
#   - ZTACiliumCrossTierDropZScore (source_namespace + destination_namespace)
#   - ZTAHubbleDNSExfilSuspect     (source_namespace + query length)
#   - ZTAHubbleEgressToThreatCIDR  (destination=reserved:world, traffic_direction=EGRESS)
#
# Without these labels, the metrics either don't exist or carry only `protocol`
# + `reason` (chart default) — alerts that reference source_namespace etc fire
# never.
#
# Why a dedicated script:
#   - `01-setup-cluster.sh` calls `helm upgrade --install ... --reuse-values`
#     which IGNORES `-f cilium-values.yaml` on existing clusters. So merely
#     editing the values file does NOT change anything on a running cluster.
#   - This script does a one-shot `helm upgrade` (NO --reuse-values) that
#     forces the new values file to be applied. Subsequent runs of
#     `01-setup-cluster.sh` will also pick up the change because the release
#     state then includes hubble.metrics.* in its stored values.
#
# Safety:
#   - Backs up current values to /tmp/cilium-values-backup-<ts>.yaml before
#     the upgrade.
#   - Rolling restart of cilium-agent DaemonSet (Cilium's safe upgrade path).
#     Pod-to-pod traffic is briefly affected only during the per-node restart
#     (~10s per node, sequential).
#   - On failure, prints the rollback command.
#
# Usage:
#   bash scripts/zta-upgrade-cilium-hubble-metrics.sh         # full upgrade
#   bash scripts/zta-upgrade-cilium-hubble-metrics.sh --check # dry-run, no changes
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES_FILE="$SCRIPT_DIR/k8s-management/cilium/cilium-values.yaml"
TIMESTAMP=$(date +%s)
BACKUP_FILE="/tmp/cilium-values-backup-${TIMESTAMP}.yaml"

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
blue()   { printf "\033[34m%s\033[0m\n" "$*"; }

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
blue "[pre-flight] Verifying Helm + Cilium release state..."

if ! command -v helm >/dev/null; then
  red "helm not found in PATH"; exit 1
fi
if ! command -v kubectl >/dev/null; then
  red "kubectl not found in PATH"; exit 1
fi

if [ ! -f "$VALUES_FILE" ]; then
  red "values file not found: $VALUES_FILE"; exit 1
fi

if ! helm -n kube-system status cilium >/dev/null 2>&1; then
  red "Cilium release 'cilium' is not installed in namespace kube-system."
  red "Run 01-setup-cluster.sh first (full install)."
  exit 1
fi

CHART_VERSION=$(helm -n kube-system list -o json | python3 -c "
import json,sys
for r in json.load(sys.stdin):
  if r['name']=='cilium': print(r['chart']); break
" || echo "unknown")
green "  Cilium release found: chart=$CHART_VERSION"

# ---------------------------------------------------------------------------
# Confirm Hubble metrics actually missing today
# ---------------------------------------------------------------------------
blue "[pre-flight] Probe current Hubble metrics state..."
PROBE_OUTPUT=$(helm -n kube-system get values cilium -o yaml 2>/dev/null | python3 -c "
import sys, yaml
try:
    d = yaml.safe_load(sys.stdin)
except Exception:
    print('  YAML parse error on helm get values'); sys.exit(0)
hubble_metrics = (d or {}).get('hubble', {}).get('metrics', {}) if isinstance(d, dict) else {}
if isinstance(hubble_metrics, dict) and hubble_metrics.get('enabled'):
    enabled_list = hubble_metrics.get('enabled')
    print(f'  ALREADY ENABLED: hubble.metrics.enabled is set to {enabled_list}')
    sys.exit(2)
else:
    print('  hubble.metrics NOT enabled on current release (expected)')
")
echo "$PROBE_OUTPUT"
PROBE_EXIT=$?
if [ "$PROBE_EXIT" -eq 2 ]; then
  yellow "  Hubble metrics already configured. Re-applying values to ensure labelsContext is correct."
fi

# ---------------------------------------------------------------------------
# Backup current values
# ---------------------------------------------------------------------------
blue "[backup] Saving current release values to $BACKUP_FILE..."
helm -n kube-system get values cilium -a -o yaml > "$BACKUP_FILE"
green "  Backup written ($(wc -l <"$BACKUP_FILE") lines)"

# ---------------------------------------------------------------------------
# Dry-run / Apply
# ---------------------------------------------------------------------------
blue "[upgrade] Computing rendered diff..."
helm -n kube-system upgrade cilium cilium/cilium \
  --version "${CILIUM_VERSION:-}" \
  -f "$VALUES_FILE" \
  --dry-run \
  --debug 2>/dev/null \
  | grep -E '^\+|hubble.metrics|cilium-config|9965' \
  | head -40 || true

if [ "$CHECK_ONLY" -eq 1 ]; then
  green "[--check] Dry-run only. No changes applied. Backup retained at $BACKUP_FILE"
  exit 0
fi

blue "[upgrade] Applying new values (helm upgrade WITHOUT --reuse-values)..."
echo "  This will rolling-restart cilium-agent DaemonSet (sequential, ~10s/node)."
echo "  Press Ctrl+C in the next 5 seconds to abort."
sleep 5

if helm -n kube-system upgrade cilium cilium/cilium \
  -f "$VALUES_FILE" \
  --wait --timeout 10m; then
  green "  Helm upgrade succeeded"
else
  red "  Helm upgrade FAILED. Roll back with:"
  red "    helm -n kube-system upgrade cilium cilium/cilium -f $BACKUP_FILE --wait --timeout 10m"
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify hubble metrics endpoint
# ---------------------------------------------------------------------------
blue "[verify] Probe hubble metrics endpoint on a cilium-agent pod..."
sleep 10
POD=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
if kubectl -n kube-system exec "$POD" -c cilium-agent -- curl -sf --max-time 5 http://127.0.0.1:9965/metrics 2>/dev/null \
   | grep -c '^hubble_' \
   | python3 -c "
import sys
n = int(sys.stdin.read().strip() or 0)
print(f'  Hubble metric series found: {n}')
if n == 0:
    sys.exit(1)
"; then
  green "  Hubble metrics endpoint healthy (port 9965)"
else
  yellow "  Hubble /metrics on :9965 returned 0 series. Check:"
  yellow "    kubectl -n kube-system exec $POD -c cilium-agent -- curl -v http://127.0.0.1:9965/metrics"
fi

# ---------------------------------------------------------------------------
# Reload Prometheus to pick up new scrape job (08-prometheus.yaml updated)
# ---------------------------------------------------------------------------
blue "[verify] Applying updated Prometheus scrape config (cilium-hubble job)..."
if kubectl apply -f "$SCRIPT_DIR/infras/k8s-yaml/08-prometheus.yaml" >/dev/null 2>&1; then
  green "  08-prometheus.yaml applied"
  kubectl -n monitoring rollout restart deployment/prometheus >/dev/null 2>&1 || true
  kubectl -n monitoring rollout status deployment/prometheus --timeout=120s >/dev/null 2>&1 || true
  green "  Prometheus restarted"
else
  yellow "  Failed to re-apply 08-prometheus.yaml. Apply manually:"
  yellow "    kubectl apply -f $SCRIPT_DIR/infras/k8s-yaml/08-prometheus.yaml"
fi

green ""
green "Done. Verify the Phase 3 alerts now have data:"
green "  PROM=\$(kubectl -n monitoring get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')"
green "  kubectl -n monitoring exec \$PROM -- wget -qO- 'http://localhost:9090/api/v1/series?match[]=hubble_drop_total' | head -5"
green ""
green "Backup of pre-upgrade values: $BACKUP_FILE"
