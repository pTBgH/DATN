#!/bin/bash
# =========================================================================
# VAULT FAST REBUILD PIPELINE (All-in-one)
# =========================================================================
set -euo pipefail

MAX_WAIT="${MAX_WAIT:-240}"
SLEEP="${SLEEP:-2}"
MAX_RETRIES=$((MAX_WAIT / SLEEP))
CMD_TIMEOUT_SHORT="${CMD_TIMEOUT_SHORT:-20}"
CMD_TIMEOUT_MEDIUM="${CMD_TIMEOUT_MEDIUM:-60}"
CMD_TIMEOUT_LONG="${CMD_TIMEOUT_LONG:-180}"

run_with_timeout() {
  local timeout_seconds=$1
  shift
  local rc=0
  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground "${timeout_seconds}s" "$@" || rc=$?
    if [ "$rc" -eq 124 ]; then
      echo "ERROR: Timeout after ${timeout_seconds}s: $*" >&2
    fi
    return "$rc"
  else
    "$@"
  fi
}

echo "╔═════════════════════════════════════════════════╗"
echo "║      🚀 SUPER FAST VAULT REBUILD PIPELINE       ║"
echo "╚═════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")"

# --- 1. CLEANUP ---
echo "==> [1/6] Dọn dẹp Vault cũ..."
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete statefulset vault -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete deployment vault-dev -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete service vault vault-dev -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete configmap vault-config -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete serviceaccount vault vault-dev -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete clusterrolebinding vault-server-binding --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete pvc vault-data -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete certificate vault-ca vault-server-tls -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete secret vault-tls vault-ca-secret -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete issuer vault-ca-issuer -n vault --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete clusterissuer selfsigned-issuer --ignore-not-found=true || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" helm uninstall vault-agent -n vault 2>/dev/null || true) &
(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg --ignore-not-found=true || true) &
wait
kubectl wait --for=delete pod -l app=vault -n vault --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app=vault-dev -n vault --timeout=60s 2>/dev/null || true
rm -f vault-prod-init.json
echo "    ✔ Clean up hoàn tất."

# --- 2. DEPLOY YAML ---
echo -e "\n==> [2/6] Deploy K8s Resources..."
run_with_timeout "$CMD_TIMEOUT_MEDIUM" kubectl apply -f ../10-cert-manager-issuer.yaml
run_with_timeout "$CMD_TIMEOUT_MEDIUM" kubectl apply -f ../11-vault.yaml

# --- 3. INIT VAULT-DEV ---
echo -e "\n==> [3/6] Cấu hình vault-dev (Transit Unsealer)..."
count=0
until run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl exec -n vault deploy/vault-dev -- wget -qO- http://127.0.0.1:8300/v1/sys/health >/dev/null 2>&1; do
  count=$((count+1))
  if [ $count -ge $MAX_RETRIES ]; then echo "ERROR: vault-dev timeout" >&2; exit 1; fi
  sleep $SLEEP
done
run_with_timeout "$CMD_TIMEOUT_MEDIUM" kubectl exec -n vault deploy/vault-dev -- sh -c "VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=vault-dev-root-token vault secrets enable transit 2>/dev/null || true; vault write -f transit/keys/vault-prod-unseal-key 2>/dev/null || true"
echo "    ✔ Transit Unseal hoàn tất."

# --- 4. INIT VAULT-PROD ---
echo -e "\n==> [4/6] Khởi tạo vault-prod..."
count=0
until [ "$(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo 'NotFound')" = "Running" ]; do
  count=$((count+1))
  if [ $count -ge $MAX_RETRIES ]; then echo "ERROR: vault-0 timeout" >&2; exit 1; fi
  sleep $SLEEP
