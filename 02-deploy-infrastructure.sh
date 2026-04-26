#!/bin/bash
# Part 2: Deploy Infrastructure Services & Vault
# This script: Deploys Cert-Manager, Vault, MySQL, Keycloak, Kafka, Kong, and ELK
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
  echo "⏱  [$step_name] Duration: ${elapsed}s"
  STEP_START_TIME=$current_time
}

print_summary() {
  local total_time=$(($(date +%s) - SCRIPT_START_TIME))
  echo ""
  echo "================================================"
  echo "✅ PART 2: INFRASTRUCTURE - TIMING SUMMARY"
  echo "================================================"
  for step in "${!STEP_TIMES[@]}"; do
    printf "  %-45s %3ds\n" "$step" "${STEP_TIMES[$step]}"
  done | sort
  echo "------------------------------------------------"
  printf "  %-45s %3ds\n" "TOTAL" "$total_time"
  echo "================================================"
}

trap print_summary EXIT

# ==================== CONFIGURATION ====================
CLUSTER_NAME="job7189"
REGISTRY_HOST="localhost:5000"
NODE_REGISTRY_ENDPOINT="172.17.0.1:5000"
KEYCLOAK_IMAGE_REPO="job7189/keycloak-custom"
KEYCLOAK_IMAGE_TAG="v1.0"
CERT_MANAGER_VERSION="v1.14.7"
FORCE_REBUILD_IMAGES="${FORCE_REBUILD_IMAGES:-0}"
WAIT_STRICT="${WAIT_STRICT:-1}"
CMD_TIMEOUT_SHORT="${CMD_TIMEOUT_SHORT:-25}"
CMD_TIMEOUT_MEDIUM="${CMD_TIMEOUT_MEDIUM:-120}"
CMD_TIMEOUT_LONG="${CMD_TIMEOUT_LONG:-600}"
VAULT_REBUILD_TIMEOUT="${VAULT_REBUILD_TIMEOUT:-900}"
DOCKER_BUILD_TIMEOUT="${DOCKER_BUILD_TIMEOUT:-1200}"
DOCKER_PUSH_TIMEOUT="${DOCKER_PUSH_TIMEOUT:-600}"

run_with_timeout() {
  local timeout_seconds=$1
  shift
  local rc=0
  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground "${timeout_seconds}s" "$@" || rc=$?
    if [ "$rc" -eq 124 ]; then
      echo "❌ Timeout after ${timeout_seconds}s: $*" >&2
    fi
    return "$rc"
  else
    "$@"
  fi
}

