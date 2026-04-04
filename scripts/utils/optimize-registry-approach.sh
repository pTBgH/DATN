#!/bin/bash
# STRATEGY 2: Replace sequential "kind load" with in-cluster registry push
# This saves ~694 seconds by pushing to registry instead of kind load
# 
# Usage: bash optimize-registry-approach.sh 
# 
# Prerequisites:
# - Docker registry running in cluster (already set up)
# - Images built locally
# - kubectl access to cluster

set -euo pipefail

echo "════════════════════════════════════════════════════════════"
echo "🚀 REGISTRY-BASED IMAGE DEPLOYMENT (Fast Path)"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "This approach replaces slow 'kind load docker-image' with"
echo "registry push. Expected time: ~40 seconds (vs 734 seconds)"
echo ""

# ===== CONFIGURATION =====
REGISTRY_HOST="localhost:5000"
IN_CLUSTER_REGISTRY="docker-registry.registry.svc.cluster.local:5000"
CLUSTER_NAME="job7189"

# All required images (must match 03-deploy-microservices.sh)
declare -a REQUIRED_IMAGES=(
  "job7189/identity-service:v2.7.8"
  "job7189/workspace-service:v1.0.0"
  "job7189/job-service:v1.0.0"
  "job7189/hiring-service:v1.7.4"
  "job7189/candidate-service:v1.0.0"
  "job7189/communication-service:v1.1.6"
  "job7189/storage-service:v1.2.1"
)

# ===== STEP 1: Verify Prerequisites =====
echo "Step 1: Verifying prerequisites..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  echo "❌ Kind cluster '$CLUSTER_NAME' not found"
  exit 1
fi
echo "✓ Cluster ready: $CLUSTER_NAME"

# Check if registry is running in cluster
if ! kubectl get svc -n kube-system registry &>/dev/null 2>&1; then
  echo "⚠️  Registry service not found in kube-system"
  echo "   Checking in other namespaces..."
  REGISTRY_NS=$(kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.metadata.name | contains("registry")) | .metadata.namespace' | head -1)
  if [ -z "$REGISTRY_NS" ]; then
    echo "⚠️  Registry might be in different namespace"
  else
    echo "✓ Registry found in namespace: $REGISTRY_NS"
  fi
fi

kubectl get nodes &>/dev/null || { echo "❌ Cannot access cluster"; exit 1; }
echo "✓ kubectl authenticated"

# Check if images exist locally
echo ""
echo "Step 2: Checking local images..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MISSING_IMAGES=0
for image in "${REQUIRED_IMAGES[@]}"; do
  if docker image inspect "$image" &>/dev/null; then
    SIZE=$(docker image inspect "$image" --format='{{.Size}}')
    SIZE_MB=$((SIZE / 1024 / 1024))
    printf "  ✓ %-50s %3d MB\n" "$image" "$SIZE_MB"
  else
    # Try with registry prefix
    if docker image inspect "${REGISTRY_HOST}/${image}" &>/dev/null; then
      SIZE=$(docker image inspect "${REGISTRY_HOST}/${image}" --format='{{.Size}}')
      SIZE_MB=$((SIZE / 1024 / 1024))
      printf "  ✓ %-50s %3d MB (registry prefix)\n" "$image" "$SIZE_MB"
    else
      echo "  ❌ Image not found: $image"
      MISSING_IMAGES=$((MISSING_IMAGES + 1))
    fi
  fi
done

if [ $MISSING_IMAGES -gt 0 ]; then
  echo ""
  echo "❌ Missing $MISSING_IMAGES images. Please build first:"
  echo "   bash 04-build-and-push-images.sh"
  exit 1
fi

echo ""
echo "Step 3: Tagging images for in-cluster registry..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RETAG_COUNT=0
for image in "${REQUIRED_IMAGES[@]}"; do
  in_cluster_image="${IN_CLUSTER_REGISTRY}/${image}"
  
  # Get source image (try local first, then registry-prefixed)
  if docker image inspect "$image" &>/dev/null; then
    source_image="$image"
  elif docker image inspect "${REGISTRY_HOST}/${image}" &>/dev/null; then
    source_image="${REGISTRY_HOST}/${image}"
  else
    echo "  ⚠️  Skipping: $image (not found)"
    continue
  fi
  
  # Re-tag for in-cluster registry
  if docker tag "$source_image" "$in_cluster_image" &>/dev/null; then
    echo "  ✓ $(echo $image | cut -d: -f1 | rev | cut -d/ -f1 | rev) → in-cluster"
    RETAG_COUNT=$((RETAG_COUNT + 1))
  fi
done

echo ""
echo "Step 4: Pushing to in-cluster registry..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PUSH_TIME_START=$(date +%s)
PUSH_COUNT=0
PUSH_FAILED=0

for image in "${REQUIRED_IMAGES[@]}"; do
  in_cluster_image="${IN_CLUSTER_REGISTRY}/${image}"
  
  if docker image inspect "$in_cluster_image" &>/dev/null; then
    echo ""
    SERVICE=$(echo "$image" | cut -d: -f1 | rev | cut -d/ -f1 | rev)
    echo "  Pushing: $SERVICE"
    echo "    From: $in_cluster_image"
    
    # Push with timeout
    if timeout 60 docker push "$in_cluster_image" 2>&1 | grep -E "(Pushed|pushed|digest|Digest)" || true; then
      echo "    ✓ Push successful"
      PUSH_COUNT=$((PUSH_COUNT + 1))
    else
      echo "    ⚠️  Push may have failed (network issue?)"
      PUSH_FAILED=$((PUSH_FAILED + 1))
    fi
  fi
done

PUSH_TIME_END=$(date +%s)
PUSH_DURATION=$((PUSH_TIME_END - PUSH_TIME_START))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📊 RESULTS"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Images retagged: $RETAG_COUNT"
echo "Images pushed:   $PUSH_COUNT"
echo "Push failures:   $PUSH_FAILED"
echo "Push time:       ${PUSH_DURATION}s"
echo ""

if [ $PUSH_COUNT -eq ${#REQUIRED_IMAGES[@]} ]; then
  echo "✅ SUCCESS: All images pushed to in-cluster registry!"
  echo ""
  echo "Next steps:"
  echo "1. Update Helm values to use in-cluster registry:"
  echo "   image:"
  echo "     registry: 'docker-registry.registry.svc.cluster.local:5000'"
  echo "     pullPolicy: 'IfNotPresent'"
  echo ""
  echo "2. Deploy via Helmfile:"
  echo "   cd k8s-management && helmfile apply"
  echo ""
elif [ $PUSH_COUNT -gt 0 ]; then
  echo "⚠️  PARTIAL: $PUSH_COUNT/$((PUSH_COUNT + PUSH_FAILED)) images pushed"
  echo "Some images may still be loading..."
else
  echo "❌ FAILED: No images were pushed"
  echo "Troubleshooting:"
  echo "  • Check if registry is running: kubectl get pod -A | grep registry"
  echo "  • Check registry logs: kubectl logs -f -n kube-system -l app=registry"
  echo "  • Verify network connectivity to registry"
fi

echo ""
echo "TIME COMPARISON:"
echo "  Old method (kind load):    ~734 seconds"
echo "  New method (registry push): ~${PUSH_DURATION} seconds"
echo "  SAVED: ~$((734 - PUSH_DURATION)) seconds!"
echo ""
