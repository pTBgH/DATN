#!/bin/bash
# ==========================================
# Check Database Seed Results
# ==========================================
# PURPOSE: Verify schema/data were actually imported after running 05-seed-databases.sh
# ==========================================

set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo
  echo -e "${BLUE}======================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}======================================================${NC}"
}

query_mysql() {
  local sql="$1"
  kubectl exec -n data deploy/mysql -- \
    mysql -uroot -p"${MYSQL_ROOT_PASS}" -Nse "$sql" 2>/dev/null
}

declare -A REQUIRED_TABLES=(
  ["job7189_candidate_db"]="service_users"
  ["job7189_communication_db"]="service_users"
  ["job7189_hiring_db"]="job_applications"
  ["job7189_identity_db"]="usr_users"
  ["job7189_job_db"]="job_companies"
  ["job7189_storage_db"]="storage_files"
  ["job7189_workspace_db"]="workspaces"
)

section "1) Read MySQL Credentials"
MYSQL_ROOT_PASS=$(kubectl get secret app-secrets -n data -o jsonpath='{.data.mysql-root-password}' 2>/dev/null | base64 -d 2>/dev/null)
if [ -z "${MYSQL_ROOT_PASS}" ]; then
  fail "Cannot read mysql-root-password from secret data/app-secrets"
  echo
  echo "Result: FAILED"
  exit 1
fi
pass "MySQL root password loaded from Kubernetes secret"

section "2) Verify Databases"
for db in "${!REQUIRED_TABLES[@]}"; do
  exists=$(query_mysql "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='${db}';")
  if [ "${exists:-0}" = "1" ]; then
    pass "Database exists: ${db}"
  else
    fail "Database missing: ${db}"
  fi
done

section "3) Verify Required Tables"
for db in "${!REQUIRED_TABLES[@]}"; do
  table="${REQUIRED_TABLES[$db]}"
  exists=$(query_mysql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';")
  if [ "${exists:-0}" = "1" ]; then
    pass "Required table exists: ${db}.${table}"
  else
    fail "Required table missing: ${db}.${table}"
  fi
done

section "4) Sample Row Counts"
for db in "${!REQUIRED_TABLES[@]}"; do
  table="${REQUIRED_TABLES[$db]}"
  exists=$(query_mysql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';")
  if [ "${exists:-0}" = "1" ]; then
    count=$(query_mysql "SELECT COUNT(*) FROM ${db}.${table};")
    if [ "${count:-0}" -gt 0 ] 2>/dev/null; then
      pass "Data present: ${db}.${table} has ${count} row(s)"
    else
      warn "No rows in ${db}.${table} (schema exists but data may be empty)"
    fi
  fi
done

section "5) Summary"
echo "PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} WARN=${WARN_COUNT}"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "Result: FAILED"
  echo "Hint: run bash 05-seed-databases.sh and check for CREATE TABLE conflicts or missing stdin piping."
  exit 1
fi

echo
echo "Result: OK"
exit 0