# ==================== HELPER FUNCTIONS ====================
wait_for_pods() {
  local label=$1
  local namespace=$2
  local timeout=${3:-300}
  local start_time current_time elapsed
  local pod_table total_pods ready_pods
  
  echo "    Checking pod status for $label in $namespace..."
  kubectl get pod -n "$namespace" -l "$label" -o wide 2>/dev/null || echo "    (pods not created yet)"

  start_time=$(date +%s)
  while true; do
    pod_table=$(kubectl get pod -n "$namespace" -l "$label" --no-headers 2>/dev/null || true)

    if [ -n "$pod_table" ]; then
      total_pods=$(printf '%s\n' "$pod_table" | awk 'NF>0 && $3 != "Terminating" {count++} END {print count+0}')
      ready_pods=$(printf '%s\n' "$pod_table" | awk 'NF>0 && $3 != "Terminating" {split($2,a,"/"); if (a[2] > 0 && a[1] == a[2]) count++} END {print count+0}')

      if [ "$total_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
        echo "    ✔ Pods ready: $label ($ready_pods/$total_pods)"
        return 0
      fi

      echo "    Waiting pods: $label ($ready_pods/$total_pods ready)"
    else
      echo "    Waiting pods: $label (0/0 ready)"
    fi

    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "⚠  Pod wait timeout for $label in $namespace"
      kubectl get pod -n "$namespace" -l "$label" || true
      if [ "$WAIT_STRICT" = "1" ]; then
        echo "❌ Strict mode enabled. Stopping due to readiness timeout."
        return 1
      fi
      echo "    (Continuing because WAIT_STRICT=0)"
      return 0
    fi

    sleep 5
  done
  return 0
}

wait_for_keycloak_admin_api() {
  local pod_name=$1
  local admin_password=$2
  local retries=${3:-30}

  echo "   Waiting for Keycloak Admin API..."
  for ((attempt=1; attempt<=retries; attempt++)); do
    if run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl exec -n security "$pod_name" -- /opt/keycloak/bin/kcadm.sh config credentials \
      --server http://127.0.0.1:8080 \
      --realm master \
      --user admin \
      --password "$admin_password" >/dev/null 2>&1; then
      echo "    ✔ Keycloak Admin API ready"
      return 0
    fi
    echo "    (admin API not ready yet, attempt $attempt/$retries)"
    sleep 5
  done
  echo "⚠  Keycloak Admin API readiness timeout"
  return 1
}

get_secret_value() {
  local namespace=$1
  local key=$2
  kubectl get secret app-secrets -n "$namespace" \
    -o go-template="{{index .data \"$key\"}}" 2>/dev/null | base64 -d 2>/dev/null || true
}

current_mysql_root_password() {
  run_with_timeout "$CMD_TIMEOUT_SHORT" kubectl exec -n data deploy/mysql -- sh -lc 'printf "%s" "$MYSQL_ROOT_PASSWORD"' 2>/dev/null || true
}

ensure_local_registry() {
  if [ ! -d "infras/local-registry" ]; then
    echo "❌ ERROR: infras/local-registry directory not found"
    return 1
  fi
  if docker ps 2>/dev/null | grep -q "local-registry"; then
    echo "   ✓ Local Registry already running"
    return 0
  fi
  echo "   Starting local Docker Registry via docker-compose..."
  run_with_timeout "$CMD_TIMEOUT_MEDIUM" bash -lc 'cd infras/local-registry && docker-compose up -d'
  sleep 2
  echo "   ✓ Local Registry started"
}

configure_kind_registry_access() {
  local registry_endpoint=$1
  local nodes=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null || true)
  if [ -z "$nodes" ]; then
    nodes=$(docker ps --format '{{.Names}}' 2>/dev/null | grep '^job7189-' || true)
  fi
  if [ -z "$nodes" ]; then
    echo "❌ ERROR: Unable to find Kind nodes for cluster $CLUSTER_NAME"
    return 1
  fi
  for node in $nodes; do
    docker exec "$node" sh -lc "mkdir -p /etc/containerd/certs.d/${registry_endpoint}"
    docker exec "$node" sh -lc "cat > /etc/containerd/certs.d/${registry_endpoint}/hosts.toml <<EOF
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
  if ! command -v curl >/dev/null 2>&1; then return 1; fi
  curl -fsS "http://${REGISTRY_HOST}/v2/${repository}/tags/list" 2>/dev/null | grep -q "\"${tag}\""
}

install_cert_manager_if_missing() {
  echo "🔍 Checking cert-manager CRDs..."
  if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
    echo "⚠ cert-manager CRDs missing - installing cert-manager..."
    run_with_timeout "$CMD_TIMEOUT_MEDIUM" kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
  else
    echo "   ✓ cert-manager CRDs present"
  fi

  kubectl wait --for=condition=Established crd/certificates.cert-manager.io --timeout=180s >/dev/null 2>&1 || true
  kubectl wait --for=condition=Established crd/issuers.cert-manager.io --timeout=180s >/dev/null 2>&1 || true
  kubectl wait --for=condition=Established crd/clusterissuers.cert-manager.io --timeout=180s >/dev/null 2>&1 || true

  if kubectl -n cert-manager rollout status deploy/cert-manager --timeout=240s \
    && kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=240s \
    && kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=240s; then
    echo "   ✓ cert-manager is healthy"
  else
    echo "❌ cert-manager is not fully healthy"
    kubectl -n cert-manager get pods -o wide || true
    return 1
  fi
}

