#!/bin/bash
# Diagnose why "kind load docker-image" is slow and suggest optimizations.
#
# KIND-ONLY: the whole script reasons about the `kind load` data path
# (tar-stream into the kind node containerd). On the 4-VM kubeadm cluster
# images flow through the in-cluster Docker registry on srv05 and never
# touch `kind load`, so this script refuses in VM mode.
# VM-mode equivalent: push images directly with 04-build-and-push-images.sh.
#
# Usage: bash scripts/utils/diagnose-image-loading.sh --kind

set -euo pipefail

# shellcheck source=scripts/utils/zta-cluster-mode.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/zta-cluster-mode.sh"
zta_parse_mode_flag "$@"
eval "$(zta_apply_parsed_args_cmd)"
zta_mode_banner "diagnose-image-loading.sh"
zta_require_kind "diagnose-image-loading.sh" "04-build-and-push-images.sh"

echo "════════════════════════════════════════════════════════════"
echo "🔍 IMAGE LOADING PERFORMANCE DIAGNOSIS"
echo "════════════════════════════════════════════════════════════"
echo ""

# Define all required images
declare -a REQUIRED_IMAGES=(
  "job7189/identity-service:v2.7.8"
  "job7189/workspace-service:v1.0.0"
  "job7189/job-service:v1.0.0"
  "job7189/hiring-service:v1.7.4"
  "job7189/candidate-service:v1.0.0"
  "job7189/communication-service:v1.1.6"
  "job7189/storage-service:v1.2.1"
)

echo "📦 IMAGE SIZE ANALYSIS (without registry prefix)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_SIZE=0
for image in "${REQUIRED_IMAGES[@]}"; do
  if docker image inspect "$image" &>/dev/null; then
    SIZE=$(docker image inspect "$image" --format='{{.Size}}')
    SIZE_MB=$((SIZE / 1024 / 1024))
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE_MB))
    printf "%-45s %6d MB\n" "$image" "$SIZE_MB"
  else
    echo "⚠️  Image not found locally: $image"
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-45s %6d MB (TOTAL)\n" "Total Size" "$TOTAL_SIZE"
echo ""

echo "🐳 KIND CLUSTER CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "job7189"; then
  echo "⚠️  Kind cluster 'job7189' not found or not running"
  echo "   Please create cluster first: 01-setup-cluster.sh"
else
  echo "✓ Cluster: job7189"
  
  # Get number of nodes
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  echo "✓ Nodes: $NODE_COUNT"
  
  # Show node details
  echo ""
  kubectl get nodes -o wide 2>/dev/null || echo "   (Could not get node details)"
fi

echo ""
echo "🔬 DOCKER DAEMON PERFORMANCE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Docker disk usage
DOCKER_USAGE=$(docker system df | tail -6)
echo "$DOCKER_USAGE"

echo ""
echo "⚡ PERFORMANCE FACTORS & OPTIMIZATION STRATEGIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "1️⃣  PRIMARY BOTTLENECK: Sequential Image Loading"
echo "   • Current approach: Loads images ONE BY ONE"
echo "   • Each image waits for the previous to complete"
echo "   • For $TOTAL_SIZE MB across ${#REQUIRED_IMAGES[@]} images → 734s"
echo ""
echo "   SOLUTIONS:"
echo "   ✓ Optimize image sizes (reduce each image)"
echo "   ✓ Parallel loading (limited by docker daemon)"
echo "   ✓ Use registry inside cluster (more efficient)"
echo ""

echo "2️⃣  IMAGE SIZE OPTIMIZATION"
echo "   • Reducing image sizes by 10-30% saves 70-200 seconds"
echo "   • Multi-stage builds / layer squashing / docker prune"
echo ""
echo "   Current estimate:"
echo "   • Total: ~${TOTAL_SIZE} MB"
echo "   • Average per image: $((TOTAL_SIZE / ${#REQUIRED_IMAGES[@]})) MB"
echo ""

echo "3️⃣  DOCKER DAEMON OPTIMIZATION"
echo "   • Check docker system df output above"
echo "   • Run: docker system prune -a to free space"
echo "   • Consider changing storage driver if using overlay2"
echo ""

echo "4️⃣  KIND CLUSTER OPTIMIZATION"
echo "   • Current: ${NODE_COUNT:-?} nodes"
echo "   • Images are synced to ALL worker nodes"
echo "   • More nodes = slower loading"
echo ""

echo ""
echo "📊 LOADING TIME ESTIMATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Current: 734s for ${#REQUIRED_IMAGES[@]} images"
echo ""
echo "If you reduce image size by:"
echo "  • 10% → ~660s (Save 74s)"
echo "  • 20% → ~587s (Save 147s)"
echo "  • 30% → ~514s (Save 220s)"
echo ""
echo "Alternative: Use in-cluster registry"
echo "  • Better for K8s native workloads"
echo "  • Can reduce by 50-70%"
echo "  • See: optimization-registry.sh"
echo ""

echo "🎯 RECOMMENDED ACTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. First: Analyze individual Dockerfile.production files"
echo "   find src -name 'Dockerfile.production' -exec du -h {} +"
echo ""
echo "2. Look for opportunities:"
echo "   • Remove build tools (keep only runtime)"
echo "   • Use Alpine/distroless base images"
echo "   • Optimize composer vendor/ size"
echo "   • Remove node_modules if not needed"
echo ""
echo "3. For faster iterations during development:"
echo "   • Skip image loading (use IfNotPresent + pre-load)"
echo "   • Or use registry-based deployment"
echo ""
