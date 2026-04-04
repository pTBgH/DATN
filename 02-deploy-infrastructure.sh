#!/bin/bash
# Part 2: Deploy Infrastructure Services & Vault
# This script: Deploys MySQL, Keycloak, Kafka, Kong, Vault, and related infrastructure
set -euo pipefail

# ==================== TIMING FUNCTIONS ====================
SCRIPT_START_TIME=$(date +%s)
STEP_START_TIME=$SCRIPT_START_TIME
declare -A STEP_TIMES

log_time() {
  local step_name=$1
  local current_time=$(date +%s)
  local elapsed=$((current_time - STEP_START_TIME))
  STEP_TIMES["$step_name"]=$elapsed
  echo "?  [$step_name] Duration: ${elapsed}s"
  STEP_START_TIME=$current_time
}

print_summary() {
  local total_time=$(($(date +%s) - SCRIPT_START_TIME))
  echo ""
  echo "????????????????????????????????????????????????"
  echo "? PART 2: INFRASTRUCTURE - TIMING SUMMARY"
  echo "????????????????????????????????????????????????"
  for step in "${!STEP_TIMES[@]}"; do
    printf "  %-45s %3ds\n" "$step" "${STEP_TIMES[$step]}"
  done | sort
  echo "------------------------------------------------"
  printf "  %-45s %3ds\n" "TOTAL" "$total_time"
  echo "????????????????????????????????????????????????"
}

trap print_summary EXIT

# ==================== HELPER FUNCTIONS ====================
wait_for_pods() {
  local label=$1
  local namespace=$2
  local timeout=${3:-300}
  
  echo "    Checking pod status for $label in $namespace..."
  kubectl get pod -n $namespace -l $label -o wide 2>/dev/null || echo "    (pods not created yet)"
  
  if kubectl wait --for=condition=Ready=True pod \
    -l $label \
    -n $namespace \
    --timeout=${timeout}s 2>/dev/null; then
    echo "    ? Pods ready: $label"
  else
    echo "?  Pod wait timeout for $label in $namespace"
    kubectl get pod -n $namespace -l $label || true
    echo "    (Continuing anyway...)"
  fi
  return 0  # Don't fail, continue anyway
}

# ==================== SCRIPT START ====================
echo ""
echo "????????????????????????????????????????????????????????????"
echo "?  PART 2: INFRASTRUCTURE SERVICES & VAULT                ?"
echo "?  Status: Deploying MySQL, Kafka, Kong, Vault            ?"
echo "????????????????????????????????????????????????????????????"
echo ""

# Check if cluster is ready
echo "? Pre-flight check: Verifying cluster readiness..."
if ! kubectl get nodes &>/dev/null; then
  echo "? ERROR: Kubernetes cluster not accessible!"
  echo "   Please run 01-setup-cluster.sh first"
  exit 1
fi

CLUSTER_STATUS=$(kubectl get pod -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l)
if [ "$CLUSTER_STATUS" -lt 1 ]; then
  echo "?  WARNING: Cilium pods not found. Continuing anyway..."
fi
echo "? Cluster is accessible"
log_time "Pre-flight check"

# read -p "? Continue with infrastructure deployment? (yes/no): " answer
# [[ "$answer" == "yes" ]] || exit 1

# ========================
# 1. Deploy Base Infrastructure (ZTA: Random Credentials)
# ========================
echo ""
echo "🔐 Step 1: Generating secure credentials (ZTA — no hardcoded passwords)..."

# ZTA: Generate random passwords at deploy time
MYSQL_ROOT_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
KEYCLOAK_ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
VAULT_MANAGER_PASS=$(openssl rand -base64 20 | tr -d '/+=' | head -c 20)

echo "   ✓ Random passwords generated (never written to disk)"

# ZTA: Create Kubernetes Secret with generated passwords
kubectl create secret generic app-secrets \
  --namespace=data \
  --from-literal=mysql-root-password="$MYSQL_ROOT_PASS" \
  --from-literal=keycloak-admin-password="$KEYCLOAK_ADMIN_PASS" \
  --from-literal=vault-manager-password="$VAULT_MANAGER_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Kubernetes Secret 'app-secrets' created in namespace 'data'"

# Also create a copy in security namespace for Keycloak
kubectl create secret generic app-secrets \
  --namespace=security \
  --from-literal=mysql-root-password="$MYSQL_ROOT_PASS" \
  --from-literal=keycloak-admin-password="$KEYCLOAK_ADMIN_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Kubernetes Secret 'app-secrets' created in namespace 'security'"

