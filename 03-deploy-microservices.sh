#!/bin/bash
# Part 3: Deploy Ingress Routes & Microservices
# This script: Deploys Ingress configurations and all microservices via Helmfile
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
  echo "? PART 3: MICROSERVICES - TIMING SUMMARY"
  echo "????????????????????????????????????????????????"
  for step in "${!STEP_TIMES[@]}"; do
    printf "  %-45s %3ds\n" "$step" "${STEP_TIMES[$step]}"
  done | sort
  echo "------------------------------------------------"
  printf "  %-45s %3ds\n" "TOTAL" "$total_time"
  echo "????????????????????????????????????????????????"
}

trap print_summary EXIT

# ==================== VALIDATION/RECOVERY FUNCTIONS ====================
declare -a LARAVEL_SERVICES=(
  "identity-service"
  "workspace-service"
  "job-service"
  "hiring-service"
  "candidate-service"
  "communication-service"
  "storage-service"
)

print_failed_pod_diagnostics() {
  local pod_name=$1

  echo ""
  echo "   🔎 Diagnostics for pod: $pod_name"
  echo "   ----------------------------------------"

  echo "   Init Containers:"
  kubectl describe pod -n job7189-apps "$pod_name" 2>/dev/null | sed -n '/^Init Containers:/,/^Containers:/p' || true

  echo ""
  echo "   Events:"
  kubectl describe pod -n job7189-apps "$pod_name" 2>/dev/null | sed -n '/^Events:/,$p' || true

  echo ""
  echo "   Init container logs:"
  for init_name in $(kubectl get pod -n job7189-apps "$pod_name" -o jsonpath='{range .spec.initContainers[*]}{.name}{" "}{end}' 2>/dev/null); do
    echo "   --- $pod_name / $init_name ---"
    kubectl logs -n job7189-apps "$pod_name" -c "$init_name" --tail=200 2>/dev/null || true
  done
}

verify_registry_tags() {
  local missing=0

  if ! command -v curl >/dev/null 2>&1; then
    echo "❌ ERROR: curl is required to verify registry tags"
    return 1
  fi

  echo "   Verifying required Laravel images in local registry ($REGISTRY_HOST)..."
  for full_image in "${REQUIRED_IMAGES[@]}"; do
    local repo="${full_image%:*}"
    local tag="${full_image##*:}"
    local tags_json

    tags_json=$(curl -fsS "http://${REGISTRY_HOST}/v2/${repo}/tags/list" 2>/dev/null || true)
    if echo "$tags_json" | grep -q "\"${tag}\""; then
      echo "   ✓ ${repo}:${tag}"
    else
      echo "   ✗ Missing in registry: ${repo}:${tag}"
      missing=$((missing + 1))
    fi
  done

  [ "$missing" -eq 0 ]
}

wait_for_vault_unsealed() {
  local timeout=${1:-300}
  local start_time=$(date +%s)

  echo "   Waiting for Vault pod to become ready..."
  kubectl wait --for=condition=Ready=True pod/vault-0 -n vault --timeout="${timeout}s" >/dev/null 2>&1 || true

  while true; do
    if kubectl exec -n vault vault-0 -- vault status 2>/dev/null | grep -q "Sealed[[:space:]]*false"; then
      echo "   ✓ Vault is initialized and unsealed"
      return 0
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "❌ ERROR: Vault is not unsealed after ${timeout}s"
      kubectl get pod -n vault -o wide || true
      return 1
    fi

    echo "   ... Vault not ready yet (${elapsed}s/${timeout}s)"
    sleep 5
  done
}

get_vault_root_token() {
  local init_file="infras/k8s-yaml/vault-scripts/vault-prod-init.json"
  if [ ! -f "$init_file" ]; then
    echo ""
    return 1
  fi

  python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('root_token',''))" "$init_file" 2>/dev/null || true
}

