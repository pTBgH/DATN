#!/bin/bash
# ==========================================
# Script restart: Chạy sau mỗi khi cluster restart
# vault-dev mất data (dev mode) → cần recreate Transit key
# Logic:
#   - Nếu vault-prod còn PVC data + key bị mất → WARN, cần cleanup + reinit
#   - Nếu vault-prod chưa init → tạo key mới, vault-prod sẽ init sau
#   - Nếu key còn → không làm gì, vault-prod tự unseal
# ==========================================

set -euo pipefail

VAULT_DEV_TOKEN="vault-dev-root-token"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────

run_dev() {
  kubectl exec -n vault deploy/vault-dev -- \
    sh -c "VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=${VAULT_DEV_TOKEN} $1"
}

vault_prod_initialized() {
  local status
  status=$(kubectl exec -n vault vault-0 -- \
    sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
    vault status -format=json 2>/dev/null" 2>/dev/null || echo "{}")
  echo "$status" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print('yes' if d.get('initialized') else 'no')
except:
    print('no')
" 2>/dev/null || echo "no"
}

vault_prod_sealed() {
  local status
  status=$(kubectl exec -n vault vault-0 -- \
    sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
    vault status -format=json 2>/dev/null" 2>/dev/null || echo "{}")
  echo "$status" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print('yes' if d.get('sealed') else 'no')
except:
    print('yes')
" 2>/dev/null || echo "yes"
}

# ── Step 1: Chờ vault-dev ─────────────────────────────────────────────────────

echo "==> [1/4] Chờ vault-dev sẵn sàng..."
kubectl wait --for=condition=ready pod \
  -l app=vault-dev -n vault --timeout=120s
echo "    ✔ vault-dev ready"

# ── Step 2: Enable Transit ────────────────────────────────────────────────────

echo "==> [2/4] Enable Transit secrets engine trên vault-dev..."
run_dev "vault secrets enable transit 2>/dev/null || echo '    Transit đã enable'"
echo "    ✔ Transit engine OK"

# ── Step 3: Kiểm tra Transit key ─────────────────────────────────────────────

echo "==> [3/4] Kiểm tra Transit key vault-prod-unseal-key..."

KEY_JSON=$(run_dev "vault read -format=json transit/keys/vault-prod-unseal-key 2>/dev/null" || echo "")

if [ -n "$KEY_JSON" ] && echo "$KEY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('data',{}).get('name') else 1)" 2>/dev/null; then
  echo "    ✔ Transit key đã tồn tại → vault-prod sẽ tự unseal với key cũ"
  KEY_EXISTED="yes"
else
  echo "    Transit key KHÔNG tồn tại (vault-dev bị restart mất data)"
  KEY_EXISTED="no"

  # Kiểm tra vault-prod đã init chưa
  echo "    Kiểm tra vault-prod initialized status..."

  # Chờ vault-0 pod running trước khi check
  until kubectl get pod vault-0 -n vault 2>/dev/null | grep -qE "Running|Error"; do
    echo "    Chờ vault-0 pod..."
    sleep 3
  done

  PROD_INIT=$(vault_prod_initialized)

  if [ "$PROD_INIT" = "yes" ]; then
    echo ""
    echo "    ╔══════════════════════════════════════════════════════════╗"
    echo "    ║  ⚠️  CRITICAL: vault-prod đã init nhưng Transit key mất  ║"
    echo "    ║  vault-prod KHÔNG THỂ unseal với key mới                 ║"
    echo "    ║  Cần cleanup hoàn toàn và init lại từ đầu               ║"
    echo "    ╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "    Chạy theo thứ tự:"
    echo "      cd $SCRIPT_DIR"
    echo "      bash 99-fast-rebuild-vault.sh"
    echo ""
    exit 1
  else
    echo "    vault-prod chưa init → tạo key mới (lần đầu setup)"
    run_dev "vault write -f transit/keys/vault-prod-unseal-key"
    echo "    ✔ Transit key mới đã tạo"
    KEY_EXISTED="new"
  fi
fi

# ── Step 4: Chờ vault-prod unseal ─────────────────────────────────────────────

echo "==> [4/4] Chờ vault-prod unseal..."

MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  SEALED=$(vault_prod_sealed)
  INIT=$(vault_prod_initialized)

  if [ "$INIT" = "yes" ] && [ "$SEALED" = "no" ]; then
    echo "    ✔ vault-prod đã unseal và sẵn sàng!"
    break
  fi

  if [ "$INIT" = "no" ] && [ "$KEY_EXISTED" = "yes" ]; then
    echo "    vault-prod chưa init — nên chạy bash 99-fast-rebuild-vault.sh"
    break
  fi

  echo "    Chờ... (${ELAPSED}s/${MAX_WAIT}s) init=${INIT} sealed=${SEALED}"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo ""
kubectl get pod -n vault
echo ""
echo "==> Done!"

if [ "$KEY_EXISTED" = "new" ]; then
  echo ""
  echo "    Key vừa tạo mới. Tiếp theo chạy:"
  echo "      bash 99-fast-rebuild-vault.sh"
fi
