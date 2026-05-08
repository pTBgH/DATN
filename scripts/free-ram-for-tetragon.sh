#!/bin/bash
# =============================================================================
# free-ram-for-tetragon.sh
# Free cluster + host RAM before deploying Tetragon (script 10).
#
# Strategy (in order, most-to-least reversible):
#   1) Toggle non-essential UIs off    (Kibana, Grafana, phpMyAdmin)
#   2) Scale vault-dev to 0 replicas   (only needed for vault-prod auto-unseal)
#   3) Drop Filebeat per-pod limit     (in-place container resize, no restart)
#   4) Trim node page cache            (drop_caches=1, host-level)
#
# Usage:
#   ./scripts/free-ram-for-tetragon.sh           # default: 600Mi target
#   FREE_RAM_TARGET_MI=800 ./scripts/free-ram-for-tetragon.sh
#   FREE_RAM_AGGRESSIVE=1 ./scripts/free-ram-for-tetragon.sh   # also drop_caches
#
# Idempotent. Each step prints what it did or skipped.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FREE_RAM_TARGET_MI="${FREE_RAM_TARGET_MI:-600}"
FREE_RAM_AGGRESSIVE="${FREE_RAM_AGGRESSIVE:-0}"

avail_mi() { free -m | awk '/^Mem:/ {print $7}'; }

echo ""
echo "=== free-ram-for-tetragon.sh — target ${FREE_RAM_TARGET_MI}Mi available ==="

CURRENT=$(avail_mi)
echo "   Current available: ${CURRENT}Mi"
if [ "$CURRENT" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo "   ✓ Already above target. Nothing to do."
  exit 0
fi

# -----------------------------------------------------------------------------
# 1) Toggle non-essential UIs off
# -----------------------------------------------------------------------------
TOGGLE="${SCRIPT_DIR}/toggle-internal-ui.sh"
if [ -x "$TOGGLE" ]; then
  echo ""
  echo "[1/4] Toggling Kibana/Grafana/phpMyAdmin off..."
  "$TOGGLE" off >/dev/null 2>&1 || true
  sleep 5
  echo "      Available now: $(avail_mi)Mi"
else
  echo "[1/4] toggle-internal-ui.sh not found — skipping"
fi

if [ "$(avail_mi)" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo ""
  echo "✓ Target reached after step 1. Done."
  exit 0
fi

# -----------------------------------------------------------------------------
# 2) Scale vault-dev to 0
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] Scaling deploy/vault-dev to 0 replicas..."
if kubectl get deploy vault-dev -n vault >/dev/null 2>&1; then
  # Sanity check: vault-prod must be unsealed first, otherwise we lose Transit unseal
  if kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
    SEALED=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('sealed', True))" 2>/dev/null || echo "true")
    if [ "$SEALED" = "False" ] || [ "$SEALED" = "false" ]; then
      kubectl scale deploy/vault-dev -n vault --replicas=0
      echo "      ✓ vault-dev scaled to 0 (vault-prod is unsealed, safe to scale down)"
      echo "      ⚠ NOTE: if vault-prod re-seals, you must scale vault-dev back up"
      sleep 5
      echo "      Available now: $(avail_mi)Mi"
    else
      echo "      ⚠ vault-prod is sealed — keeping vault-dev running"
    fi
  else
    echo "      ⚠ Cannot inspect vault-prod — skipping vault-dev scale"
  fi
else
  echo "      (vault-dev deployment not found — skipping)"
fi

if [ "$(avail_mi)" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo ""
  echo "✓ Target reached after step 2. Done."
  exit 0
fi

# -----------------------------------------------------------------------------
# 3) In-place resize Filebeat DaemonSet (lower request/limit, no restart)
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] Lowering Filebeat memory limit (200Mi → 128Mi)..."
if kubectl get ds filebeat -n monitoring >/dev/null 2>&1; then
  # patch DaemonSet spec; existing pods will pick up on next rollout, but limit
  # itself reduces kernel memcg headroom for new starts
  kubectl patch ds filebeat -n monitoring --type=json -p='[
    {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"},
    {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"64Mi"}
  ]' 2>/dev/null && echo "      ✓ Filebeat ds patched" || echo "      ⚠ Patch failed (continuing)"
  # Trigger a controlled rolling restart only if absolutely needed — not by default
  if [ "$FREE_RAM_AGGRESSIVE" = "1" ]; then
    echo "      AGGRESSIVE=1 → rolling restart Filebeat to apply new request"
    kubectl -n monitoring rollout restart ds/filebeat
    kubectl -n monitoring rollout status ds/filebeat --timeout=120s || true
  fi
  sleep 3
  echo "      Available now: $(avail_mi)Mi"
else
  echo "      (filebeat ds not found — skipping)"
fi

if [ "$(avail_mi)" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo ""
  echo "✓ Target reached after step 3. Done."
  exit 0
fi

# -----------------------------------------------------------------------------
# 4) Drop OS page cache (host-level, last resort)
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Dropping host page cache (drop_caches=1)..."
if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
  sync
  echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || \
    echo "      ⚠ Could not write to drop_caches"
  sleep 2
  echo "      Available now: $(avail_mi)Mi"
else
  echo "      ⚠ Not root and no passwordless sudo — skipping drop_caches"
fi

# -----------------------------------------------------------------------------
# Final report
# -----------------------------------------------------------------------------
FINAL=$(avail_mi)
echo ""
echo "=== Final available: ${FINAL}Mi (target ${FREE_RAM_TARGET_MI}Mi) ==="
if [ "$FINAL" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo "✓ OK — proceed with Tetragon deploy"
  exit 0
else
  echo "⚠ Below target. Tetragon may still deploy if Kind nodes have headroom"
  echo "   (each node only needs ~96Mi for Tetragon at proposed limits)."
  echo "   Check per-node allocatable: kubectl describe nodes | grep -A5 Allocated"
  exit 0   # don't fail — let caller decide
fi