vault_dynamic_db_ready() {
  local root_token=$1

  if [ -z "$root_token" ]; then
    return 1
  fi

  if ! kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN='${root_token}' vault read -format=json database/config/mysql >/dev/null 2>&1"; then
    return 1
  fi

  local svc
  for svc in "${LARAVEL_SERVICES[@]}"; do
    if ! kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN='${root_token}' vault read -format=json database/roles/${svc} >/dev/null 2>&1"; then
      echo "   ✗ Missing Vault DB role: ${svc}"
      return 1
    fi
  done

  return 0
}

ensure_vault_dynamic_db_ready() {
  local repair_script="infras/k8s-yaml/vault-scripts/99-fast-rebuild-vault.sh"
  local attempt

  for attempt in 1 2; do
    echo "   Vault dynamic DB readiness check (attempt ${attempt}/2)..."

    if wait_for_vault_unsealed 300; then
      local root_token
      root_token=$(get_vault_root_token || true)

      if vault_dynamic_db_ready "$root_token"; then
        echo "   ✓ Vault dynamic credentials backend is ready"
        return 0
      fi
    fi

    if [ "$attempt" -lt 2 ]; then
      if [ ! -f "$repair_script" ]; then
        echo "❌ ERROR: Vault repair script not found: $repair_script"
        return 1
      fi

      echo "   ⚠️  Vault dynamic DB config is missing. Running repair pipeline..."
      bash "$repair_script"
    fi
  done

  echo "❌ ERROR: Vault dynamic credentials backend is not ready after repair"
  return 1
}