# ==================== SCRIPT START ====================
echo ""
echo "============================================================"
echo "🚀 PART 2: INFRASTRUCTURE SERVICES & VAULT (ZTA ORDER)"
echo "============================================================"
echo ""

# Pre-flight check
echo "🔍 Pre-flight check: Verifying cluster readiness..."
if ! kubectl get nodes &>/dev/null; then
  echo "❌ ERROR: Kubernetes cluster not accessible! Run 01-setup-cluster.sh first"
  exit 1
fi
echo "   ✓ Cluster is accessible"

# Ensure required namespaces
for ns in vault data management job7189-apps security gateway monitoring ingress-nginx cert-manager; do
  kubectl get namespace "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns" >/dev/null
done
log_time "0. Pre-flight checks & Namespaces"

# ========================
# 1. Generate Credentials
# ========================
echo ""
echo "🔐 Step 1: Generating secure credentials..."

MYSQL_ROOT_PASS=$(current_mysql_root_password)
[ -z "$MYSQL_ROOT_PASS" ] && MYSQL_ROOT_PASS=$(get_secret_value data mysql-root-password)
[ -z "$MYSQL_ROOT_PASS" ] && MYSQL_ROOT_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

KEYCLOAK_ADMIN_PASS=$(get_secret_value security keycloak-admin-password)
[ -z "$KEYCLOAK_ADMIN_PASS" ] && KEYCLOAK_ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)

VAULT_MANAGER_PASS=$(get_secret_value data vault-manager-password)
[ -z "$VAULT_MANAGER_PASS" ] && VAULT_MANAGER_PASS=$(openssl rand -base64 20 | tr -d '/+=' | head -c 20)

# Create secrets (NOTE: Injecting MySQL password to Security namespace so Keycloak works)
kubectl create secret generic app-secrets --namespace=data \
  --from-literal=mysql-root-password="$MYSQL_ROOT_PASS" \
  --from-literal=keycloak-admin-password="$KEYCLOAK_ADMIN_PASS" \
  --from-literal=vault-manager-password="$VAULT_MANAGER_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic app-secrets --namespace=security \
  --from-literal=mysql-root-password="$MYSQL_ROOT_PASS" \
  --from-literal=keycloak-admin-password="$KEYCLOAK_ADMIN_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

log_time "1. Generate Credentials"

# ========================
# 2. Deploy Cert-Manager Issuer (MOVED UP FOR VAULT)
# ========================
echo ""
echo "🔐 Step 2: Setting up cert-manager issuer..."
install_cert_manager_if_missing
if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  kubectl apply -f infras/k8s-yaml/10-cert-manager-issuer.yaml
  sleep 5
else
  echo "   ⚠ Skip cert-manager issuer (CRDs missing)"
fi
log_time "2. Setup Cert-Manager Issuer"

# ========================
# 3. Deploy Vault & Config (MOVED UP FOR MYSQL)
# ========================
echo ""
echo "🏦 Step 3: Deploying Vault infrastructure..."

# F-1 fix (audit finding 2025-Q4): vault-dev token KHÔNG còn hard-coded.
# Tạo Secret 'vault-dev-token' với giá trị random per-cluster TRƯỚC khi apply
# Deployment. Re-apply sẽ giữ nguyên token cũ (idempotent).
if ! kubectl get secret vault-dev-token -n vault >/dev/null 2>&1; then
  VAULT_DEV_TOKEN=$(openssl rand -hex 16)
  kubectl create secret generic vault-dev-token --namespace=vault \
    --from-literal=token="$VAULT_DEV_TOKEN"
  echo "   🔑 Sinh vault-dev token mới (random, lưu trong Secret vault-dev-token)"
else
  echo "   ✓ vault-dev-token Secret đã tồn tại — tái sử dụng"
fi

kubectl apply -f infras/k8s-yaml/11-vault.yaml

