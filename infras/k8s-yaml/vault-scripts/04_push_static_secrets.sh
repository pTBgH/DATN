#!/bin/bash
# ==========================================
# Script 4: Push static secrets lên Vault
# ==========================================

set -euo pipefail

if [ ! -f vault-prod-init.json ]; then
  echo "ERROR: Không tìm thấy vault-prod-init.json"
  exit 1
fi

ROOT_TOKEN=$(python3 -c "import json; print(json.load(open('vault-prod-init.json'))['root_token'])")

run_vault() {
  kubectl exec -n vault vault-0 -- \
    env \
      VAULT_SKIP_VERIFY=true \
      VAULT_ADDR=https://127.0.0.1:8200 \
      VAULT_TOKEN="$ROOT_TOKEN" \
    sh -c "$1"
}

echo "==> [1/6] Common secrets (dùng chung tất cả services)..."
run_vault "vault kv put secret/laravel-common \
  APP_KEY='base64:V0sAjegVX3yTmM/z+zEsMjYbksjNhHcJxqhV6wKAGNs='"
echo "    ✔ laravel-common OK"

echo "==> [2/6] Communication service secrets..."
run_vault "vault kv put secret/communication-service \
  MAIL_PASSWORD='rscd zhzf uvad ecot'"
echo "    ✔ communication-service OK"

echo "==> [3/6] Identity service secrets..."
run_vault "vault kv put secret/identity-service \
  LARAVEL_INTERNAL_API_SECRET='ABC123XYZ'"
echo "    ✔ identity-service OK"

echo "==> [4/6] Storage service secrets..."
run_vault "vault kv put secret/storage-service \
  MINIO_KEY='minioadmin' \
  MINIO_SECRET='minioadmin' \
  NEXTJS_INTERNAL_API_SECRET='ABC123XYZ'"
echo "    ✔ storage-service OK"

echo "==> [5/8] OAuth2 Proxy secrets..."
run_vault "vault kv put secret/oauth2-proxy \
  client-secret='8iAntNwXzjJUSbw1m1tHpM3JigJUTeAE' \
  cookie-secret='v92UDXzSJJZhKAldJT9M76rSH4MSGxTyWu9sbL-F8jg='"
echo "    ✔ oauth2-proxy OK"

# ZTA: Read passwords from Kubernetes Secret (generated at deploy time)
MYSQL_ROOT_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.mysql-root-password}' | base64 -d)
KC_ADMIN_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.keycloak-admin-password}' | base64 -d)
VAULT_MGR_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.vault-manager-password}' | base64 -d)

echo "==> [6/8] Keycloak secrets (from K8s Secret)..."
run_vault "vault kv put secret/keycloak \
  db-password='${MYSQL_ROOT_PASS}' \
  admin-password='${KC_ADMIN_PASS}'"
echo "    ✔ keycloak OK"

echo "==> [7/8] MySQL root password (from K8s Secret)..."
run_vault "vault kv put secret/mysql \
  root-password='${MYSQL_ROOT_PASS}'"
echo "    ✔ mysql OK"

echo "==> [8/8] Vault manager credentials (from K8s Secret)..."
run_vault "vault kv put secret/vault-manager \
  username='vault_manager' \
  password='${VAULT_MGR_PASS}'"
echo "    ✔ vault-manager OK"

echo ""
echo "==> Tất cả static secrets đã push lên Vault!"