wait_for_laravel_deployments_ready() {
  local timeout=${1:-900}
  local start_time=$(date +%s)

  echo ""
  echo "   Waiting for Laravel deployments to become Ready..."

  while true; do
    local not_ready=0
    local svc

    for svc in "${LARAVEL_SERVICES[@]}"; do
      local desired ready
      desired=$(kubectl get deploy -n job7189-apps "$svc" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
      ready=$(kubectl get deploy -n job7189-apps "$svc" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

      desired=${desired:-0}
      ready=${ready:-0}

      if [ "$desired" -eq 0 ] || [ "$ready" -lt "$desired" ]; then
        not_ready=$((not_ready + 1))
      fi
    done

    if [ "$not_ready" -eq 0 ]; then
      echo "   ✓ All Laravel deployments are Ready"
      return 0
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "❌ ERROR: Laravel deployments are not Ready after ${timeout}s"
      kubectl get pod -n job7189-apps -o wide || true

      for pod_name in $(kubectl get pod -n job7189-apps --no-headers 2>/dev/null | awk '$3!="Running" {print $1}'); do
        print_failed_pod_diagnostics "$pod_name"
      done

      return 1
    fi

    echo "   ... Still waiting (${elapsed}s/${timeout}s)"
    sleep 10
  done
}

# ==================== SCRIPT START ====================
echo ""
echo "????????????????????????????????????????????????????????????"
echo "?  PART 3: MICROSERVICES & INGRESS ROUTES                 ?"
echo "?  Status: Deploying Ingress + Microservices via Helmfile ?"
echo "????????????????????????????????????????????????????????????"
echo ""

# Check if cluster is ready
echo "? Pre-flight check: Verifying cluster readiness..."
if ! kubectl get nodes &>/dev/null; then
  echo "? ERROR: Kubernetes cluster not accessible!"
  echo "   Please run 01-setup-cluster.sh first"
  exit 1
fi

# Check if infrastructure is deployed
INFRA_CHECK=$(kubectl get pod -n management 2>/dev/null | wc -l)
if [ "$INFRA_CHECK" -lt 2 ]; then
  echo "?  WARNING: Infrastructure may not be fully deployed yet."
  echo "   Please ensure 02-deploy-infrastructure.sh has completed."
  read -p "Continue anyway? (yes/no): " answer
  [[ "$answer" == "yes" ]] || exit 1
fi

echo "? Cluster and infrastructure are accessible"
log_time "Pre-flight check"

read -p "? Continue with microservices deployment? (yes/no): " answer
[[ "$answer" == "yes" ]] || exit 1

# ========================
# 0. Setup Docker Registry & Build Images
# ========================
echo ""
echo "? Step 0: Setting up local Docker Registry and building microservice images..."

# Using LOCAL REGISTRY (HOST MACHINE) for image management
echo ""
echo "? Using LOCAL REGISTRY for image management..."
echo "   Local Registry: http://localhost:5000"
echo "   Local Registry UI: http://localhost:8088"

# Start local registry via docker-compose if not running
if [ ! -d "infras/local-registry" ]; then
  echo "?  ERROR: infras/local-registry directory not found!"
  exit 1
fi

cd infras/local-registry

# Check if registry is already running
if docker ps 2>/dev/null | grep -q "local-registry"; then
  echo "   ✓ Local Registry already running"
else
  echo "   Starting local Docker Registry via docker-compose..."
  if docker-compose up -d; then
    echo "   ✓ Local Registry started successfully"
    sleep 2  # Give it time to be fully ready
  else
    echo "?  ERROR: Could not start local registry!"
    echo "   Make sure Docker daemon is running"
    exit 1
  fi
fi

cd - > /dev/null

log_time "0a. Local Registry setup"

REGISTRY_HOST="localhost:5000"
echo "   Registry endpoint: $REGISTRY_HOST"
echo ""

# Build and push images
echo ""
echo "   Building and pushing microservice images..."
echo "   Registry: $REGISTRY_HOST"
echo ""

# Clean up old untagged or mismatched images
echo "   Cleaning up old or temporary images..."
docker image prune -f --filter "dangling=true" 2>/dev/null || true

# Remove old images that don't match current spec (to avoid confusion)
OLD_IMAGES=(
  "job7189/candidate-service:1.0.0"        # Old: no "v" prefix
  "job7189/communication-service:1.0.0"    # Old: no "v" prefix, wrong tag
  "job7189/identity-service:v1.0.0"        # Old tag
  "job7189/storage-service:v1.0.0"         # Old tag
)

for old_image in "${OLD_IMAGES[@]}"; do
  if docker image ls --quiet "$old_image" 2>/dev/null | grep -q .; then
    echo "   Removing old: $old_image"
    docker image rm "$old_image" 2>/dev/null || true
  fi
done

echo ""
echo "   Running build script..."
if [ ! -f "./04-build-and-push-images.sh" ]; then
  echo ""
  echo "?  CRITICAL ERROR: 04-build-and-push-images.sh not found!"
  exit 1
fi

if bash ./04-build-and-push-images.sh "$REGISTRY_HOST"; then
  echo ""
  echo "   ✓ Build and push completed"
else
  BUILD_EXIT_CODE=$?
  echo ""
  echo "   ⚠️  Build script exited with code $BUILD_EXIT_CODE"
  echo "   This may be OK if images already exist locally"
fi
log_time "0d. Build and push images"

# Load images into Kind cluster
echo ""
echo "   Ensuring images are available in Kind cluster..."

# Define all required images with their tags (must match values files!)
# Define all required images with their tags dynamically from values files
declare -a REQUIRED_IMAGES=()
for svc in "identity" "workspace" "job" "hiring" "candidate" "communication" "storage"; do
  val_file="k8s-management/values/${svc}-values.yaml"
  if [ -f "$val_file" ]; then
    TAG=$(grep -m 1 -E "^[[:space:]]*tag:" "$val_file" | awk -F"[:]" "{print \$2}" | tr -d " \"\r")
  else
    TAG="latest"
  fi
  REQUIRED_IMAGES+=("job7189/${svc}-service:${TAG}")
done


# Images built with registry prefix (localhost:5000) need to be retagged for local use
echo "   Retagging images to remove registry prefix..."
for full_image in "${REQUIRED_IMAGES[@]}"; do
  # Build the registry-prefixed version (as built by 04-build-and-push-images.sh)
  registry_image="${REGISTRY_HOST}/${full_image}"
  
  # Check if registry-prefixed version exists
  if docker image inspect "$registry_image" &>/dev/null; then
    echo "   ▶ Retagging: $registry_image → $full_image"
    if docker tag "$registry_image" "$full_image" 2>&1 | grep -v "^$"; then
      echo "     (Re-tagged successfully)"
    fi
  fi
done

log_time "0e1. Retag images"

# Determine chart registry FQDN used by Helm charts (fallback to chart default)
CHART_VALUES_FILE="k8s-management/charts/laravel-app/values.yaml"
CHART_REGISTRY="172.17.0.1:5000"
if [ -f "$CHART_VALUES_FILE" ]; then
  CHART_REGISTRY=$(awk '/^registry:/{r=1} r&&/url:/{print $2; exit}' "$CHART_VALUES_FILE" 2>/dev/null | tr -d ' "\r' || true)
  CHART_REGISTRY=${CHART_REGISTRY:-172.17.0.1:5000}
fi

echo "   Chart registry detected: $CHART_REGISTRY"

# Also ensure images are available under the chart registry name used in manifests
echo "   Tagging images with chart registry prefix (if present)..."
for full_image in "${REQUIRED_IMAGES[@]}"; do
  registry_image="${REGISTRY_HOST}/${full_image}"
  chart_image="${CHART_REGISTRY}/${full_image}"

  # If image exists under localhost registry, tag it as the chart registry image
  if docker image inspect "$registry_image" &>/dev/null; then
    echo "   ▶ Tagging: $registry_image → $chart_image"
    docker tag "$registry_image" "$chart_image" 2>/dev/null || true
  fi

  # If we have a local unprefixed image, also tag it to chart image
  if docker image inspect "$full_image" &>/dev/null; then
    echo "   ▶ Tagging: $full_image → $chart_image"
    docker tag "$full_image" "$chart_image" 2>/dev/null || true
  fi
done

log_time "0e1. Retag images"

# ========================
# 0e2. Push images to in-cluster registry (instead of kind load)
# ========================
echo ""
echo "   ⚡ Pushing images to in-cluster registry (fast path)..."
echo "   Registry: $CHART_REGISTRY"
echo ""

FAILED_PUSHES=()
PUSH_COUNT=0

for full_image in "${REQUIRED_IMAGES[@]}"; do
  echo ""
  echo "   Pushing: $full_image"
  
  # Determine source image
  if docker image inspect "$full_image" &>/dev/null; then
    source_image="$full_image"
  elif docker image inspect "${REGISTRY_HOST}/${full_image}" &>/dev/null; then
    source_image="${REGISTRY_HOST}/${full_image}"
  else
    echo "   ✗ ERROR: Image not found locally: $full_image"
    FAILED_PUSHES+=("$full_image")
    continue
  fi
  
  # Tag for in-cluster registry if not already
  chart_image="${CHART_REGISTRY}/${full_image}"
  if [ "$source_image" != "$chart_image" ]; then
    docker tag "$source_image" "$chart_image" 2>/dev/null || true
  fi
  
  # Push to in-cluster registry
  echo "   ▶ Pushing to registry..."
  if docker push "$chart_image" 2>&1 | grep -E "(Pushed|pushed|digest|Digest)" || true; then
    echo "   ✓ Push successful: $chart_image"
    PUSH_COUNT=$((PUSH_COUNT + 1))
  else
    echo "   ⚠️  Push may have failed (registry network issue?)"
    FAILED_PUSHES+=("$full_image")
  fi
done

log_time "0e2. Push images to registry"

# Verify all images were pushed successfully
echo ""
echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   📦 Image Registry Push Summary:"
echo "   ✓ Pushed: $PUSH_COUNT/${#REQUIRED_IMAGES[@]}"

if [ ${#FAILED_PUSHES[@]} -gt 0 ]; then
  echo "   ⚠️  Failed: ${#FAILED_PUSHES[@]}"
  echo ""
  echo "   Note: Failures may be non-critical if registry is"
  echo "   already populated from previous runs."
  printf '      • %s\n' "${FAILED_PUSHES[@]}"
  echo ""
  echo "   Continuing with deployment anyway..."
fi

if [ $PUSH_COUNT -eq ${#REQUIRED_IMAGES[@]} ]; then
  echo "   ✓ All images pushed successfully!"
fi
echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! verify_registry_tags; then
  echo ""
  echo "❌ CRITICAL ERROR: One or more required Laravel images are missing in local registry"
  echo "   Please verify 04-build-and-push-images.sh and registry availability before deploying"
  exit 1
fi
log_time "0e3. Verify registry tags"

echo ""
echo "   Validating Vault dynamic credentials backend before Helmfile deploy..."
if ! ensure_vault_dynamic_db_ready; then
  echo ""
  echo "❌ CRITICAL ERROR: Vault dynamic DB credentials are not ready"
  echo "   Deployment stopped to avoid pods stuck in Init state"
  exit 1
fi
log_time "0f. Vault dynamic DB readiness"

echo ""
echo "   Pods will pull images on-demand from registry"
echo "   (imagePullPolicy: IfNotPresent in Helm charts)"
echo ""

# ========================
# 1. Deploy Microservices via Helmfile
# ========================
echo ""
echo "?  Step 1: Deploying microservices via Helmfile..."
echo ""
echo "   Waiting for Kind cluster to be ready..."

# Give Kind some time to be ready
sleep 2

if [ ! -d "k8s-management" ]; then
  echo "? ERROR: k8s-management directory not found"
  exit 1
fi

if [ ! -f "k8s-management/helmfile.yaml" ]; then
  echo "? ERROR: helmfile.yaml not found in k8s-management"
  exit 1
fi

echo "   Checking Helm & Helmfile..."
helmfile version || {
  echo "?  WARNING: Helmfile not found. Will use helm commands instead."
}

cd k8s-management

echo ""
echo "   Running helmfile apply to deploy Laravel microservices (job7189-apps)..."
echo "   (This may take 2-5 minutes as pods initialize)"
echo ""

if helmfile --selector namespace=job7189-apps apply 2>&1 | tee /tmp/helmfile-output.log; then
  echo ""
  echo "   ✓ Helmfile apply completed"
else
  HELMFILE_EXIT=$?
  echo ""
  echo "   ⚠️  Helmfile encountered issues (exit code: $HELMFILE_EXIT)"
  echo "   Helm releases may still be deploying..."
  tail -20 /tmp/helmfile-output.log
fi

log_time "1a. Helmfile apply"

echo ""
echo "   Waiting for pods to be created..."
sleep 3

echo "   Verifying deployed releases..."
helm list -n job7189-apps 2>/dev/null || echo "    (checking Helm releases...)"
log_time "1b. Helmfile deployment checkpoint"

if ! wait_for_laravel_deployments_ready 900; then
  echo ""
  echo "❌ CRITICAL ERROR: Laravel pods failed to reach Running state"
  echo "   Root-cause diagnostics are printed above"
  exit 1
fi
log_time "1c. Laravel readiness gate"

cd - > /dev/null

# ========================
# 2. Final Status Check
# ========================
echo ""
echo "? Step 2: Checking deployment status..."
echo ""

# Wait a bit for pods to start
echo "   Giving pods time to initialize (15 seconds)..."
for i in {1..15}; do
  echo -n "."
  sleep 1
done
echo " Done"
echo ""

echo "? Pod Status Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pod -n job7189-apps -o wide 2>/dev/null || echo "   Unable to get pod status"

echo ""
echo "? Detailed Status by Namespace:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pod -A --no-headers 2>/dev/null | \
  awk '{print $1}' | sort | uniq -c | sort -rn || echo "Unable to get namespaces"

echo ""
echo "? Checking for Error States:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for problematic pod states
ERROR_PODS=$(kubectl get pod -A --no-headers 2>/dev/null | grep -E 'Error|Backoff|Failed' | wc -l)

if [ "$ERROR_PODS" -gt 0 ]; then
  echo "⚠️  Found $ERROR_PODS pods with errors:"
  echo ""
  kubectl get pod -A --no-headers 2>/dev/null | grep -E 'Error|Backoff|Failed'
  echo ""
  echo "📝 Common error meanings:"
  echo "   • ImagePullBackOff - Pod trying to pull image from registry (should use local)"
  echo "   • ErrImageNeverPull - pullPolicy: Never but image not in local (tag mismatch?)"
  echo "   • CrashLoopBackOff - Pod started but crashed"
  echo "   • Pending - Waiting for resources"
  echo ""
  echo "Troubleshooting:"
  echo "   1. Check which images are missing:"
  echo "      docker image ls | grep job7189"
  echo ""
  echo "   2. Check pod image configuration (what pods are trying to pull):"
  echo "      kubectl get pod -n job7189-apps -o json | jq '.items[] | {name: .metadata.name, images: .spec.containers[].image}'"
  echo ""
  echo "   3. Compare values file tags with actual build script tags:"
  echo "      echo 'Values tags:' && grep -r 'tag:' k8s-management/values/"
  echo "      echo 'Build script tags:' && grep 'IMAGE_TAGS' 04-build-and-push-images.sh -A 10"
  echo ""
  echo "   4. Describe a failed pod for details:"
  echo "      kubectl describe pod -n job7189-apps <pod-name>"
  echo ""
  echo "   5. Check pod logs (if container started):"
  echo "      kubectl logs -n job7189-apps <pod-name> --all-containers=true"
else
  echo "✓ No pods in error state (good start!)"
fi

echo ""

echo ""
echo "? Ingress Resources (deployed in Phase 2):"
kubectl get ingress -A 2>/dev/null || echo "No ingress resources found"

echo ""
echo "? Recent Events:"
kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No recent events"

log_time "2a. Status check"

# ========================
# COMPLETED
# ========================
echo ""
echo "????????????????????????????????????????????????"
echo "? PART 3 COMPLETED: Docker Registry + Microservices deployed"
echo "????????????????????????????????????????????????"
echo ""
echo "? FULL SYSTEM DEPLOYMENT COMPLETE!"
echo ""
echo "? Deployment Status:"
echo "   ? Part 1: Cluster Setup (Cilium, cert-manager, Nginx Ingress) - DONE"
echo "   ? Part 2: Infrastructure (MySQL, Keycloak, oauth2-proxy, Kafka, Kong, Vault) + Ingress Routes - DONE"
echo "   ? Part 3: Docker Registry Setup + Image Builds - DONE"
echo "   ? Part 3: Microservices (via Helmfile) - DONE"
echo ""
echo "? Deployed Ingress Routes (from Phase 2):"
echo "   - Public API gateway (Kong proxy)"
echo "   - OAuth2 authentication routes"
echo "   - Internal tools routes"
echo "   - Service aliases"
echo ""
echo "? IMPORTANT: Microservices are still stabilizing!"
echo "   This can take 5-15 minutes depending on your system."
echo ""
echo "? Next Steps to Monitor:"
echo "   1. Check microservice pod readiness:"
echo "      kubectl get pod -A | grep -v Running"
echo ""
echo "   2. Check ingress configuration (from Phase 2):"
echo "      kubectl get ingress -A"
echo ""
echo "   3. Monitor deployment events:"
echo "      kubectl get events -A --sort-by='.lastTimestamp' | tail -20"
echo ""
echo "   4. Check microservice logs:"
echo "      kubectl logs -n job7189-apps -f --tail=20"
echo ""
echo "   5. Check Helmfile releases:"
echo "      helm list -A"
echo ""
echo "   6. Accessing services:"
echo "      kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &"
echo "      # Then visit: http://localhost:8080 or use configured hostnames"
echo ""
echo "? Troubleshooting:"
echo "   o Pod CrashLoopBackOff? Check logs: kubectl logs -n <namespace> <pod-name>"
echo "   o Pending pods? Check node resources: kubectl describe nodes"
echo "   o DNS issues? Check CoreDNS: kubectl get pod -n kube-system | grep coredns"
echo "   o Ingress not routing? Check services: kubectl get svc -A"
echo ""
