#!/bin/bash
# =========================================================================
# VAULT FAST REBUILD PIPELINE (All-in-one)
# Gộp tất cả lệnh kubectl exec -> Loại bỏ >500s delay I/O
# =========================================================================

set -euo pipefail

echo "╔═════════════════════════════════════════════════╗"
echo "║      🚀 SUPER FAST VAULT REBUILD PIPELINE       ║"
echo "╚═════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")"

# --- 1. CLEANUP (Tẩy sạch thần tốc) ---
echo "==> [1/7] Dọn dẹp Vault cũ (Đang xóa song song...)"
kubectl delete statefulset vault -n vault --ignore-not-found=true &
kubectl delete deployment vault-dev -n vault --ignore-not-found=true &
kubectl delete service vault vault-dev -n vault --ignore-not-found=true &
kubectl delete configmap vault-config -n vault --ignore-not-found=true &
kubectl delete serviceaccount vault vault-dev -n vault --ignore-not-found=true &
kubectl delete clusterrolebinding vault-server-binding --ignore-not-found=true &
kubectl delete pvc vault-data -n vault --ignore-not-found=true &
kubectl delete certificate vault-ca vault-server-tls -n vault --ignore-not-found=true &
kubectl delete secret vault-tls vault-ca-secret -n vault --ignore-not-found=true &
kubectl delete issuer vault-ca-issuer -n vault --ignore-not-found=true &
kubectl delete clusterissuer selfsigned-issuer --ignore-not-found=true &
helm uninstall vault-agent -n vault 2>/dev/null || true &
kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg --ignore-not-found=true &
wait

echo "    Chờ dọn dẹp triệt để pods..."
kubectl wait --for=delete pod -l app=vault -n vault --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app=vault-dev -n vault --timeout=60s 2>/dev/null || true
rm -f vault-prod-init.json
echo "    ✔ Clean up hoàn tất."

# --- 2. DEPLOY YAML ---
echo -e "\n==> [2/7] Deploy K8s Resources (Cert-Manager Issuer & Vault)..."
kubectl apply -f ../10-cert-manager-issuer.yaml
kubectl apply -f ../11-vault.yaml

# --- 3. INIT VAULT-DEV (Dùng Liveness Polling thay vì sleep tĩnh) ---
echo -e "\n==> [3/7] Cấu hình vault-dev (Transit Unsealer)..."
while ! kubectl exec -n vault deploy/vault-dev -- wget -qO- http://127.0.0.1:8300/v1/sys/health >/dev/null 2>&1; do
    echo -n "."
    sleep 1
done
echo " Ready!"
kubectl exec -n vault deploy/vault-dev -- sh -c "VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=vault-dev-root-token vault secrets enable transit 2>/dev/null || true; vault write -f transit/keys/vault-prod-unseal-key 2>/dev/null || true"
echo "    ✔ Transit Unseal hoàn tất."

# --- 4. INIT VAULT-PROD ---
echo -e "\n==> [4/7] Khởi tạo vault-prod..."
while : ; do
    PHASE=$(kubectl get pod vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo "Waiting")
    [ "$PHASE" == "Running" ] && break
    echo -n "."
    sleep 1
done
echo " Running!"

# Wait for Vault API responding
while : ; do
    STATUS=$(kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json" 2>/dev/null || true)
    if echo "$STATUS" | grep -q "\"initialized\""; then
        break
    fi
    echo -n "."
    sleep 1
done
echo " Initializing..."

INIT_OUTPUT=$(kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json")
echo "$INIT_OUTPUT" > vault-prod-init.json
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['root_token'])")
echo "    ✔ Init Vault-prod thành công!"

# --- 5. BATCH EXECUTION IN VAULT-0 (Sát thủ rút ngắn thời gian) ---
echo -e "\n==> [5/7] Chuẩn bị Data & Đẩy vào Vault (Batch Pipeline siêu tốc)..."

## Prefer environment-supplied MYSQL_ROOT_PASS (02 will export it). Fall back to legacy app-secrets only if not set.
if [ -z "${MYSQL_ROOT_PASS:-}" ]; then
  MYSQL_ROOT_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.mysql-root-password}' 2>/dev/null | base64 -d || true)
fi
KC_ADMIN_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.keycloak-admin-password}' | base64 -d)
VAULT_MGR_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.vault-manager-password}' 2>/dev/null | base64 -d || true)
if [ -z "$VAULT_MGR_PASS" ]; then
  VAULT_MGR_PASS=$(openssl rand -hex 16)
  # If app-secrets exists, update vault-manager there; otherwise ignore (we'll keep password only in Vault)
  if kubectl get secret app-secrets -n data >/dev/null 2>&1; then
    kubectl get secret app-secrets -n data -o json | python3 -c "import sys, json, base64; s = json.load(sys.stdin); s['data']['vault-manager-password'] = base64.b64encode(b'${VAULT_MGR_PASS}').decode(); json.dump(s, sys.stdout)" | kubectl replace -f - || true
  fi
fi

echo "    -> Bơm kịch bản xử lý hàng loạt trực tiếp vào Pod vault-0..."
# Sử dụng Heredoc không quote biến EOF để truyền Root Token & Passwords vào script
cat <<EOF | kubectl exec -i -n vault vault-0 -c vault -- sh
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN="${ROOT_TOKEN}"

echo "    [In-Pod] Kích hoạt Engines..."
vault auth enable kubernetes 2>/dev/null || true
vault write auth/kubernetes/config \
  token_reviewer_jwt="\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host=https://kubernetes.default.svc \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault secrets enable -path=secret kv-v2 2>/dev/null || true
vault secrets enable database 2>/dev/null || true

