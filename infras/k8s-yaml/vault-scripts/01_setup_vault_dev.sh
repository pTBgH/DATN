#!/bin/bash
# ==========================================
# Script 1: Setup vault-dev (Transit Engine)
# Chạy 1 lần sau mỗi khi vault-dev restart
# ==========================================

set -e

VAULT_DEV_ADDR="http://vault-dev.vault.svc.cluster.local:8300"
VAULT_DEV_TOKEN="vault-dev-root-token"

echo "==> Chờ vault-dev sẵn sàng..."
until kubectl exec -n vault deploy/vault-dev -- \
  wget -qO- http://127.0.0.1:8300/v1/sys/health > /dev/null 2>&1; do
  echo "    vault-dev chưa ready, đợi 3s..."
  sleep 3
done
echo "    vault-dev ready!"

echo "==> Enable Transit secrets engine..."
kubectl exec -n vault deploy/vault-dev -- \
  sh -c "VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=vault-dev-root-token \
  vault secrets enable transit 2>/dev/null || echo '    Transit đã enable rồi'"

echo "==> Tạo Transit key cho vault-prod..."
kubectl exec -n vault deploy/vault-dev -- \
  sh -c "VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=vault-dev-root-token \
  vault write -f transit/keys/vault-prod-unseal-key 2>/dev/null || echo '    Key đã tồn tại rồi'"

echo "==> vault-dev setup hoàn tất!"
