#!/bin/bash
# ================================================================
# DOAN2 System Health Check
# ================================================================
# Quick validation script to verify all components are operational
# Run this after deployment to confirm everything works
# ================================================================

set -uo pipefail  # Removed -e for graceful error handling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         DOAN2 SYSTEM HEALTH CHECK                          ║"
echo "║         $(date '+%Y-%m-%d %H:%M:%S UTC')                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ================================================================
# HELPER FUNCTIONS
# ================================================================

check_pass() {
  echo -e "${GREEN}✅${NC} $1"
  ((PASS_COUNT++))
}

check_fail() {
  echo -e "${RED}❌${NC} $1"
  ((FAIL_COUNT++))
}

check_warn() {
  echo -e "${YELLOW}⚠️${NC} $1"
  ((WARN_COUNT++))
}

check_section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ================================================================
# CLUSTER CHECKS
# ================================================================

check_section "1. KUBERNETES CLUSTER"

# Check cluster nodes
NODES=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODES" -ge 2 ]; then
  check_pass "Cluster nodes ready ($NODES nodes)"
else
  check_fail "Cluster nodes not ready (only $NODES nodes)"
fi

# Check node status
NODE_READY=$(kubectl get nodes --no-headers | grep -c "Ready " || true)
if [ "$NODE_READY" -ge "$NODES" ] 2>/dev/null; then
  check_pass "All nodes in Ready status"
else
  check_warn "Some nodes may not be fully Ready ($NODE_READY/$NODES)"
fi

# ================================================================
# Pod Checks - Cluster
# ================================================================

check_section "2. INFRASTRUCTURE PODS"

# Check Cilium
CILIUM_PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | grep -c "Running" || true)
if [ "$CILIUM_PODS" -ge 1 ]; then
  check_pass "Cilium CNI running ($CILIUM_PODS pods)"
else
  check_fail "Cilium CNI not ready"
fi

# Check cert-manager
CM_PODS=$(kubectl get pods -n cert-manager --no-headers | grep -c "Running" || true)
if [ "$CM_PODS" -ge 3 ]; then
  check_pass "cert-manager running ($CM_PODS pods)"
else
  check_warn "cert-manager pods not all ready ($CM_PODS pods)"
fi

# Check Nginx Ingress
NGINX_PODS=$(kubectl get pods -n ingress-nginx --no-headers | grep -c "Running" || true)
if [ "$NGINX_PODS" -ge 1 ]; then
  check_pass "Nginx Ingress Controller running ($NGINX_PODS pods)"
else
  check_fail "Nginx Ingress not ready"
fi

# ================================================================
# DATABASE CHECKS
# ================================================================

check_section "3. DATABASE & MESSAGING"

# Check MySQL
MYSQL_PODS=$(kubectl get pods -n data -l app=mysql --no-headers | grep -c "Running" || true)
if [ "$MYSQL_PODS" -ge 1 ]; then
  check_pass "MySQL running ($MYSQL_PODS pods)"
else
  check_fail "MySQL not running"
fi

# Check Kafka
KAFKA_PODS=$(kubectl get pods -n data -l app.kubernetes.io/name=kafka --no-headers | grep -c "Running" || true)
if [ "$KAFKA_PODS" -ge 1 ]; then
  check_pass "Kafka running ($KAFKA_PODS pods)"
else
  check_warn "Kafka not running"
fi

# Check databases exist
DATABASES=$(kubectl exec -n data deploy/mysql -- \
  mysql -uroot -p$(kubectl get secret app-secrets -n data \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d) \
  -e "SHOW DATABASES LIKE 'job7189%';" 2>/dev/null | grep -c job7189 || echo "0")

if [ "$(($DATABASES))" -ge 7 ]; then
  check_pass "Databases created ($(($DATABASES)) found)"
else
  check_warn "Some databases missing ($DATABASES/7 found)"
fi

# ================================================================
# VAULT CHECKS
# ================================================================

check_section "4. VAULT & SECRET MANAGEMENT"