log_time "1a. Generate ZTA credentials"

echo "   Deploying MySQL init ConfigMap (empty databases only)..."
kubectl apply -f infras/k8s-yaml/mysql-init-configmap.yaml
log_time "1b. Apply mysql-init-configmap.yaml"

echo "   Deploying MySQL & phpMyAdmin..."
kubectl apply -f infras/k8s-yaml/01-mysql-phpmyadmin.yaml
log_time "1c. Apply 01-mysql-phpmyadmin.yaml"

# ======== KEYCLOAK SPECIAL HANDLING ========
echo ""
echo "? Building and deploying Keycloak..."

echo "   Step 1: Building Keycloak Docker image..."
cd infras/keycloak
docker build -t keycloak-custom:v1.0 .
cd ../..
log_time "1d1. Build Keycloak image"

echo "   Step 2: Loading image into Kind cluster..."
kind load docker-image keycloak-custom:v1.0 --name job7189
log_time "1d2. Load Keycloak image to Kind"

echo "   Step 3: Deploying Keycloak..."
kubectl apply -f infras/k8s-yaml/02-keycloak.yaml
log_time "1d3. Apply Keycloak deployment"

echo "   Step 4: WAITING for Keycloak to be ready (this may take 2-3 minutes)..."
if kubectl wait --for=condition=Ready=True pod \
  -l app=keycloak \
  -n security \
  --timeout=300s 2>/dev/null; then
  echo "    ? Keycloak is ready"
else
  echo "?  Keycloak wait timeout - checking status..."
  kubectl get pod -n security -l app=keycloak -o wide || true
  echo "    (WARNING: Keycloak may still be initializing, forcing continue)"
fi
log_time "1d4. Wait for Keycloak ready"

# ======== KAFKA DEPLOYMENT ========
echo ""
echo "? Deploying Kafka..."
kubectl apply -f infras/k8s-yaml/03-kafka.yaml
log_time "1e1. Apply Kafka deployment"

echo "  WAITING for Kafka to be ready (this may take 1-2 minutes)..."
if kubectl wait --for=condition=Ready=True pod \
  -l app.kubernetes.io/name=kafka \
  -n data \
  --timeout=240s 2>/dev/null; then
  echo "    ? Kafka is ready"
else
  echo "?  Kafka wait timeout - checking status..."
  kubectl get pod -n data -l app.kubernetes.io/name=kafka -o wide || true
  echo "    (WARNING: Kafka may still be initializing)"
fi
log_time "1e2. Wait for Kafka ready"

# ======== KONG SETUP & DEPLOYMENT ========
echo ""
echo "? Setting up and deploying Kong..."

echo "   Step 1: Creating Kong configuration ConfigMap..."
bash infras/kong/01_setup_kong_config.sh
log_time "1f1. Setup Kong ConfigMap"

echo "   Step 2: Deploying Kong..."
kubectl apply -f infras/k8s-yaml/04-kong-dbless.yaml
log_time "1f2. Apply Kong deployment"

echo "   Step 3: WAITING for Kong to be ready (this may take 1-2 minutes)..."
if kubectl wait --for=condition=Ready=True pod \
  -l app=kong-gateway \
  -n gateway \
  --timeout=240s 2>/dev/null; then
  echo "    ? Kong is ready"
else
  echo "?  Kong wait timeout - checking status..."
  kubectl get pod -n gateway -l app=kong-gateway -o wide || true
  echo "    (WARNING: Kong may still be initializing)"
fi
log_time "1f3. Wait for Kong ready"

echo ""
echo "? Base infrastructure services deployed"

# ======== OAUTH2-PROXY SETUP ========
echo ""
echo "? Step 2: Setting up oauth2-proxy authentication service..."

echo "   Creating oauth2-proxy configuration and secrets..."
bash infras/k8s-yaml/ingress/00_setup_oauth2_proxy.sh
log_time "2a. Setup oauth2-proxy ConfigMap, Secret, Deployment"

echo "   WAITING for oauth2-proxy to be ready (this may take 1-2 minutes)..."
echo "   Checking if pod is running first..."
RETRY=0
while [ $RETRY -lt 30 ]; do
  OAUTH2_STATUS=$(kubectl get pod -n security -l app=oauth2-proxy --no-headers 2>/dev/null | wc -l)
  if [ "$OAUTH2_STATUS" -ge 1 ]; then
    echo "    ? oauth2-proxy pod detected, now waiting for Ready condition..."
    break
  fi
  echo "    (waiting for pod to be created, attempt $((RETRY+1))/30)"
  sleep 2
  ((RETRY++))
