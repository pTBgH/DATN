#!/bin/bash
# STRATEGY 3: Parallel image loading (10-20% improvement)
# Load multiple images concurrently to Kind
# 
# Usage: bash optimize-parallel-loading.sh
#
# Limitations:
# - Docker daemon has connection limits (usually allows 3-4 concurrent)
# - Still requires copying to all nodes (system-level bottleneck)
# - Best combined with image size reduction or registry approach

set -euo pipefail

echo "════════════════════════════════════════════════════════════"
echo "⚡ PARALLEL IMAGE LOADING"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "This approach loads multiple images concurrently (max 3-4)"
echo "Expected improvement: 10-20% (90-150 seconds saved)"
echo "Expected time: ~620 seconds (vs 734 sequential)"
echo ""
echo "Note: This is LESS effective than registry approach"
echo "      Consider using registry push instead (saves 694s)"
echo ""

CLUSTER_NAME="job7189"
REGISTRY_HOST="localhost:5000"
CHART_REGISTRY="docker-registry.registry.svc.cluster.local:5000"
MAX_PARALLEL=3  # Max concurrent docker push operations

# All required images
declare -a REQUIRED_IMAGES=(
  "job7189/identity-service:v2.7.8"
  "job7189/workspace-service:v1.0.0"
  "job7189/job-service:v1.0.0"
  "job7189/hiring-service:v1.7.4"
  "job7189/candidate-service:v1.0.0"
  "job7189/communication-service:v1.1.6"
  "job7189/storage-service:v1.2.1"
)

# ===== Helper Functions =====

# Load a single image into Kind
load_image_task() {
  local image=$1
  local cluster=$2
  local chart_registry=$3
  
  # Determine which image to load
  if docker image inspect "$image" &>/dev/null; then
    load_image="$image"
  elif docker image inspect "${chart_registry}/${image}" &>/dev/null; then
    load_image="${chart_registry}/${image}"
  else
    echo "❌ Image not found: $image"
    return 1
  fi
  
  echo "⏳ Loading: $(echo $image | rev | cut -d/ -f1 | rev)..."
  
  if kind load docker-image "$load_image" --name "$cluster" 2>&1; then
    echo "✅ Loaded: $(echo $image | rev | cut -d/ -f1 | rev)"
    return 0
  else
    echo "❌ Failed: $(echo $image | rev | cut -d/ -f1 | rev)"
    return 1
  fi
}

export -f load_image_task

# ===== Main Implementation =====

echo "Step 1: Verifying prerequisites..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check cluster
if ! kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  echo "❌ Kind cluster not found: $CLUSTER_NAME"
  exit 1
fi
echo "✓ Cluster ready"

# Check images
MISSING=0
for image in "${REQUIRED_IMAGES[@]}"; do
  if ! docker image inspect "$image" &>/dev/null && \
     ! docker image inspect "${CHART_REGISTRY}/${image}" &>/dev/null; then
    echo "❌ Image not found: $image"
    MISSING=$((MISSING + 1))
  fi
done

if [ $MISSING -gt 0 ]; then
  echo "❌ $MISSING images missing. Please build first."
  exit 1
fi

echo "✓ All images found locally"

echo ""
echo "Step 2: Loading images in parallel..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Max concurrent jobs: $MAX_PARALLEL"
echo ""

LOAD_START=$(date +%s)

# Prepare list of images and load in parallel
printf '%s\n' "${REQUIRED_IMAGES[@]}" | \
  xargs -P $MAX_PARALLEL -I {} bash -c "load_image_task '{}' '$CLUSTER_NAME' '$CHART_REGISTRY'"

LOAD_END=$(date +%s)
LOAD_DURATION=$((LOAD_END - LOAD_START))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ PARALLEL LOADING COMPLETE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Duration: ${LOAD_DURATION}s"
echo "Sequential would be: ~734s"
echo "Improvement: ~$((734 - LOAD_DURATION))s saved ($(((100 * (734 - LOAD_DURATION)) / 734))%)"
echo ""

if [ $LOAD_DURATION -lt 500 ]; then
  echo "✅ Good! Parallel loading is effective."
elif [ $LOAD_DURATION -lt 650 ]; then
  echo "⚠️  Moderate improvement. Consider registry approach for more savings."
else
  echo "⚠️  Limited improvement. Recommend switching to registry approach."
fi

echo ""
echo "Next: Deploy microservices via Helmfile"
echo "  cd k8s-management && helmfile apply"
echo ""
