#!/bin/bash
# ==========================================
# Script 3: Setup vault-prod
# Chạy 1 lần sau khi init xong
# Cần file vault-prod-init.json từ script 02
# ==========================================

set -e

if [ ! -f vault-prod-init.json ]; then
  echo "ERROR: Không tìm thấy vault-prod-init.json"
  echo "       Chạy script 02 trước!"
  exit 1
fi

ROOT_TOKEN=$(python3 -c "import json; print(json.load(open('vault-prod-init.json'))['root_token'])")
VAULT_CMD="kubectl exec -n vault vault-0 -- sh -c"
VAULT_ENV="VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN=$ROOT_TOKEN"

echo "==> Enable K8s Auth Method..."
$VAULT_CMD "$VAULT_ENV vault auth enable kubernetes 2>/dev/null || echo 'đã enable'"

echo "==> Config K8s Auth..."
$VAULT_CMD "$VAULT_ENV vault write auth/kubernetes/config \
  kubernetes_host=https://kubernetes.default.svc \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

echo "==> Enable KV v2 secrets engine..."
$VAULT_CMD "$VAULT_ENV vault secrets enable -path=secret kv-v2 2>/dev/null || echo 'đã enable'"

echo "==> Enable Database secrets engine..."
$VAULT_CMD "$VAULT_ENV vault secrets enable database 2>/dev/null || echo 'đã enable'"

echo "==> vault-prod setup hoàn tất!"
echo "    Tiếp theo: chạy script 04 để đẩy secrets"
