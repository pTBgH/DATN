#!/bin/bash
# 00-cleanup-images.sh — Full cleanup of all microservice images
# Removes images from: local Docker, Docker registry, and Kind nodes
set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5000}"
CLUSTER_NAME="${CLUSTER_NAME:-job7189}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  00 — Full Image Cleanup                                ║"
echo "║  Removes ALL job7189 images from local, registry, nodes ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ========================
# 1. Remove local Docker images
# ========================
echo -e "${BLUE}[1/4] Removing local Docker images...${NC}"

LOCAL_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E '(job7189/|:5000/job7189/)' || true)

if [ -z "$LOCAL_IMAGES" ]; then
  echo -e "  ${GREEN}✓ No local job7189 images found${NC}"
else
  COUNT=$(echo "$LOCAL_IMAGES" | wc -l)
  echo "  Found $COUNT local image(s) to remove:"
  echo "$LOCAL_IMAGES" | while read -r img; do
    echo "    • Removing: $img"
    docker rmi "$img" 2>/dev/null || true
  done
  echo -e "  ${GREEN}✓ Local images removed${NC}"
fi

# Also prune dangling images
echo "  Pruning dangling images..."
docker image prune -f 2>/dev/null || true

# ========================
# 2. Remove images from Docker registry
# ========================
echo ""
echo -e "${BLUE}[2/4] Removing images from registry ($REGISTRY_HOST)...${NC}"

if ! curl -sf "http://${REGISTRY_HOST}/v2/_catalog" > /dev/null 2>&1; then
  echo -e "  ${YELLOW}⚠ Registry not reachable at $REGISTRY_HOST — skipping${NC}"
else
  REPOS=$(curl -sf "http://${REGISTRY_HOST}/v2/_catalog" 2>/dev/null | python3 -c "import sys,json; [print(r) for r in json.load(sys.stdin).get('repositories',[])]" 2>/dev/null || true)

  if [ -z "$REPOS" ]; then
    echo -e "  ${GREEN}✓ Registry is empty${NC}"
  else
    for repo in $REPOS; do
      echo "  Processing repo: $repo"
      TAGS=$(curl -sf "http://${REGISTRY_HOST}/v2/${repo}/tags/list" 2>/dev/null | python3 -c "import sys,json; [print(t) for t in json.load(sys.stdin).get('tags',[])]" 2>/dev/null || true)

      if [ -z "$TAGS" ]; then
        echo "    (no tags found)"
        continue
      fi

      for tag in $TAGS; do
        # Get manifest digest
        DIGEST=$(curl -sf -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
          -I "http://${REGISTRY_HOST}/v2/${repo}/manifests/${tag}" 2>/dev/null \
          | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r' || true)

        if [ -n "$DIGEST" ]; then
          echo "    Deleting ${repo}:${tag} (${DIGEST:0:25}...)"
          curl -sf -X DELETE "http://${REGISTRY_HOST}/v2/${repo}/manifests/${DIGEST}" 2>/dev/null || true
        else
          echo "    ${YELLOW}⚠ Could not get digest for ${repo}:${tag}${NC}"
        fi
      done
    done

    echo -e "  ${GREEN}✓ Registry tags deleted${NC}"
  fi

  # Trigger garbage collection if registry is a local docker-compose registry
  REGISTRY_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "local-registry.*registry" | head -1 || true)
  if [ -n "$REGISTRY_CONTAINER" ]; then
    echo "  Running registry garbage collection on container: $REGISTRY_CONTAINER ..."
    docker exec "$REGISTRY_CONTAINER" bin/registry garbage-collect /etc/docker/registry/config.yml --delete-untagged 2>/dev/null || true
    echo -e "  ${GREEN}✓ Registry GC completed${NC}"
  fi
fi

# ========================
# 3. Remove images from Kind nodes
# ========================
echo ""
echo -e "${BLUE}[3/4] Removing images from Kind cluster nodes...${NC}"

NODES=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null || docker ps --format '{{.Names}}' 2>/dev/null | grep "^${CLUSTER_NAME}-" || true)

if [ -z "$NODES" ]; then
  echo -e "  ${YELLOW}⚠ No Kind nodes found for cluster $CLUSTER_NAME — skipping${NC}"
else
  for node in $NODES; do
    echo "  Node: $node"

    # List and remove job7189 images from containerd
    CRICTL_IMAGES=$(docker exec "$node" crictl images -o json 2>/dev/null \
      | python3 -c "
import sys,json
data = json.load(sys.stdin)
for img in data.get('images', []):
    for tag in img.get('repoTags', []):
        if 'job7189' in tag:
            print(img['id'])
            break
" 2>/dev/null || true)

    if [ -z "$CRICTL_IMAGES" ]; then
      echo "    ✓ No job7189 images on this node"
    else
      for img_id in $CRICTL_IMAGES; do
        echo "    Removing: ${img_id:0:20}..."
        docker exec "$node" crictl rmi "$img_id" 2>/dev/null || true
      done
      echo "    ✓ Node images cleaned"
    fi

    # Also prune dangling/unused images
    docker exec "$node" crictl rmi --prune 2>/dev/null || true
  done
  echo -e "  ${GREEN}✓ Kind node images cleaned${NC}"
fi

# ========================
# 4. Final verification
# ========================
echo ""
echo -e "${BLUE}[4/4] Verification...${NC}"
echo ""

echo "  Local Docker images (job7189):"
REMAINING=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E '(job7189/|:5000/job7189/)' | wc -l || echo 0)
if [ "$REMAINING" -eq 0 ]; then
  echo -e "    ${GREEN}✓ Zero images${NC}"
else
  echo -e "    ${YELLOW}⚠ $REMAINING image(s) still present${NC}"
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E '(job7189/|:5000/job7189/)' | sed 's/^/    /'
fi

echo ""
echo "  Registry ($REGISTRY_HOST):"
if curl -sf "http://${REGISTRY_HOST}/v2/_catalog" > /dev/null 2>&1; then
  REG_REPOS=$(curl -sf "http://${REGISTRY_HOST}/v2/_catalog" 2>/dev/null)
  echo "    $REG_REPOS"
else
  echo "    (registry not reachable)"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "NOTE: To rebuild images, run:"
echo "  bash 04-build-and-push-images.sh localhost:5000"
echo "  — or —"
echo "  bash 03-deploy-microservices.sh"
echo ""
