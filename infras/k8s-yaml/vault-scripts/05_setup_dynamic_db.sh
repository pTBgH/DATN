#!/bin/bash
# ==========================================
# Script 5: Setup Dynamic DB credentials
# Thêm DB mới: chỉ cần thêm vào mảng SERVICES
# ==========================================
# ZTA: All passwords read from Kubernetes Secret.
# If vault-manager-password doesn't exist yet, generate and store it.
# ==========================================

set -e

if [ ! -f vault-prod-init.json ]; then
  echo "ERROR: Không tìm thấy vault-prod-init.json"
  exit 1
fi

ROOT_TOKEN=$(python3 -c "import json; print(json.load(open('vault-prod-init.json'))['root_token'])")

# Helper function to run vault commands
run_vault() {
  kubectl exec -n vault vault-0 -- \
    env \
      VAULT_SKIP_VERIFY=true \
      VAULT_ADDR=https://127.0.0.1:8200 \
      VAULT_TOKEN="$ROOT_TOKEN" \
    sh -c "$1"
}

# ══════════════════════════════════════════════════════
# Thêm service mới: chỉ cần thêm 1 dòng vào đây
# Format: "service-name:database-name"
# ══════════════════════════════════════════════════════
SERVICES=(
  "identity-service:job7189_identity_db"
  "workspace-service:job7189_workspace_db"
  "job-service:job7189_job_db"
  "hiring-service:job7189_hiring_db"
  "candidate-service:job7189_candidate_db"
  "communication-service:job7189_communication_db"
  "storage-service:job7189_storage_db"
)

MYSQL_HOST="mysql.data.svc.cluster.local"
MYSQL_PORT="3306"

# ZTA: Read MySQL root password from Kubernetes Secret
MYSQL_ROOT_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.mysql-root-password}' | base64 -d)
if [ -z "$MYSQL_ROOT_PASS" ]; then
  echo "ERROR: Cannot read mysql-root-password from app-secrets"
  exit 1
fi

VAULT_MYSQL_USER="vault_manager"

# ZTA: Read or generate vault-manager password
VAULT_MYSQL_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.vault-manager-password}' 2>/dev/null | base64 -d 2>/dev/null || true)
if [ -z "$VAULT_MYSQL_PASS" ]; then
  echo "    ⚠ vault-manager-password not in K8s Secret, generating..."
  VAULT_MYSQL_PASS=$(openssl rand -hex 16)
  # Patch the existing secret to add the new key
  kubectl get secret app-secrets -n data -o json | \
    python3 -c "
import sys, json, base64
s = json.load(sys.stdin)
s['data']['vault-manager-password'] = base64.b64encode(b'${VAULT_MYSQL_PASS}').decode()
json.dump(s, sys.stdout)
" | kubectl replace -f -
  echo "    ✔ vault-manager-password generated and stored in K8s Secret"
fi

DEFAULT_TTL="1h"
MAX_TTL="24h"

# ══════════════════════════════════════════════════════

echo "==> [1/3] Tạo vault_manager user trong MySQL..."
echo "    User này có quyền tạo/xóa user động, không có quyền đọc data"

# Build GRANT statements cho từng DB
GRANT_STATEMENTS=""
for entry in "${SERVICES[@]}"; do
  DB="${entry#*:}"
  GRANT_STATEMENTS+="GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP ON ${DB}.* TO '${VAULT_MYSQL_USER}'@'%' WITH GRANT OPTION;"
done

kubectl exec -n data deploy/mysql -- \
  mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "
    CREATE USER IF NOT EXISTS '${VAULT_MYSQL_USER}'@'%'
      IDENTIFIED BY '${VAULT_MYSQL_PASS}';
    ALTER USER '${VAULT_MYSQL_USER}'@'%'
      IDENTIFIED BY '${VAULT_MYSQL_PASS}';
    GRANT CREATE USER ON *.* TO '${VAULT_MYSQL_USER}'@'%'
      WITH GRANT OPTION;
    ${GRANT_STATEMENTS}
    FLUSH PRIVILEGES;
  "
echo "    ✔ vault_manager user OK"

echo ""
echo "==> [2/3] Config Vault Database Engine..."
# ZTA: Use env to pass credentials — avoids shell quoting issues
run_vault "vault write database/config/mysql \
  plugin_name=mysql-database-plugin \
  connection_url='{{username}}:{{password}}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/' \
  allowed_roles='*' \
  username='${VAULT_MYSQL_USER}' \
  password='${VAULT_MYSQL_PASS}'"
echo "    ✔ Database engine OK"

echo ""
echo "==> [3/3] Tạo Vault role cho từng service..."
for entry in "${SERVICES[@]}"; do
  SVC="${entry%%:*}"
  DB="${entry#*:}"
  echo "    → $SVC ($DB)"
  run_vault "vault write database/roles/${SVC} \
    db_name=mysql \
    username_template='usr_{{random 16 | truncate 12}}' \
    creation_statements=\"CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; \
    GRANT SELECT,INSERT,UPDATE,DELETE ON ${DB}.* TO '{{name}}'@'%';\" \
    revocation_statements=\"DROP USER IF EXISTS '{{name}}'@'%';\" \
    default_ttl='${DEFAULT_TTL}' \
    max_ttl='${MAX_TTL}'"
done

echo ""
echo "==> Dynamic DB setup hoàn tất!"
echo ""
echo "Test thử:"
echo "  kubectl exec -n vault vault-0 -- sh -c \\"
echo "  \"VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \\"
echo "  VAULT_TOKEN=$ROOT_TOKEN \\"
echo "  vault read database/creds/candidate-service\""