done
count=0
until STATUS_JSON=$(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json 2>/dev/null || true"); [ -n "$STATUS_JSON" ] && echo "$STATUS_JSON" | grep -q '"initialized"'; do
  count=$((count+1))
  if [ $count -ge $MAX_RETRIES ]; then echo "ERROR: Vault API timeout" >&2; exit 1; fi
  sleep $SLEEP
done

STATUS_JSON=${STATUS_JSON:-$(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json 2>/dev/null || true")}
IS_INITIALIZED=$(echo "$STATUS_JSON" | python3 -c 'import sys,json; j=json.load(sys.stdin); print("true" if j.get("initialized") else "false")')

if [ "$IS_INITIALIZED" = "false" ]; then
  INIT_OUTPUT=$(run_with_timeout "$CMD_TIMEOUT_MEDIUM" kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault operator init -key-shares=1 -key-threshold=1 -format=json")
  echo "$INIT_OUTPUT" > vault-prod-init.json
  ROOT_TOKEN=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['root_token'])")
  UNSEAL_KEY=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('unseal_keys_b64',[None])[0])")
  if [ -n "$UNSEAL_KEY" ]; then
    run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault operator unseal '$UNSEAL_KEY'" || true
    sleep 2
  fi
else
  ROOT_TOKEN=$(cat vault-prod-init.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('root_token',''))" 2>/dev/null || echo "")
fi

if [ -z "${ROOT_TOKEN:-}" ]; then
  echo "ERROR: ROOT_TOKEN is empty; Vault bootstrap cannot continue" >&2
  exit 1
fi

# --- 5. BATCH EXECUTION ---
echo -e "\n==>[5/6] Chuẩn bị Data & Đẩy vào Vault..."
if [ -z "${MYSQL_ROOT_PASS:-}" ]; then MYSQL_ROOT_PASS=$(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl get secret app-secrets -n data -o jsonpath='{.data.mysql-root-password}' 2>/dev/null | base64 -d || true); fi
KC_ADMIN_PASS=$(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl get secret app-secrets -n data -o jsonpath='{.data.keycloak-admin-password}' 2>/dev/null | base64 -d)
VAULT_MGR_PASS=$(run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl get secret app-secrets -n data -o jsonpath='{.data.vault-manager-password}' 2>/dev/null | base64 -d || true)

if [ -z "${MYSQL_ROOT_PASS:-}" ] || [ -z "${KC_ADMIN_PASS:-}" ] || [ -z "${VAULT_MGR_PASS:-}" ]; then
  echo "ERROR: Missing bootstrap secrets (mysql/keycloak/vault-manager)" >&2
  exit 1
fi

cat <<EOF | run_with_timeout "$CMD_TIMEOUT_LONG" kubectl exec -i -n vault vault-0 -c vault -- sh
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN="${ROOT_TOKEN}"

vault auth enable kubernetes 2>/dev/null || true
vault write auth/kubernetes/config token_reviewer_jwt="\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" kubernetes_host=https://kubernetes.default.svc kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
vault secrets enable -path=secret kv-v2 2>/dev/null || true
vault secrets enable database 2>/dev/null || true

vault kv put secret/keycloak db-password='${MYSQL_ROOT_PASS}' admin-password='${KC_ADMIN_PASS}'
vault kv put secret/mysql root-password='${MYSQL_ROOT_PASS}'
vault kv put secret/vault-manager username='vault_manager' password='${VAULT_MGR_PASS}'

# QUAN TRỌNG: verify_connection=false để không kẹt khi MySQL chưa sống
vault write database/config/mysql plugin_name=mysql-database-plugin verify_connection=false connection_url='{{username}}:{{password}}@tcp(mysql.data.svc.cluster.local:3306)/' allowed_roles='*' username='vault_manager' password='${VAULT_MGR_PASS}'

for SVC_DB in identity-service:job7189_identity_db workspace-service:job7189_workspace_db job-service:job7189_job_db hiring-service:job7189_hiring_db candidate-service:job7189_candidate_db communication-service:job7189_communication_db storage-service:job7189_storage_db; do
  SVC="\${SVC_DB%%:*}"; DB="\${SVC_DB##*:}"
  vault write database/roles/\$SVC db_name=mysql username_template='usr_{{random 16 | truncate 12}}' creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT,INSERT,UPDATE,DELETE ON \${DB}.* TO '{{name}}'@'%';" revocation_statements="DROP USER IF EXISTS '{{name}}'@'%';" default_ttl='1h' max_ttl='24h'
done

vault policy write keycloak - <<POL
path "secret/data/keycloak" { capabilities = ["read"] }
POL
vault write auth/kubernetes/role/keycloak bound_service_account_names=keycloak bound_service_account_namespaces=security policies=keycloak ttl=1h max_ttl=24h

vault policy write mysql-bootstrap - <<POL
path "secret/data/mysql" { capabilities = ["read"] }
POL
vault write auth/kubernetes/role/mysql bound_service_account_names=mysql bound_service_account_namespaces=data policies=mysql-bootstrap ttl=1h max_ttl=24h
EOF
echo "    ✔ Bơm Data hoàn tất!"

# --- 6. HELM INJECTOR ---
echo -e "\n==> [6/6] Cài đặt lại Vault Injector..."
if [ -f 07_install_injector.sh ]; then
  run_with_timeout "$CMD_TIMEOUT_LONG" bash 07_install_injector.sh | grep -v '✔' || true
fi
echo "    ✔ Cài đặt Vault Injector hoàn tất!"