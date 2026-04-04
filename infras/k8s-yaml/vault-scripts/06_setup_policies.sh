#!/bin/bash
# ==========================================
# Script 6: Setup Policies và K8s Roles
# ==========================================

set -euo pipefail

if [ ! -f vault-prod-init.json ]; then
  echo "ERROR: Không tìm thấy vault-prod-init.json"
  exit 1
fi

ROOT_TOKEN=$(python3 -c "import json; print(json.load(open('vault-prod-init.json'))['root_token'])")

# Services có DB dynamic credentials
MICROSERVICES=(
  "identity-service"
  "workspace-service"
  "job-service"
  "hiring-service"
  "candidate-service"
  "communication-service"
  "storage-service"
)

# Services có thêm static secrets riêng
declare -A EXTRA_SECRETS=(
  ["communication-service"]="secret/data/communication-service"
  ["identity-service"]="secret/data/identity-service"
  ["storage-service"]="secret/data/storage-service"
)

NAMESPACE="job7189-apps"

run_vault() {
  kubectl exec -n vault vault-0 -- \
    env \
      VAULT_SKIP_VERIFY=true \
      VAULT_ADDR=https://127.0.0.1:8200 \
      VAULT_TOKEN="$ROOT_TOKEN" \
    sh -c "$1"
}

echo "==> Check vault-0 sẵn sàng..."
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=60s
echo "    ✔ vault-0 ready"

echo "==> Check KV v2..."
KV_TYPE=$(run_vault "vault secrets list -format=json" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('secret/','').get('options',{}).get('version','1') if 'secret/' in d else 'not_found')
except:
    print('not_found')
" || echo "not_found")

if [ "$KV_TYPE" = "not_found" ]; then
  echo "    Enable KV v2..."
  run_vault "vault secrets enable -path=secret kv-v2 2>/dev/null || true"
elif [ "$KV_TYPE" = "1" ]; then
  echo "    Upgrade KV v1 → v2..."
  run_vault "vault secrets tune -path=secret -version=2 2>/dev/null || true"
fi
echo "    ✔ KV v2 OK"

echo "==> Check + Config Kubernetes auth..."
AUTH_ENABLED=$(run_vault "vault auth list -format=json" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print('yes' if 'kubernetes/' in d else 'no')
except:
    print('no')
" || echo "no")

if [ "$AUTH_ENABLED" = "no" ]; then
  run_vault "vault auth enable kubernetes"
fi

run_vault "vault write auth/kubernetes/config \
  token_reviewer_jwt=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
  kubernetes_host=https://kubernetes.default.svc \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
echo "    ✔ Kubernetes auth OK"

echo "==> [1/5] Policy cho oauth2-proxy..."
run_vault "vault policy write oauth2-proxy - <<EOF
path \"secret/data/oauth2-proxy\" {
  capabilities = [\"read\"]
}
EOF"
echo "    ✔ oauth2-proxy policy OK"

echo "==> [2/5] Policy cho keycloak..."
run_vault "vault policy write keycloak - <<EOF
path \"secret/data/keycloak\" {
  capabilities = [\"read\"]
}
EOF"
echo "    ✔ keycloak policy OK"

echo "==> [3/5] Policies cho microservices..."
for SVC in "${MICROSERVICES[@]}"; do
  echo "    → $SVC"

  EXTRA_PATH=""
  if [ -n "${EXTRA_SECRETS[$SVC]+x}" ]; then
    EXTRA_PATH="
path \"${EXTRA_SECRETS[$SVC]}\" {
  capabilities = [\"read\"]
}"
  fi

  run_vault "vault policy write $SVC - <<EOF
path \"secret/data/laravel-common\" {
  capabilities = [\"read\"]
}
path \"database/creds/$SVC\" {
  capabilities = [\"read\"]
}
$EXTRA_PATH
EOF"
  echo "    ✔ $SVC policy OK"
done

echo "==> [4/5] K8s Auth Roles cho oauth2-proxy + keycloak..."
run_vault "vault write auth/kubernetes/role/oauth2-proxy \
  bound_service_account_names=oauth2-proxy \
  bound_service_account_namespaces=security \
  policies=oauth2-proxy \
  ttl=1h max_ttl=24h"
echo "    ✔ oauth2-proxy role OK"

run_vault "vault write auth/kubernetes/role/keycloak \
  bound_service_account_names=keycloak \
  bound_service_account_namespaces=security \
  policies=keycloak \
  ttl=1h max_ttl=24h"
echo "    ✔ keycloak role OK"

echo "==> [5/5] K8s Auth Roles cho microservices..."
for SVC in "${MICROSERVICES[@]}"; do
  echo "    → $SVC"
  run_vault "vault write auth/kubernetes/role/$SVC \
    bound_service_account_names=$SVC \
    bound_service_account_namespaces=$NAMESPACE \
    policies=$SVC \
    ttl=1h max_ttl=24h"
  echo "    ✔ $SVC role OK"
done

echo ""
echo "==> Policies và Roles setup hoàn tất!"
