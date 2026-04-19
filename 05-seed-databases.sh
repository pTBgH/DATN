#!/bin/bash
# ==========================================
# Script 05: Seed Databases from SQL Dumps
# ==========================================
# PURPOSE: Load initial schema + default data from DB/ folder into MySQL.
# SECURITY (ZTA):
#   - MySQL root password is read from Kubernetes Secret (never hardcoded)
#   - SQL files contain ONLY schema (CREATE TABLE) and default data (INSERT)
#   - SQL files MUST NOT contain passwords, user creations, or GRANT statements
#   - All credential management is delegated to Vault dynamic DB engine
# ==========================================

set -uo pipefail  # Remove -e to handle errors gracefully

echo ""
echo "════════════════════════════════════════════════════════"
echo "🌱 DATABASE SEED SCRIPT (ZTA Mode)"
echo "════════════════════════════════════════════════════════"
echo ""

# ── ZTA: Obtain MySQL credentials from Vault (avoid cluster-wide secrets)
echo "🔐 Obtaining MySQL credentials from Vault..."

# Ensure namespace 'data' exists and MySQL pod is ready
if ! kubectl get namespace data >/dev/null 2>&1; then
  echo "? Namespace 'data' not found — creating"
  kubectl create namespace data || true
fi
echo "? Waiting up to 180s for MySQL pod to be Ready in namespace 'data'"
if ! kubectl wait --for=condition=Ready=True pod -l app=mysql -n data --timeout=180s 2>/dev/null; then
  echo "! ERROR: MySQL pods not ready in namespace 'data' — aborting seed"
  kubectl get pod -n data -o wide || true
  exit 1
fi
get_vault_root_token() {
  local init_file="infras/k8s-yaml/vault-scripts/vault-prod-init.json"
  if [ -f "$init_file" ]; then
    python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('root_token',''))" "$init_file" 2>/dev/null || true
  else
    echo ""
  fi
}

# Acquire Vault root token (created by the fast-rebuild pipeline). This is used only
# by bootstrap/administrative tasks that must seed databases; application pods
# should use dynamic credentials via database/creds/*.
ROOT_TOKEN=$(get_vault_root_token || true)
if [ -z "$ROOT_TOKEN" ]; then
  echo "❌ ERROR: Vault root token not found (infras/k8s-yaml/vault-scripts/vault-prod-init.json)"
  echo "   Ensure Vault has been initialized and the fast-rebuild pipeline has been run"
  exit 1
fi