echo "    [In-Pod] Put Static Secrets..."
vault kv put secret/laravel-common APP_KEY='base64:V0sAjegVX3yTmM/z+zEsMjYbksjNhHcJxqhV6wKAGNs='
vault kv put secret/communication-service MAIL_PASSWORD='rscd zhzf uvad ecot'
vault kv put secret/identity-service LARAVEL_INTERNAL_API_SECRET='ABC123XYZ'
vault kv put secret/storage-service MINIO_KEY='minioadmin' MINIO_SECRET='minioadmin' NEXTJS_INTERNAL_API_SECRET='ABC123XYZ'
vault kv put secret/oauth2-proxy client-secret='8iAntNwXzjJUSbw1m1tHpM3JigJUTeAE' cookie-secret='v92UDXzSJJZhKAldJT9M76rSH4MSGxTyWu9sbL-F8jg='
vault kv put secret/keycloak db-password='${MYSQL_ROOT_PASS}' admin-password='${KC_ADMIN_PASS}'
vault kv put secret/mysql root-password='${MYSQL_ROOT_PASS}'
vault kv put secret/vault-manager username='vault_manager' password='${VAULT_MGR_PASS}'

echo "    [In-Pod] Setup Dynamic Database..."
vault write database/config/mysql \
  plugin_name=mysql-database-plugin \
  connection_url='{{username}}:{{password}}@tcp(mysql.data.svc.cluster.local:3306)/' \
  allowed_roles='*' username='vault_manager' password='${VAULT_MGR_PASS}'

for SVC_DB in identity-service:job7189_identity_db workspace-service:job7189_workspace_db job-service:job7189_job_db hiring-service:job7189_hiring_db candidate-service:job7189_candidate_db communication-service:job7189_communication_db storage-service:job7189_storage_db; do
  SVC="\${SVC_DB%%:*}"
  DB="\${SVC_DB##*:}"
  vault write database/roles/\$SVC db_name=mysql \
    username_template='usr_{{random 16 | truncate 12}}' \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT,INSERT,UPDATE,DELETE ON \${DB}.* TO '{{name}}'@'%';" \
    revocation_statements="DROP USER IF EXISTS '{{name}}'@'%';" \
    default_ttl='1h' max_ttl='24h'
done

echo "    [In-Pod] Cấu hình Policies & Roles..."
vault policy write oauth2-proxy - <<POL
path "secret/data/oauth2-proxy" { capabilities = ["read"] }
POL
vault policy write keycloak - <<POL
path "secret/data/keycloak" { capabilities = ["read"] }
POL

for SVC in identity-service workspace-service job-service hiring-service candidate-service communication-service storage-service; do
  EXTRA=""
  case "\$SVC" in communication-service|identity-service|storage-service)
    EXTRA="path \"secret/data/\$SVC\" { capabilities = [\"read\"] }"
  ;; esac
  vault policy write \$SVC - <<POL
path "secret/data/laravel-common" { capabilities = ["read"] }
path "database/creds/\$SVC" { capabilities = ["read"] }
\$EXTRA
POL
  vault write auth/kubernetes/role/\$SVC \
    bound_service_account_names=\$SVC \
    bound_service_account_namespaces=job7189-apps \
    policies=\$SVC \
    ttl=1h max_ttl=24h
done

vault write auth/kubernetes/role/oauth2-proxy bound_service_account_names=oauth2-proxy bound_service_account_namespaces=security policies=oauth2-proxy ttl=1h max_ttl=24h
vault write auth/kubernetes/role/keycloak bound_service_account_names=keycloak bound_service_account_namespaces=security policies=keycloak ttl=1h max_ttl=24h

# Create minimal policy and Kubernetes auth role for MySQL bootstrap init container
vault policy write mysql-bootstrap - <<POL
path "secret/data/mysql" { capabilities = ["read"] }
POL
vault write auth/kubernetes/role/mysql \
  bound_service_account_names=mysql \
  bound_service_account_namespaces=data \
  policies=mysql-bootstrap \
  ttl=1h max_ttl=24h
EOF
echo "    ✔ Bơm Data hoàn tất!"

# --- 6. CẤP QUYỀN MYSQL BÊN NGOÀI ---
echo -e "\n==> [6/7] Cấp quyền Vault Manager trên MySQL..."
GRANT_STATEMENTS=""
for DB in job7189_identity_db job7189_workspace_db job7189_job_db job7189_hiring_db job7189_candidate_db job7189_communication_db job7189_storage_db; do
  GRANT_STATEMENTS+="GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP ON ${DB}.* TO 'vault_manager'@'%' WITH GRANT OPTION;"
done

kubectl exec -n data deploy/mysql -- mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "
  CREATE USER IF NOT EXISTS 'vault_manager'@'%' IDENTIFIED BY '${VAULT_MGR_PASS}';
  ALTER USER 'vault_manager'@'%' IDENTIFIED BY '${VAULT_MGR_PASS}';
  GRANT CREATE USER ON *.* TO 'vault_manager'@'%' WITH GRANT OPTION;
  ${GRANT_STATEMENTS}
  FLUSH PRIVILEGES;
"
echo "    ✔ MySQL Grants OK!"

# --- 7. HELM INJECTOR ---
echo -e "\n==> [7/7] Cài đặt lại Vault Injector..."
# Run im lặng, tránh log dài, dùng script 07 có sẵn
bash 07_install_injector.sh | grep -v '✔' || true
echo "    ✔ Cài đặt Vault Injector hoàn tất!"

echo ""
echo "=========================================================="
echo "🎯 ĐÃ XONG! Toàn bộ quy trình Vault Rebuild chỉ mất vài chục giây!"
echo "=========================================================="
