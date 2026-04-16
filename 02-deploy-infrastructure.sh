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

# ==================== CONFIGURATION ====================
CLUSTER_NAME="job7189"
REGISTRY_HOST="localhost:5000"
NODE_REGISTRY_ENDPOINT="172.17.0.1:5000"
KEYCLOAK_IMAGE_REPO="job7189/keycloak-custom"
KEYCLOAK_IMAGE_TAG="v1.0"
FORCE_REBUILD_IMAGES="${FORCE_REBUILD_IMAGES:-0}"

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

wait_for_keycloak_admin_api() {
  local pod_name=$1
  local admin_password=$2
  local retries=${3:-30}

  echo "   Waiting for Keycloak Admin API..."
  for ((attempt=1; attempt<=retries; attempt++)); do
    if kubectl exec -n security "$pod_name" -- /opt/keycloak/bin/kcadm.sh config credentials \
      --server http://127.0.0.1:8080 \
      --realm master \
      --user admin \
      --password "$admin_password" >/dev/null 2>&1; then
      echo "    ? Keycloak Admin API ready"
      return 0
    fi
    echo "    (admin API not ready yet, attempt $attempt/$retries)"
    sleep 5
  done

  echo "?  Keycloak Admin API readiness timeout"
  return 1
}

get_secret_value() {
  local namespace=$1
  local key=$2

  kubectl get secret app-secrets -n "$namespace" \
    -o go-template="{{index .data \"$key\"}}" 2>/dev/null | base64 -d 2>/dev/null || true
}

current_mysql_root_password() {
  kubectl exec -n data deploy/mysql -- sh -lc 'printf "%s" "$MYSQL_ROOT_PASSWORD"' 2>/dev/null || true
}

ensure_local_registry() {
  if [ ! -d "infras/local-registry" ]; then
    echo "? ERROR: infras/local-registry directory not found"
    return 1
  fi

  if docker ps 2>/dev/null | grep -q "local-registry"; then
    echo "   ✓ Local Registry already running"
    return 0
  fi

  echo "   Starting local Docker Registry via docker-compose..."
  (cd infras/local-registry && docker-compose up -d)
  sleep 2
  echo "   ✓ Local Registry started"
}

configure_kind_registry_access() {
  local registry_endpoint=$1
  local nodes
  local node

  nodes=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null || true)
  if [ -z "$nodes" ]; then
    nodes=$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^job7189-' || true)
  fi

  if [ -z "$nodes" ]; then
    echo "? ERROR: Unable to find Kind nodes for cluster $CLUSTER_NAME"
    return 1
  fi

  for node in $nodes; do
    docker exec "$node" sh -lc "mkdir -p /etc/containerd/certs.d/${registry_endpoint}"
    docker exec "$node" sh -lc "cat > /etc/containerd/certs.d/${registry_endpoint}/hosts.toml <<'EOF'
server = \"http://${registry_endpoint}\"