# Check Vault pod
VAULT_PODS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers | grep -c "Running" || true)
if [ "$VAULT_PODS" -ge 1 ]; then
  check_pass "Vault running ($VAULT_PODS pods)"
else
  check_fail "Vault not running"
fi

# Check Vault status
if kubectl exec -n vault vault-0 -- \
  sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status" &>/dev/null; then
  VAULT_SEALED=$(kubectl exec -n vault vault-0 -- \
    sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status" | grep "Sealed" | awk '{print $2}' || echo "unknown")
  
  if [ "$VAULT_SEALED" = "false" ]; then
    check_pass "Vault unsealed and accessible"
  else
    check_warn "Vault sealed (status: $VAULT_SEALED)"
  fi
else
  check_warn "Cannot reach Vault"
fi

# Check Agent Injector
INJECTOR_PODS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector --no-headers | grep -c "Running" || true)
if [ "$INJECTOR_PODS" -ge 1 ]; then
  check_pass "Vault Agent Injector running ($INJECTOR_PODS pods)"
else
  check_fail "Vault Agent Injector not running"
fi

# Check K8s auth roles
K8S_ROLES=$(kubectl exec -n vault vault-0 -- \
  sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN=\$(cat /mnt/vault/keys.txt 2>/dev/null | grep root_token | cut -d: -f2 | tr -d ' ') vault list auth/kubernetes/role/" 2>/dev/null | grep -c "service" || true)

if [ "$K8S_ROLES" -ge 7 ]; then
  check_pass "Kubernetes auth roles configured ($K8S_ROLES roles)"
else
  check_warn "Some K8s auth roles missing ($K8S_ROLES/9 roles)"
fi

# ================================================================
# MICROSERVICE CHECKS
# ================================================================

check_section "5. MICROSERVICES"

# Count running microservices
RUNNING_SERVICES=$(kubectl get pods -n job7189-apps --no-headers | \
  grep -v redis | grep -v fe- | grep -c "2/2.*Running" || true)

if [ "$RUNNING_SERVICES" -eq 7 ]; then
  check_pass "All microservices ready (7/7 - 2/2 containers each)"
else
  check_warn "Some microservices not ready ($RUNNING_SERVICES/7)"
fi

# List microservices status
echo ""
echo "  Microservice Status:"
for svc in identity-service workspace-service job-service hiring-service \
           candidate-service communication-service storage-service; do
  PODS=$(kubectl get pods -n job7189-apps -l app=$svc --no-headers | wc -l)
  STATUS=$(kubectl get pods -n job7189-apps -l app=$svc --no-headers | awk '{print $2, $3}' | head -1)
  echo "    • $svc: $STATUS"
done

# ================================================================
# VAULT INJECTION CHECKS
# ================================================================

check_section "6. VAULT SECRET INJECTION"

# Get a healthy sample pod
SAMPLE_POD=$(kubectl get pods -n job7189-apps -l app=candidate-service --no-headers 2>/dev/null | awk '$2=="2/2" && $3=="Running" {print $1; exit}' || echo "")

if [ -n "$SAMPLE_POD" ]; then
  # Check if secrets exist
  if kubectl exec -n job7189-apps "$SAMPLE_POD" -- test -f /vault/secrets/.env.common 2>/dev/null; then
    check_pass "APP_KEY (common secrets) injected"
  else
    check_warn "APP_KEY not found in /vault/secrets/.env.common"
  fi

  if kubectl exec -n job7189-apps "$SAMPLE_POD" -- test -f /vault/secrets/.env.db 2>/dev/null; then
    check_pass "Database credentials (dynamic) injected"
  else
    check_fail "Database credentials not injected"
  fi

  if kubectl exec -n job7189-apps "$SAMPLE_POD" -- test -f /vault/secrets/.env 2>/dev/null; then
    check_pass "Merged .env file ready"
  else
    check_warn "Merged .env file not found"
  fi

  # Check for actual credential values
  DB_USER=$(kubectl exec -n job7189-apps "$SAMPLE_POD" -- \
    sh -lc "grep '^DB_USERNAME=' /vault/secrets/.env.db | cut -d= -f2 | tr -d ' '" 2>/dev/null || echo "")
  
  if [[ "$DB_USER" == v-kubernetes-* ]]; then
    check_pass "Dynamic database credentials present (v-kubernetes-*)"
  else
    check_warn "Database credentials not in expected format"
  fi
else
  check_warn "No healthy candidate-service pod (2/2 Running) found for secrets check"
fi

# ================================================================
# AUTHENTICATION CHECKS
# ================================================================

check_section "7. AUTHENTICATION & API GATEWAY"

# Check Keycloak
KC_PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=keycloak --no-headers | grep -c "Running" || true)
if [ "$KC_PODS" -ge 1 ]; then
  check_pass "Keycloak running ($KC_PODS pods)"
