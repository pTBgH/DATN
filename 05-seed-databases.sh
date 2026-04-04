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

# ── ZTA: Read MySQL root password from Kubernetes Secret ──
echo "🔐 Reading MySQL root password from Kubernetes Secret..."
MYSQL_ROOT_PASS=$(kubectl get secret app-secrets -n data \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d)

if [ -z "$MYSQL_ROOT_PASS" ]; then
  echo "❌ ERROR: Could not read mysql-root-password from app-secrets in namespace 'data'"
  echo "   Ensure the secret exists: kubectl get secret app-secrets -n data"
  exit 1
fi
echo "✓ MySQL root password retrieved from Kubernetes Secret"

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

  # ZTA: Pipe SQL through kubectl exec (-i is required to forward stdin)
  if kubectl exec -i -n data deploy/mysql -- \
    mysql -uroot -p"${MYSQL_ROOT_PASS}" "$db_name" \
    < "$sql_path" 2>&1; then
    echo "   ✅ Seeded successfully: $db_name"
  else
    echo "   ❌ Failed to seed: $db_name"
    FAILED+=("$db_name")
  fi
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
  mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "SHOW DATABASES LIKE 'job7189%';" 2>/dev/null | \
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