done

if kubectl wait --for=condition=Ready=True pod \
  -l app=oauth2-proxy \
  -n security \
  --timeout=240s 2>&1 | grep -q "condition met"; then
  echo "    ? oauth2-proxy is ready"
else
  echo "?  oauth2-proxy condition check - verifying actual status..."
  OAUTH2_READY=$(kubectl get pod -n security -l app=oauth2-proxy -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "unknown")
  if [ "$OAUTH2_READY" = "true" ]; then
    echo "    ? oauth2-proxy is actually READY (pod reports ready=true)"
  else
    kubectl get pod -n security -l app=oauth2-proxy -o wide || true
    echo "    (WARNING: oauth2-proxy status unclear, it may still be initializing)"
  fi
fi
log_time "2b. Wait for oauth2-proxy ready"

# ======== INGRESS ROUTES SETUP ========
echo ""
echo "? Step 3: Deploying Ingress routes..."

if [ ! -d "infras/k8s-yaml/ingress" ]; then
  echo "? ERROR: ingress directory not found at infras/k8s-yaml/ingress"
  exit 1
fi

echo "   Applying public, OAuth2, and internal ingress routes..."
# Apply only YAML files, exclude bash scripts
kubectl apply -f infras/k8s-yaml/ingress/01_ingress_public.yaml
kubectl apply -f infras/k8s-yaml/ingress/02_ingress_oauth2_callback.yaml
kubectl apply -f infras/k8s-yaml/ingress/03_ingress_internal.yaml
kubectl apply -f infras/k8s-yaml/ingress/05_nginx_ingress_service.yaml
kubectl apply -f infras/k8s-yaml/ingress/07_oauth2_proxy_alias.yaml
log_time "3a. Deploy ingress routes"

echo "   Checking ingress status..."
kubectl get ingress -A 2>/dev/null | head -15 || echo "    (ingress resources initializing)"
log_time "3b. Ingress deployment checkpoint"

# ========================
# 4. Deploy Cert-Manager Issuer
# ========================
echo ""
echo "? Step 4: Setting up cert-manager issuer..."
kubectl apply -f infras/k8s-yaml/10-cert-manager-issuer.yaml
log_time "4a. Apply cert-manager-issuer.yaml"

# ========================
# 5. Deploy Vault
# ========================
echo ""
echo "? Step 5: Deploying Vault infrastructure..."
kubectl apply -f infras/k8s-yaml/11-vault.yaml
log_time "5a. Apply Vault deployment"

echo "    Waiting for Vault pods..."
sleep 10
kubectl get pod -n vault -o wide 2>/dev/null | grep vault || echo "    (Vault pods initializing)"
log_time "5b. Wait for Vault initialization"

# ========================
# 6. Vault Configuration Scripts
# ========================
echo ""
echo "?  Step 6: Running Vault configuration scripts..."

if [ ! -d "infras/k8s-yaml/vault-scripts" ]; then
  echo "? ERROR: vault-scripts directory not found!"
  exit 1
fi

cd infras/k8s-yaml/vault-scripts

echo "   o Running 01_setup_vault_dev.sh..."
if [ -f "01_setup_vault_dev.sh" ]; then
  bash 01_setup_vault_dev.sh || echo "?  01_setup_vault_dev.sh encountered issues"
  log_time "6a. Setup Vault DEV"
else
  echo "?  01_setup_vault_dev.sh not found, skipping"
fi

echo "   o Running 02_init_vault_prod.sh..."
if [ -f "02_init_vault_prod.sh" ]; then
  bash 02_init_vault_prod.sh || echo "?  02_init_vault_prod.sh encountered issues"
  log_time "6b. Init Vault PROD"
else
  echo "?  02_init_vault_prod.sh not found, skipping"
fi

echo "   o Running 03_setup_vault_prod.sh..."
if [ -f "03_setup_vault_prod.sh" ]; then
  bash 03_setup_vault_prod.sh || echo "?  03_setup_vault_prod.sh encountered issues"
  log_time "6c. Setup Vault PROD"
else
  echo "?  03_setup_vault_prod.sh not found, skipping"
fi

echo "   o Running 04_push_static_secrets.sh..."
if [ -f "04_push_static_secrets.sh" ]; then
  bash 04_push_static_secrets.sh || echo "?  04_push_static_secrets.sh encountered issues"
  log_time "6d. Push static secrets"
else
  echo "?  04_push_static_secrets.sh not found, skipping"
fi

