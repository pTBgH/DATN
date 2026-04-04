#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# In-cluster registry configuration
LOCAL_REGISTRY="localhost:5000"
IN_CLUSTER_REGISTRY="docker-registry.registry.svc.cluster.local:5000"

echo -e "${YELLOW}Building Frontend Applications...${NC}"

# Build fe-candidate
echo -e "\n${YELLOW}1. Building fe-candidate...${NC}"
docker build -t fe-candidate:latest ./src/fe_candidate/
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ fe-candidate built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build fe-candidate${NC}"
    exit 1
fi

# Build fe-recruiter
echo -e "\n${YELLOW}2. Building fe-recruiter...${NC}"
docker build -t fe-recruiter:latest ./src/fe_recruiter/
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ fe-recruiter built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build fe-recruiter${NC}"
    exit 1
fi

# Tag images for in-cluster registry
echo -e "\n${YELLOW}3. Tagging images for in-cluster registry...${NC}"
docker tag fe-candidate:latest ${IN_CLUSTER_REGISTRY}/fe-candidate:latest
docker tag fe-recruiter:latest ${IN_CLUSTER_REGISTRY}/fe-recruiter:latest
echo -e "${GREEN}✓ Images tagged for in-cluster registry${NC}"

# Push to in-cluster registry
echo -e "\n${YELLOW}4. Pushing images to in-cluster registry...${NC}"

docker push ${IN_CLUSTER_REGISTRY}/fe-candidate:latest
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ fe-candidate pushed to in-cluster registry${NC}"
else
    echo -e "${RED}✗ Failed to push fe-candidate${NC}"
    echo -e "${YELLOW}   Note: This may be expected if registry is not reachable from host${NC}"
fi

docker push ${IN_CLUSTER_REGISTRY}/fe-recruiter:latest
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ fe-recruiter pushed to in-cluster registry${NC}"
else
    echo -e "${RED}✗ Failed to push fe-recruiter${NC}"
    echo -e "${YELLOW}   Note: This may be expected if registry is not reachable from host${NC}"
fi

echo -e "\n${GREEN}Done! Frontend images are ready.${NC}"
echo -e "${GREEN}Images will be pulled from in-cluster registry:${NC}"
echo -e "${GREEN}  • ${IN_CLUSTER_REGISTRY}/fe-candidate:latest${NC}"
echo -e "${GREEN}  • ${IN_CLUSTER_REGISTRY}/fe-recruiter:latest${NC}"
