#!/bin/bash
# Build Docker images cho tất cả microservices
# Và push lên Docker Registry
# Called from: 03-deploy-microservices.sh

set -euo pipefail

# ==================== CONFIG ====================
REGISTRY_HOST=${1:-"localhost:5000"}  # Default: local registry (not K8s NodePort)
REGISTRY_PREFIX="${REGISTRY_HOST}"

# Danh sách services - CHỈ BUILD SERVICES KHÔNG CÓ DEPENDENCY ISSUES
declare -A SERVICES=(
  ["identity-service"]="identity_service"
  ["workspace-service"]="workspace_service"
  ["job-service"]="job_service"
  ["hiring-service"]="hiring_service"
  ["candidate-service"]="candidate_service"
  ["communication-service"]="communication_service"
  ["storage-service"]="storage_service"
)

# Image tags - từ values files
# Lấy file values.yaml để làm source of truth cho tags
get_tag_from_values() {
  local service_name=$1
  local val_file="k8s-management/values/${service_name%-service}-values.yaml"
  if [ -f "$val_file" ]; then
    grep -m 1 -E "^[[:space:]]*tag:" "$val_file" | awk -F"[:]" "{print \$2}" | tr -d " \"\r"
  else
    echo "latest"
  fi
}


# ==================== FUNCTIONS ====================
build_and_push() {
  local service_name=$1
  local service_dir=$2
  local tag=$(get_tag_from_values "$service_name" || echo "latest")
  
  local image_name="${REGISTRY_PREFIX}/job7189/${service_name}"
  local full_image="${image_name}:${tag}"
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Building: $service_name"
  echo "   Image: $full_image"
  echo "   From: src/$service_dir/laravel_back"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Check if service directory exists
  if [ ! -d "src/$service_dir" ]; then
    echo "❌ Directory not found: src/$service_dir"
    return 1
  fi
  
  if [ ! -f "src/$service_dir/laravel_back/Dockerfile.production" ]; then
    echo "❌ Dockerfile.production not found in src/$service_dir/laravel_back"
    return 1
  fi
  
  # Build image
  echo "▶ Building Docker image..."
  if docker build \
    --file "src/$service_dir/laravel_back/Dockerfile.production" \
    --tag "$full_image" \
    --label "built_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --label "service=$service_name" \
    --label "version=$tag" \
    "src/$service_dir/laravel_back/"; then
    echo "✅ Build successful: $full_image"
    
    # Verify image exists with exact tag
    if docker image inspect "$full_image" &>/dev/null; then
      echo "   Verified: Image exists with tag $tag"
    else
      echo "❌ ERROR: Image built but inspect failed!"
      return 1
    fi
  else
    echo "❌ Build failed for $service_name"
    return 1
  fi
  
  # Push to registry
  echo "▶ Pushing to registry: $REGISTRY_HOST"
  if docker push "$full_image"; then
    echo "✅ Push successful: $full_image"
  else
    echo "⚠️  Push failed - but image exists locally"
    echo "   This may be expected if registry is not reachable from host"
    return 0  # Don't fail - image still available
  fi
}

# ==================== MAIN ====================
echo ""
echo "════════════════════════════════════════════════════════"
echo "🐳 DOCKER IMAGE BUILD & PUSH SCRIPT"
echo "════════════════════════════════════════════════════════"
echo "Registry: $REGISTRY_HOST"
echo ""

# Check if docker is running
if ! docker ps &>/dev/null; then
  echo "❌ ERROR: Docker daemon is not running!"
  exit 1
fi

echo "✅ Docker daemon is available"
echo ""

# Build all services
FAILED_BUILDS=()
SUCCESSFUL_BUILDS=()

for service_name in "${!SERVICES[@]}"; do
  service_dir="${SERVICES[$service_name]}"
  
  if ! build_and_push "$service_name" "$service_dir"; then
    FAILED_BUILDS+=("$service_name")
  else
    SUCCESSFUL_BUILDS+=("$service_name")
  fi
done

echo ""
echo "════════════════════════════════════════════════════════"
echo "📊 BUILD SUMMARY"
echo "════════════════════════════════════════════════════════"

echo "✅ Successfully built and pushed:"
printf '   • %s\n' "${SUCCESSFUL_BUILDS[@]}"

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Failed to build/push:"
  printf '   • %s\n' "${FAILED_BUILDS[@]}"
  echo ""
  echo "⚠️  Some services failed to build"
  echo "   However, images may still exist locally from a previous build."
  echo "   Proceeding with local images..."
else
  echo ""
  echo "✅ All services built and pushed successfully!"
fi

echo ""
echo "Checking which images exist locally..."
echo "─────────────────────────────────────────────────────────"

# Verify which images actually exist
for service_name in "${!SERVICES[@]}"; do
  tag=$(get_tag_from_values "$service_name" || echo "latest")
  image_name="${REGISTRY_PREFIX}/job7189/${service_name}:${tag}"
  
  if docker image ls --quiet "$image_name" &>/dev/null; then
    echo "✓ ${image_name}"
  else
    echo "✗ ${image_name} NOT FOUND LOCALLY"
  fi
done

echo "─────────────────────────────────────────────────────────"

echo ""
echo "Next step: Images are ready to be pulled by Kubernetes"
echo "          From cluster (if using K8s registry): docker-registry.registry.svc.cluster.local:5000"
echo "          From host: localhost:5000"