echo "   Waiting for Vault pod to reach Running phase before bootstrap..."
kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l app=vault -n vault --timeout=180s >/dev/null 2>&1 || {
  echo "❌ Vault pod did not reach Running phase in time"
  kubectl get pod -n vault -l app=vault -o wide || true
  exit 1
}

echo "   Running Vault fast rebuild pipeline..."
if [ -d "infras/k8s-yaml/vault-scripts" ] && [ -f "infras/k8s-yaml/vault-scripts/99-fast-rebuild-vault.sh" ]; then
  if ! run_with_timeout "$VAULT_REBUILD_TIMEOUT" bash -lc "cd infras/k8s-yaml/vault-scripts && MYSQL_ROOT_PASS='$MYSQL_ROOT_PASS' bash 99-fast-rebuild-vault.sh"; then
    echo "❌ Vault config script timed out/failed"
    exit 1
  fi
else
  echo "⚠ Vault script not found, skipping config"
fi

# After bootstrap/unseal, Vault must be Ready in strict mode.
wait_for_pods "app=vault" vault 240
log_time "3. Vault Deployment & Config"

# ========================
# 4. Deploy MySQL (Now it can read from Vault)
# ========================
echo ""
echo "🗄️ Step 4: Deploying MySQL & phpMyAdmin..."
kubectl apply -f infras/k8s-yaml/mysql-init-configmap.yaml
kubectl apply -f infras/k8s-yaml/01-mysql-phpmyadmin.yaml
wait_for_pods "app=mysql" data 180