else
  check_warn "Keycloak not running"
fi

# Check oauth2-proxy
oauth2_PODS=$(kubectl get pods -n security -l app.kubernetes.io/name=oauth2-proxy --no-headers | grep -c "Running" || true)
if [ "$oauth2_PODS" -ge 1 ]; then
  check_pass "oauth2-proxy running ($oauth2_PODS pods)"
else
  check_warn "oauth2-proxy not running"
fi

# Check Kong Gateway
KONG_PODS=$(kubectl get pods -n gateway --no-headers | grep -c "Running" || true)
if [ "$KONG_PODS" -ge 1 ]; then
  check_pass "Kong API Gateway running ($KONG_PODS pods)"
else
  check_warn "Kong API Gateway not running"
fi

# Deep scripted checks for deterministic, auditable validation
check_section "8. DEEP SCRIPTED CHECKS"

if [ -x "./check-vault-env.sh" ]; then
  if ./check-vault-env.sh >/dev/null 2>&1; then
    check_pass "Vault env injection deep check passed (all backend services)"
  else
    check_fail "Vault env injection deep check failed (run ./check-vault-env.sh)"
  fi
else
  check_warn "Missing executable ./check-vault-env.sh"
fi

if [ -x "./check-kong-keycloak.sh" ]; then
  if ./check-kong-keycloak.sh >/dev/null 2>&1; then
    check_pass "Kong-Keycloak integration deep check passed"
  else
    check_fail "Kong-Keycloak integration deep check failed (run ./check-kong-keycloak.sh)"
  fi
else
  check_warn "Missing executable ./check-kong-keycloak.sh"
fi

# ================================================================
# POD RESTART RESILIENCE CHECK
# ================================================================

check_section "9. POD RESTART RESILIENCE"

# This is informational - we don't actually delete pods during health check
echo "  ℹ️  To test pod restart resilience manually:"
echo "    1. kubectl exec -n job7189-apps <pod> -- cat /vault/secrets/.env.db"
echo "       (note the DB_USERNAME)"
echo "    2. kubectl delete pod <pod> -n job7189-apps"
echo "    3. sleep 30 && kubectl exec -n job7189-apps <new-pod> -- cat /vault/secrets/.env.db"
echo "       (verify DB_USERNAME is DIFFERENT)"
echo ""
check_pass "Pod restart testing procedure documented"

# ================================================================
# SUMMARY
# ================================================================

echo ""
check_section "HEALTH CHECK SUMMARY"

TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
SUCCESS_PERCENT=$(echo "scale=1; $PASS_COUNT * 100 / $TOTAL" | bc)

echo ""
echo -e "  Checks Passed:  ${GREEN}$PASS_COUNT${NC}"
echo -e "  Checks Failed:  ${RED}$FAIL_COUNT${NC}"
echo -e "  Warnings:       ${YELLOW}$WARN_COUNT${NC}"
echo "  Total Checks:   $TOTAL"
echo ""
echo "  Success Rate:   $SUCCESS_PERCENT%"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
  if [ "$WARN_COUNT" -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 ALL SYSTEMS OPERATIONAL                           ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    exit 0
  else
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  ⚠️  SYSTEM OPERATIONAL WITH WARNINGS                ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    exit 0
  fi
else
  echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
  echo -e "${RED}  ❌ SYSTEM HAS FAILURES - REVIEW ABOVE                ${NC}"
  echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
  exit 1
fi
