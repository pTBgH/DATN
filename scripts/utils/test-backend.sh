#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_BASE_URL="${1:-http://localhost:8000}"
KEYCLOAK_URL="${2:-http://localhost:8080}"

echo -e "${BLUE}=== Frontend Backend Connectivity Test ===${NC}\n"

# Test 1: API Gateway Health
echo -e "${YELLOW}Test 1: API Gateway Health${NC}"
response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/health" 2>/dev/null || echo "error\n0")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ API Gateway is running${NC}\n"
else
    echo -e "${RED}✗ API Gateway is not responding (HTTP $http_code)${NC}\n"
fi

# Test 2: Keycloak Health
echo -e "${YELLOW}Test 2: Keycloak Server${NC}"
response=$(curl -s -w "\n%{http_code}" "$KEYCLOAK_URL/auth/realms/job7189" 2>/dev/null || echo "error\n0")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ Keycloak is reachable${NC}\n"
else
    echo -e "${RED}✗ Keycloak is not responding (HTTP $http_code)${NC}\n"
fi

# Test 3: Job Service
echo -e "${YELLOW}Test 3: Job Service${NC}"
response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$API_BASE_URL/api/jobs" 2>/dev/null || echo "error\n0")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Job Service is accessible${NC}\n"
else
    echo -e "${RED}✗ Job Service error (HTTP $http_code)${NC}\n"
fi

# Test 4: Candidate Service
echo -e "${YELLOW}Test 4: Candidate Service${NC}"
response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$API_BASE_URL/api/candidates" 2>/dev/null || echo "error\n0")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Candidate Service is accessible${NC}\n"
else
    echo -e "${RED}✗ Candidate Service error (HTTP $http_code)${NC}\n"
fi

# Test 5: Hiring Service
echo -e "${YELLOW}Test 5: Hiring Service${NC}"
response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$API_BASE_URL/api/hiring-board" 2>/dev/null || echo "error\n0")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Hiring Service is accessible${NC}\n"
else
    echo -e "${RED}✗ Hiring Service error (HTTP $http_code)${NC}\n"
fi

# Test 6: Storage Service
echo -e "${YELLOW}Test 6: Storage Service (MinIO)${NC}"
response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/api/storage/health" 2>/dev/null || echo "error\n0")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
    echo -e "${GREEN}✓ Storage Service is accessible${NC}\n"
else
    echo -e "${YELLOW}⚠ Storage Service status unknown (HTTP $http_code)${NC}\n"
fi

echo -e "${BLUE}=== Test Complete ===${NC}"
echo -e "\n${YELLOW}Usage:${NC}"
echo "  ./test-backend.sh [API_BASE_URL] [KEYCLOAK_URL]"
echo -e "\n${YELLOW}Examples:${NC}"
echo "  ./test-backend.sh http://localhost:8000 http://localhost:8080"
echo "  ./test-backend.sh http://api.local:8000 http://keycloak.local:8080"