MYSQL_POD=$(kubectl get pod -n data -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$MYSQL_POD" ]; then
  READY_STATE=$(kubectl get pod -n data "$MYSQL_POD" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  if [ "$READY_STATE" != "true" ]; then
    echo "⚠ MySQL pod not ready, attempting rollout restart..."
    kubectl -n data rollout restart deploy/mysql || true
    kubectl wait --for=condition=Ready pod -l app=mysql -n data --timeout=120s 2>/dev/null || true
  fi
fi
log_time "4. MySQL & phpMyAdmin"

# ========================
# 5. Deploy Keycloak (Now MySQL is ready)
# ========================
echo ""
echo "🛡️ Step 5: Building and deploying Keycloak..."
ensure_local_registry || true
configure_kind_registry_access "$NODE_REGISTRY_ENDPOINT" || true

KEYCLOAK_LOCAL_IMAGE="${REGISTRY_HOST}/${KEYCLOAK_IMAGE_REPO}:${KEYCLOAK_IMAGE_TAG}"
if [ "$FORCE_REBUILD_IMAGES" != "1" ] && registry_has_tag "$KEYCLOAK_IMAGE_REPO" "$KEYCLOAK_IMAGE_TAG"; then
  echo "   ✓ Keycloak image exists, skipping build"
else
  echo "   Building Keycloak image..."
  run_with_timeout "$DOCKER_BUILD_TIMEOUT" bash -lc "cd infras/keycloak && docker build -t '$KEYCLOAK_LOCAL_IMAGE' ."
  run_with_timeout "$DOCKER_PUSH_TIMEOUT" docker push "$KEYCLOAK_LOCAL_IMAGE"
fi

kubectl apply -f infras/k8s-yaml/02-keycloak.yaml
echo "   Waiting for Keycloak rollout (up to 900s due to first-boot DB migration/import)..."
if kubectl -n security rollout status deploy/keycloak --timeout=900s; then
  echo "   ✔ Keycloak rollout succeeded"
else
  echo "⚠  Keycloak rollout timeout/failure"
  kubectl -n security get pods -l app=keycloak -o wide || true
  KEYCLOAK_POD_DIAG=$(kubectl get pod -n security -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$KEYCLOAK_POD_DIAG" ]; then
    kubectl -n security describe pod "$KEYCLOAK_POD_DIAG" | sed -n '/^Events:/,$p' || true
    kubectl -n security logs "$KEYCLOAK_POD_DIAG" --tail=120 || true
    kubectl -n security logs "$KEYCLOAK_POD_DIAG" --previous --tail=120 || true
  fi
  if [ "$WAIT_STRICT" = "1" ]; then
    echo "❌ Strict mode enabled. Stopping due to Keycloak rollout timeout."
    exit 1
  fi
  echo "   (Continuing because WAIT_STRICT=0)"
fi

# Keep generic pod readiness check as a second gate after rollout status.
wait_for_pods "app=keycloak" security 600

# Import Keycloak Realm safely
echo "   Importing Keycloak realm: job7189..."
REALM_JOB7189_FILE="infras/keycloak/realms/realm-job7189.json"
KEYCLOAK_POD=$(kubectl get pod -n security -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -f "$REALM_JOB7189_FILE" ] && [ -n "$KEYCLOAK_POD" ]; then
  if wait_for_keycloak_admin_api "$KEYCLOAK_POD" "$KEYCLOAK_ADMIN_PASS"; then
    kubectl exec -i -n security "$KEYCLOAK_POD" -- sh -c "cat > /tmp/realm-job7189.json" < "$REALM_JOB7189_FILE" || true
    kubectl exec -n security "$KEYCLOAK_POD" -- sh -c "
      /opt/keycloak/bin/kcadm.sh config credentials --server http://127.0.0.1:8080 --realm master --user admin --password '$KEYCLOAK_ADMIN_PASS' >/dev/null
      /opt/keycloak/bin/kcadm.sh create realms -f /tmp/realm-job7189.json >/dev/null 2>&1 || echo 'Realm maybe exists'
    " || echo "⚠ Realm import script encountered an error, continuing..."
  fi
fi
log_time "5. Keycloak Setup"

# ========================
# 6. Deploy Kafka & Kong
# ========================
echo ""
echo "📨 Step 6: Deploying Kafka & Kong..."
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
wait_for_pods "app=kong-gateway" gateway 240
log_time "6. Kafka & Kong"

# ========================
# 7. Oauth2-Proxy
# ========================
echo ""
echo "🔐 Step 7: Setting up oauth2-proxy..."
if ! run_with_timeout "$CMD_TIMEOUT_MEDIUM" bash infras/k8s-yaml/ingress/00_setup_oauth2_proxy.sh; then
  if [ "$WAIT_STRICT" = "1" ]; then
    echo "❌ oauth2-proxy setup script timed out/failed"
    exit 1
  fi
  echo "⚠ oauth2-proxy setup script timed out/failed, continuing because WAIT_STRICT=0"
fi

echo "   Checking if pod is running first..."
RETRY=0
while [ $RETRY -lt 30 ]; do
  OAUTH2_STATUS=$(kubectl get pod -n security -l app=oauth2-proxy --no-headers 2>/dev/null | wc -l)
  if [ "$OAUTH2_STATUS" -ge 1 ]; then
    echo "    ✔ oauth2-proxy pod detected!"
    break
  fi
  echo "    (waiting... attempt $((RETRY+1))/30)"
  sleep 2
  ((++RETRY)) # LỖI CRITICAL ĐÃ ĐƯỢC FIX Ở ĐÂY
done

wait_for_pods "app=oauth2-proxy" security 240
log_time "7. Oauth2-Proxy"

# ========================
# 8. Ingress Routes
# ========================
echo ""
echo "🌐 Step 8: Deploying Ingress routes..."
if [ -d "infras/k8s-yaml/ingress" ]; then
  kubectl apply -f infras/k8s-yaml/ingress/01_ingress_public.yaml
  kubectl apply -f infras/k8s-yaml/ingress/02_ingress_oauth2_callback.yaml
  kubectl apply -f infras/k8s-yaml/ingress/03_ingress_internal.yaml
  kubectl apply -f infras/k8s-yaml/ingress/05_nginx_ingress_service.yaml
  kubectl apply -f infras/k8s-yaml/ingress/07_oauth2_proxy_alias.yaml
fi
log_time "8. Ingress Routes"

# ========================
# 9. ELK Stack
# ========================
echo ""
echo "📊 Step 9: Deploying ELK Stack..."
kubectl apply -f infras/k8s-yaml/05-elasticsearch.yaml
wait_for_pods "app=elasticsearch" monitoring 300

kubectl apply -f infras/k8s-yaml/06-filebeat.yaml
wait_for_pods "k8s-app=filebeat" monitoring 120

kubectl wait --for=condition=Ready=True pod -l app=kibana -n monitoring --timeout=300s 2>/dev/null || echo "⚠ Kibana initializing"
log_time "9a. ELK Stack"

# ========================
# 9b. Prometheus + Grafana (observability full stack)
# ========================
echo ""
echo "📊 Step 9b: Deploying Prometheus + Grafana..."
kubectl apply -f infras/k8s-yaml/08-prometheus.yaml
wait_for_pods "app=prometheus" monitoring 180

kubectl apply -f infras/k8s-yaml/09-grafana.yaml
wait_for_pods "app=grafana" monitoring 180
log_time "9b. Prometheus + Grafana"

# ========================
# 9c. Microsegmentation Policies (ZTA enforcement)
# ========================
echo ""
echo "🛡️ Step 9c: Applying ZTA Microsegmentation policies..."
ZTA_ENABLE_POLICIES="${ZTA_ENABLE_POLICIES:-1}"
if [ "$ZTA_ENABLE_POLICIES" = "1" ]; then
  POLICY_DIR="infras/k8s-yaml/cilium-policies"
  if [ -d "$POLICY_DIR" ]; then
    kubectl apply -f "$POLICY_DIR/00-default-deny.yaml" && echo "   ✓ Default Deny applied"
    kubectl apply -f "$POLICY_DIR/01-allow-egress-dns.yaml" && echo "   ✓ Allow DNS applied"
    kubectl apply -f "$POLICY_DIR/02-allow-egress-data.yaml" && echo "   ✓ Allow Data egress applied"
    kubectl apply -f "$POLICY_DIR/03-allow-ingress-kong.yaml" && echo "   ✓ Allow Kong ingress applied"
    kubectl apply -f "$POLICY_DIR/04-allow-internal-api-strict.yaml" && echo "   ✓ Allow Internal API (L7) applied"
    echo "   ✓ ZTA Microsegmentation enabled for namespace job7189-apps"
  else
    echo "   ⚠ Policy directory not found: $POLICY_DIR"
  fi
else
  echo "   ⏩ Skipped (ZTA_ENABLE_POLICIES=0)"
fi
log_time "9c. Microsegmentation Policies"

# ========================
# 10. VALIDATION
# ========================
echo ""
echo "📋 Step 10: Validation Summary..."

# Check for pods in truly problematic states (exclude Completed/Succeeded which are normal)
NON_RUNNING_PODS=$(kubectl get pod -A --no-headers 2>/dev/null \
  | awk '$4 != "Running" && $4 != "Completed" && $4 != "Succeeded" {print}' || true)
if [ -n "$NON_RUNNING_PODS" ]; then
  echo "⚠ Pods not in Running/Completed state:"
  echo "$NON_RUNNING_PODS"
  # Count only truly failed pods (not init or pending briefly)
  FAILED_COUNT=$(echo "$NON_RUNNING_PODS" | grep -cE 'Error|CrashLoop|Failed' || true)
  if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "❌ Found $FAILED_COUNT pods in error state"
    exit 1
  fi
  echo "   (Non-critical pods still initializing — continuing)"
fi

# Check Ready status only for Running pods
NOT_READY_PODS=$(kubectl get pod -A --no-headers 2>/dev/null \
  | awk '$4 == "Running" {split($3,a,"/"); if (a[1] != a[2]) print $0}' || true)

if [ -n "$NOT_READY_PODS" ]; then
  echo "⚠ Running pods not fully Ready (READY column x/x):"
  echo "$NOT_READY_PODS"
  echo "   (Some pods may still be initializing — non-fatal)"
fi

echo "   ✓ Infrastructure validation passed"
echo "✔ PART 2 COMPLETED SUCCESSFULLY"