[host.\"http://${registry_endpoint}\"]
  capabilities = [\"pull\", \"resolve\", \"push\"]
  skip_verify = true
EOF"
  done

  echo "   ✓ Kind nodes configured for registry endpoint: ${registry_endpoint}"
}

registry_has_tag() {
  local repository=$1
  local tag=$2
  local tags_json

  if ! command -v curl >/dev/null 2>&1; then
    return 1
  fi

  tags_json=$(curl -fsS "http://${REGISTRY_HOST}/v2/${repository}/tags/list" 2>/dev/null || true)
  echo "$tags_json" | grep -q "\"${tag}\""
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

# Ensure required namespaces exist (idempotent)
for ns in vault data management job7189-apps security gateway monitoring ingress-nginx cert-manager; do
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "? Namespace '$ns' not found — creating"
    kubectl create namespace "$ns" || true
  fi
done
log_time "Pre-flight: ensure namespaces"

# read -p "? Continue with infrastructure deployment? (yes/no): " answer
# [[ "$answer" == "yes" ]] || exit 1

# ========================
# 1. Deploy Base Infrastructure (ZTA: Random Credentials)
# ========================
echo ""
echo "🔐 Step 1: Generating secure credentials (ZTA — no hardcoded passwords)..."

# Prefer active credentials when components already exist to avoid password drift.
MYSQL_ROOT_PASS=""
KEYCLOAK_ADMIN_PASS=""
VAULT_MANAGER_PASS=""

ACTIVE_MYSQL_ROOT_PASS=$(current_mysql_root_password)
if [ -n "$ACTIVE_MYSQL_ROOT_PASS" ]; then
  MYSQL_ROOT_PASS="$ACTIVE_MYSQL_ROOT_PASS"
  echo "   ✓ Reusing active MySQL root password from running mysql pod"
else
  SECRET_MYSQL_ROOT_PASS=$(get_secret_value data mysql-root-password)
  if [ -n "$SECRET_MYSQL_ROOT_PASS" ]; then
    MYSQL_ROOT_PASS="$SECRET_MYSQL_ROOT_PASS"
    echo "   ✓ Reusing MySQL root password from existing secret"
  else
    MYSQL_ROOT_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    echo "   ✓ Generated new MySQL root password"
  fi
fi

KEYCLOAK_ADMIN_PASS=$(get_secret_value security keycloak-admin-password)
if [ -z "$KEYCLOAK_ADMIN_PASS" ]; then
  KEYCLOAK_ADMIN_PASS=$(get_secret_value data keycloak-admin-password)
fi
if [ -n "$KEYCLOAK_ADMIN_PASS" ]; then
  echo "   ✓ Reusing Keycloak admin password from existing secret"
else
  KEYCLOAK_ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
  echo "   ✓ Generated new Keycloak admin password"
fi

VAULT_MANAGER_PASS=$(get_secret_value data vault-manager-password)
if [ -n "$VAULT_MANAGER_PASS" ]; then
  echo "   ✓ Reusing Vault manager password from existing secret"
else
  VAULT_MANAGER_PASS=$(openssl rand -base64 20 | tr -d '/+=' | head -c 20)
  echo "   ✓ Generated new Vault manager password"
fi

# ZTA: Create Kubernetes Secret with generated passwords (do NOT store MySQL root here)
# Note: MySQL root password is stored only in Vault (and optionally a minimal, namespaced secret
# created during bootstrap). Avoid writing mysql-root-password into the cluster-wide `app-secrets`.
kubectl create secret generic app-secrets \
  --namespace=data \
  --from-literal=keycloak-admin-password="$KEYCLOAK_ADMIN_PASS" \
  --from-literal=vault-manager-password="$VAULT_MANAGER_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Kubernetes Secret 'app-secrets' created in namespace 'data' (without mysql-root-password)"

# Also create a copy in security namespace for Keycloak (without mysql password)
kubectl create secret generic app-secrets \
  --namespace=security \
  --from-literal=keycloak-admin-password="$KEYCLOAK_ADMIN_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Kubernetes Secret 'app-secrets' created in namespace 'security' (without mysql-root-password)"

# NOTE: For the pure Vault-driven flow we no longer create a K8s secret for MySQL root.
echo "   ✓ Skipping creation of mysql-root K8s Secret (using Vault-driven bootstrap)"

log_time "1a. Generate ZTA credentials"

echo "   Deploying MySQL init ConfigMap (empty databases only)..."
kubectl apply -f infras/k8s-yaml/mysql-init-configmap.yaml
log_time "1b. Apply mysql-init-configmap.yaml"

echo "   Deploying MySQL & phpMyAdmin..."
kubectl apply -f infras/k8s-yaml/01-mysql-phpmyadmin.yaml
log_time "1c. Apply 01-mysql-phpmyadmin.yaml"

echo "   Waiting for MySQL pods to be Ready (up to 180s)"
wait_for_pods "app=mysql" data 180


# ======== KEYCLOAK SPECIAL HANDLING ========
echo ""
echo "? Building and deploying Keycloak (registry mode)..."

echo "   Step 0: Ensuring local registry is ready..."
if ! ensure_local_registry; then
  echo "? ERROR: Failed to start local registry"
  exit 1
fi
log_time "1d0. Ensure local registry"

echo "   Step 0b: Configuring Kind nodes for registry pulls..."
if ! configure_kind_registry_access "$NODE_REGISTRY_ENDPOINT"; then
  echo "? ERROR: Failed to configure Kind registry access"
  exit 1
fi
log_time "1d0b. Configure Kind registry access"

KEYCLOAK_LOCAL_IMAGE="${REGISTRY_HOST}/${KEYCLOAK_IMAGE_REPO}:${KEYCLOAK_IMAGE_TAG}"

if [ "$FORCE_REBUILD_IMAGES" != "1" ] && registry_has_tag "$KEYCLOAK_IMAGE_REPO" "$KEYCLOAK_IMAGE_TAG"; then
  echo "   Step 1: Keycloak image already exists in registry, skipping build"
  docker pull "$KEYCLOAK_LOCAL_IMAGE" >/dev/null 2>&1 || true
else
  echo "   Step 1: Building Keycloak Docker image..."
  cd infras/keycloak
  docker build -t "$KEYCLOAK_LOCAL_IMAGE" .
  cd ../..

  echo "   Step 2: Pushing Keycloak image to local registry..."
  docker push "$KEYCLOAK_LOCAL_IMAGE"
fi
log_time "1d1. Build/push Keycloak image"

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

# Import additional realm for API auth tests without impacting existing realm-infra import.
echo ""
echo "? Importing additional Keycloak realm: job7189..."

REALM_JOB7189_FILE="infras/keycloak/realms/realm-job7189.json"
# Hardcoded from postman/job7189-auth-api.postman_collection.json
POSTMAN_CLIENT_ID="candidate-app-dev"
POSTMAN_CLIENT_SECRET="MYIpuUHIlIFyrfk1zjktZcnChO3WTFYW"

if [ ! -f "$REALM_JOB7189_FILE" ]; then
  echo "?  WARNING: $REALM_JOB7189_FILE not found, skipping additional realm import"
else
  KEYCLOAK_POD=$(kubectl get pod -n security -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$KEYCLOAK_POD" ]; then
    echo "?  WARNING: Keycloak pod not found, skipping additional realm import"
  elif wait_for_keycloak_admin_api "$KEYCLOAK_POD" "$KEYCLOAK_ADMIN_PASS"; then
    echo "   Copying $REALM_JOB7189_FILE into Keycloak pod..."
    kubectl exec -i -n security "$KEYCLOAK_POD" -- sh -c "cat > /tmp/realm-job7189.json" < "$REALM_JOB7189_FILE"

    echo "   Importing realm and enforcing Postman client credentials..."
    if kubectl exec -n security "$KEYCLOAK_POD" -- sh -c "
      set -e
      KCADM=/opt/keycloak/bin/kcadm.sh
      \$KCADM config credentials --server http://127.0.0.1:8080 --realm master --user admin --password '$KEYCLOAK_ADMIN_PASS' >/dev/null
      if \$KCADM get realms/job7189 >/dev/null 2>&1; then
        echo '    Realm job7189 already exists, skipping create'
      else
        \$KCADM create realms -f /tmp/realm-job7189.json >/dev/null
        echo '    Realm job7189 imported'
      fi

      CLIENT_UUID=\$(\$KCADM get clients -r job7189 -q clientId='$POSTMAN_CLIENT_ID' --fields id 2>/dev/null | sed -n 's/.*\"id\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p' | head -n1)
      if [ -z \"\$CLIENT_UUID\" ]; then
        echo '    ERROR: client candidate-app-dev not found in realm job7189'
        exit 1
      fi

      \$KCADM create clients/\$CLIENT_UUID/client-secret -r job7189 -s value='$POSTMAN_CLIENT_SECRET' >/dev/null
      echo '    Client secret for candidate-app-dev has been set from Postman collection'
      rm -f /tmp/realm-job7189.json
    "; then
      echo "   ? Additional realm import completed"
    else
      echo "?  WARNING: Additional realm import encountered issues"
    fi
  else
    echo "?  WARNING: Keycloak Admin API not ready, skipping additional realm import"
  fi
fi
log_time "1d5. Import realm-job7189"

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

echo "   Step 0: Pre-loading kong:3.6 image into Kind cluster nodes (avoid Docker Hub pull delay)..."
docker pull kong:3.6 2>/dev/null || true
kind load docker-image kong:3.6 --name "$CLUSTER_NAME" 2>/dev/null || true
echo "   ✓ kong:3.6 loaded into Kind cluster"
log_time "1f0. Pre-load Kong image"

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
echo "    Checking for cert-manager CRDs before applying issuer/certificate resources"
if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  kubectl apply -f infras/k8s-yaml/10-cert-manager-issuer.yaml
  log_time "4a. Apply cert-manager-issuer.yaml"
else
  echo "    ! cert-manager CRDs not found; skipping issuer/certificate apply. Ensure cert-manager is installed (run 01-setup-cluster.sh)"
  log_time "4a. Skip cert-manager issuer (CRDs missing)"
fi

# ========================
# 5. Deploy Vault
# ========================
echo ""
echo "? Step 5: Deploying Vault infrastructure..."
kubectl apply -f infras/k8s-yaml/11-vault.yaml
log_time "5a. Apply Vault deployment"

echo "    Waiting for Vault pods to be Ready (up to 180s)"
wait_for_pods "app=vault" vault 180
log_time "5b. Wait for Vault initialization"

# ========================
# 6. Vault Configuration Scripts
# ========================
echo ""
echo "?  Step 6: Running Vault fast rebuild pipeline..."

if [ ! -d "infras/k8s-yaml/vault-scripts" ]; then
  echo "? ERROR: vault-scripts directory not found!"
  exit 1
fi

cd infras/k8s-yaml/vault-scripts

echo "   o Running 99-fast-rebuild-vault.sh..."
if [ -f "99-fast-rebuild-vault.sh" ]; then
  # Pass MYSQL_ROOT_PASS to the fast rebuild pipeline so the Vault bootstrap remains the authoritative source
  MYSQL_ROOT_PASS="$MYSQL_ROOT_PASS" bash 99-fast-rebuild-vault.sh || echo "?  99-fast-rebuild-vault.sh encountered issues"
  log_time "6a. Vault fast rebuild pipeline"
else
  echo "? ERROR: 99-fast-rebuild-vault.sh not found!"
  cd - > /dev/null
  exit 1
fi

cd - > /dev/null

# ========================
# 8. Deploy ELK Stack (Elasticsearch, Kibana, Filebeat)
# ========================
echo ""
echo "📊 Step 8: Deploying ELK Stack (Elasticsearch, Kibana, Filebeat)..."

echo "   Deploying Elasticsearch & Kibana..."
kubectl apply -f infras/k8s-yaml/05-elasticsearch.yaml
log_time "8a. Apply Elasticsearch + Kibana"

echo "   Waiting for Elasticsearch to be ready..."
if kubectl wait --for=condition=Ready=True pod \
  -l app=elasticsearch \
  -n monitoring \
  --timeout=300s 2>/dev/null; then
  echo "    ✓ Elasticsearch is ready"
else
  echo "⚠  Elasticsearch wait timeout - checking status..."
  kubectl get pod -n monitoring -l app=elasticsearch -o wide || true
  echo "    (WARNING: Elasticsearch may still be initializing)"
fi
log_time "8b. Wait for Elasticsearch ready"

echo "   Deploying Filebeat..."
kubectl apply -f infras/k8s-yaml/06-filebeat.yaml
log_time "8c. Apply Filebeat"

echo "   Waiting for Filebeat to be ready..."
sleep 5
if kubectl wait --for=condition=Ready=True pod \
  -l k8s-app=filebeat \
  -n monitoring \
  --timeout=120s 2>/dev/null; then
  echo "    ✓ Filebeat is ready"
else
  echo "⚠  Filebeat wait timeout - checking status..."
  kubectl get pod -n monitoring -l k8s-app=filebeat -o wide || true
  echo "    (WARNING: Filebeat may still be starting)"
fi
log_time "8d. Wait for Filebeat ready"

echo "   Waiting for Kibana to be ready..."
if kubectl wait --for=condition=Ready=True pod \
  -l app=kibana \
  -n monitoring \
  --timeout=300s 2>/dev/null; then
  echo "    ✓ Kibana is ready"
else
  echo "⚠  Kibana wait timeout - checking status..."
  kubectl get pod -n monitoring -l app=kibana -o wide || true
  echo "    (WARNING: Kibana may still be starting)"
fi
log_time "8e. Wait for Kibana ready"

echo "✓ ELK Stack deployment completed"

# ========================
# 9. COMPREHENSIVE VALIDATION
# ========================
echo ""
echo "📋 Step 9: Comprehensive validation of Phase 2..."

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