# Read MySQL root credentials from Vault (vault kv secret)
CREDS_JSON=$(kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN='${ROOT_TOKEN}' vault kv get -format=json secret/mysql" 2>/dev/null || true)
if [ -z "$CREDS_JSON" ]; then
  echo "❌ ERROR: Could not read secret/mysql credentials from Vault"
  exit 1
fi
MYSQL_USER="root"
MYSQL_PASS=$(echo "$CREDS_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("data",{}).get("data",{}).get("root-password",""))')

if [ -z "$MYSQL_PASS" ]; then
  echo "❌ ERROR: MySQL root-password is missing in Vault"
  exit 1
fi
echo "✓ Obtained vault-manager credentials from Vault (user: $MYSQL_USER)"

# ── Locate SQL dump files ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="${SCRIPT_DIR}/DB"

if [ ! -d "$DB_DIR" ]; then
  echo "❌ ERROR: DB directory not found at $DB_DIR"
  exit 1
fi

echo ""
echo "📂 SQL files found in $DB_DIR:"
ls -la "$DB_DIR"/*.sql 2>/dev/null || { echo "❌ No SQL files found"; exit 1; }
echo ""

# ── Mapping: SQL file → database name ──
declare -A DB_MAP=(
  ["job7189_identity_db.sql"]="job7189_identity_db"
  ["job7189_workspace_db.sql"]="job7189_workspace_db"
  ["job7189_job_db.sql"]="job7189_job_db"
  ["job7189_hiring_db.sql"]="job7189_hiring_db"
  ["job7189_candidate_db.sql"]="job7189_candidate_db"
  ["job7189_communication_db.sql"]="job7189_communication_db"
  ["job7189_storage_db.sql"]="job7189_storage_db"
)

# Validate all files exist before starting
echo "🔍 Validating SQL files..."
for sql_file in "${!DB_MAP[@]}"; do
  sql_path="${DB_DIR}/${sql_file}"
  if [ ! -f "$sql_path" ]; then
    echo "❌ Missing: $sql_path"
    exit 1
  fi
done
echo "✅ All SQL files found"
echo ""

# ── Seed each database ──
TOTAL=${#DB_MAP[@]}
CURRENT=0
FAILED=()

for sql_file in "${!DB_MAP[@]}"; do
  db_name="${DB_MAP[$sql_file]}"
  sql_path="${DB_DIR}/${sql_file}"
  ((CURRENT++))

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[$CURRENT/$TOTAL] 🗄️  Seeding: $db_name"
  echo "   Source: $sql_file ($(wc -c < "$sql_path" | tr -d ' ') bytes)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ ! -f "$sql_path" ]; then
    echo "   ⚠️  File not found: $sql_path — skipping"
    FAILED+=("$db_name")
    continue
  fi

  # ZTA: Create transformed SQL that drops existing tables, then run original SQL.
  temp_sql=$(mktemp --suffix=.sql)
  # 1) Build transformed SQL: disable FK checks, drop tables, then append original SQL (with INSERT -> INSERT IGNORE)
  if ! printf "%s
SET FOREIGN_KEY_CHECKS=0;\n" "-- transformed by seed script" > "$temp_sql"; then
    echo "   ❌ Failed to start transformed SQL for $db_name"
    rm -f "$temp_sql"
    FAILED+=("$db_name")
    continue
  fi
  if ! perl -0777 -ne 'while(/CREATE\s+TABLE\s+`?([^\s`(]+)`?\s*\(/ig){ print "DROP TABLE IF EXISTS `$1`;\n" }' "$sql_path" >> "$temp_sql"; then
    echo "   ❌ Failed to extract table names for $db_name"
    rm -f "$temp_sql"
    FAILED+=("$db_name")
    continue
  fi
  # re-enable FK checks after drops, then append original SQL (with INSERT -> INSERT IGNORE)
  printf "SET FOREIGN_KEY_CHECKS=1;\n\n" >> "$temp_sql"
  if ! perl -0777 -pe 's/\bINSERT\s+INTO\b/INSERT IGNORE INTO/ig' "$sql_path" >> "$temp_sql"; then
    echo "   ❌ Failed to append transformed SQL for $db_name"
    rm -f "$temp_sql"
    FAILED+=("$db_name")
    continue
  fi

  # 3) Apply transformed SQL into MySQL
  if kubectl exec -i -n data deploy/mysql -- \
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "$db_name" \
    < "$temp_sql" 2>&1; then
    echo "   ✅ Seeded successfully: $db_name"
  else
    echo "   ❌ Failed to seed: $db_name"
    FAILED+=("$db_name")
  fi
  rm -f "$temp_sql"
  echo ""
done

# ── Summary ──
echo "════════════════════════════════════════════════════════"
echo "📊 SEED SUMMARY"
echo "════════════════════════════════════════════════════════"

if [ ${#FAILED[@]} -eq 0 ]; then
  echo "✅ All databases seeded successfully!"
else
  echo "⚠️  Some databases failed to seed:"
  printf '   • %s\n' "${FAILED[@]}"
fi

echo ""
echo "📋 Verify databases:"
if kubectl exec -n data deploy/mysql -- \
  mysql -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e "SHOW DATABASES LIKE 'job7189%';" 2>/dev/null | \
  grep job7189 || echo "   (unable to list databases)"; then
  :
fi
echo ""

# Exit with appropriate code
if [ ${#FAILED[@]} -eq 0 ]; then
  exit 0
else
  exit 1
fi