echo "   o Running 05_setup_dynamic_db.sh..."
if [ -f "05_setup_dynamic_db.sh" ]; then
  bash 05_setup_dynamic_db.sh || echo "?  05_setup_dynamic_db.sh encountered issues"
  log_time "6e. Setup dynamic DB"
else
  echo "?  05_setup_dynamic_db.sh not found, skipping"
fi

echo "   o Running 06_setup_policies.sh..."
if [ -f "06_setup_policies.sh" ]; then
  bash 06_setup_policies.sh || echo "?  06_setup_policies.sh encountered issues"
  log_time "6f. Setup policies"
else
  echo "?  06_setup_policies.sh not found, skipping"
fi

echo "   o Applying Vault injector..."
if [ -f "07_install_injector.sh" ]; then
  bash 07_install_injector.sh || echo "?  07_install_injector.sh encountered issues"
  log_time "6g. Install injector"
else
  echo "?  07_install_injector.sh not found, trying YAML instead..."
  if [ -f "vault-injector-values.yaml" ]; then
    kubectl apply -f vault-injector-values.yaml 2>/dev/null || echo "    (vault injector YAML apply)"
  fi
fi

cd - > /dev/null

# ========================
# 7. COMPREHENSIVE VALIDATION
# ========================
echo ""
echo "? Step 7: Comprehensive validation of Phase 2..."

echo ""
echo "? Checking all deployed services..."
echo ""
echo "? 1. KEYCLOAK STATUS:"
kubectl get pod -n security -l app=keycloak -o wide 2>/dev/null || echo "  (No keycloak pods found)"

echo ""
echo "? 2. OAUTH2-PROXY STATUS:"
kubectl get pod -n security -l app=oauth2-proxy -o wide 2>/dev/null || echo "  (No oauth2-proxy pods found)"

echo ""
echo "? 3. INGRESS ROUTES:"
kubectl get ingress -A 2>/dev/null || echo "  (No ingress routes found)"

echo ""
echo "? 4. KAFKA STATUS:"
kubectl get pod -n data -l app.kubernetes.io/name=kafka -o wide 2>/dev/null || echo "  (No kafka pods found)"

echo ""
echo "? 5. KONG STATUS:"
kubectl get pod -n gateway -l app=kong-gateway -o wide 2>/dev/null || echo "  (No kong pods found)"

echo ""
echo "? 6. VAULT STATUS:"
kubectl get pod -n vault -l app=vault -o wide 2>/dev/null || echo "  (No vault pods found)"

echo ""
echo "? 7. MYSQL STATUS:"
kubectl get pod -n data -l app=mysql -o wide 2>/dev/null || echo "  (No mysql pods found)"

echo ""
echo "? 8. CERTIFICATE ISSUERS:"
kubectl get clusterissuer,issuer -A 2>/dev/null || echo "  (No issuers found)"

echo ""
echo "? All services summary:"
echo "  Total Pods (all namespaces):"
kubectl get pod -A --no-headers 2>/dev/null | wc -l
echo "  Running pods:"
kubectl get pod -A --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l
echo "  Failed/Pending pods:"
kubectl get pod -A --field-selector=status.phase!=Running --no-headers 2>/dev/null | head -10

log_time "7. Final validation"

# ========================
# COMPLETED
# ========================
echo ""
echo "? PART 2 COMPLETED: Infrastructure, Auth, Ingress, and Vault deployed"
echo ""
echo "? Infrastructure Status:"
echo "   MySQL & phpMyAdmin - Deployed to 'data' namespace"
echo "   Keycloak - Deployed to 'security' namespace (CRITICAL)"
echo "   oauth2-proxy - Deployed to 'security' namespace (depends on Keycloak)"
echo "   Kafka - Deployed to 'data' namespace"
echo "   Kong - Deployed to 'gateway' namespace"
echo "   Vault - Deployed to 'vault' namespace"
echo "   Ingress Routes - Deployed to multiple namespaces (gateway, security, data)"
echo ""
echo "? Ingress Routes Deployed:"
echo "   - Public API routes (Kong proxy)"
echo "   - OAuth2 callback routes"
echo "   - Internal tools routes"
echo "   - Service aliases"
echo ""
echo "? NOTE: Services may take several minutes to fully stabilize!"
echo "   Use: kubectl get pod -A to check status"
echo ""
echo "Next steps:"
echo "  1. Wait 1-2 minutes for services to stabilize"
echo "  2. Check: kubectl get pod -A | grep -E '(mysql|keycloak|kafka|kong|vault)'"
echo "  3. Run: bash 03-deploy-microservices.sh"
echo ""
