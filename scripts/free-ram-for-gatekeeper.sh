#!/bin/bash
# =============================================================================
# free-ram-for-gatekeeper.sh
# Free host RAM before deploying OPA Gatekeeper (step 26).
#
# Why a separate script (not free-ram-for-tetragon.sh):
#   - Gatekeeper webhook controller-manager + audit pod ≈ 250-300 MiB.
#   - Pre-flight in zta-deploy-gatekeeper.sh requires ≥1500 MiB available
#     (rebuild_20260505_142433 OOM cascade — see incident-falco-tetragon-ram-overcommit.md).
#   - Tetragon's free-ram script also scales `vault-dev` to 0, which is too
#     aggressive for gatekeeper because the gatekeeper webhook needs Vault
#     pod stable (operator-managed certs etc.). We use a strictly safe subset.
#
# Strategy (in order, most-to-least reversible):
#   1) Toggle non-essential UIs off  (Kibana, Grafana, phpMyAdmin, Kafbat)
#   2) Trim Filebeat per-pod memory limit (in-place ds patch, no restart)
#   3) Trim host page cache          (drop_caches=1)
#
# Usage:
#   ./scripts/free-ram-for-gatekeeper.sh                 # default 1700 MiB
#   FREE_RAM_TARGET_MI=1800 ./scripts/free-ram-for-gatekeeper.sh
#
# Idempotent. Each step prints what it did or skipped. Always exits 0 so the
# caller can decide whether the new headroom is enough.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default 1700 MiB = gatekeeper pre-flight ≥1500 + 200 MiB buffer for the
# helm install / CRD apply spike + headroom for cilium-operator etc.
FREE_RAM_TARGET_MI="${FREE_RAM_TARGET_MI:-1700}"

avail_mi() { free -m | awk '/^Mem:/ {print $7}'; }

echo ""
echo "=== free-ram-for-gatekeeper.sh — target ${FREE_RAM_TARGET_MI} MiB available ==="

CURRENT=$(avail_mi)
echo "   Current available: ${CURRENT} MiB"
if [ "$CURRENT" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo "   ✓ Already above target. Nothing to do."
  exit 0
fi

# -----------------------------------------------------------------------------
# 1) Toggle non-essential UIs off  (Kibana, Grafana, phpMyAdmin, Kafbat)
# -----------------------------------------------------------------------------
TOGGLE="${SCRIPT_DIR}/toggle-internal-ui.sh"
if [ -x "$TOGGLE" ]; then
  echo ""
  echo "[1/3] Toggling Kibana / Grafana / phpMyAdmin / Kafbat off..."
  "$TOGGLE" off >/dev/null 2>&1 || true
  sleep 5
  echo "      Available now: $(avail_mi) MiB"
else
  echo "[1/3] toggle-internal-ui.sh not found — skipping"
fi

if [ "$(avail_mi)" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo ""
  echo "✓ Target reached after step 1. Done."
  exit 0
fi

# -----------------------------------------------------------------------------
# 2) Lower Filebeat per-pod memory limit  (in-place ds patch, no restart)
# -----------------------------------------------------------------------------
echo ""
echo "[2/3] Lowering Filebeat memory limit (200Mi → 128Mi)..."
if kubectl get ds filebeat -n monitoring >/dev/null 2>&1; then
  kubectl patch ds filebeat -n monitoring --type=json -p='[
    {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"},
    {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"64Mi"}
  ]' 2>/dev/null && echo "      ✓ Filebeat ds patched" || echo "      ⚠ Patch failed (continuing)"
  sleep 3
  echo "      Available now: $(avail_mi) MiB"
else
  echo "      (filebeat ds not found — skipping)"
fi

if [ "$(avail_mi)" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo ""
  echo "✓ Target reached after step 2. Done."
  exit 0
fi

# -----------------------------------------------------------------------------
# 3) Drop OS page cache  (host-level, last resort)
# -----------------------------------------------------------------------------
echo ""
echo "[3/3] Dropping host page cache (drop_caches=1)..."
if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
  sync
  echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || \
    echo "      ⚠ Could not write to drop_caches"
  sleep 2
  echo "      Available now: $(avail_mi) MiB"
else
  echo "      ⚠ Not root and no passwordless sudo — skipping drop_caches"
fi

# -----------------------------------------------------------------------------
# Final report
# -----------------------------------------------------------------------------
FINAL=$(avail_mi)
echo ""
echo "=== Final available: ${FINAL} MiB (target ${FREE_RAM_TARGET_MI} MiB) ==="
if [ "$FINAL" -ge "$FREE_RAM_TARGET_MI" ]; then
  echo "✓ OK — proceed with Gatekeeper deploy"
  echo ""
  echo "  After 26-gatekeeper + 27-pdp finish, you can re-enable the UIs:"
  echo "    bash scripts/toggle-internal-ui.sh on"
  exit 0
else
  echo "⚠ Below target — Gatekeeper pre-flight will likely refuse to install."
  echo "  Aggressive options:"
  echo "    kubectl -n data         scale sts/kafka       --replicas=0  # ~335 MiB"
  echo "    kubectl -n monitoring   scale sts/es          --replicas=0  # ~720 MiB"
  echo "  (NOT recommended — breaks audit/log pipeline. Re-scale after step 27.)"
  exit 0   # don't fail — let caller decide
fi
