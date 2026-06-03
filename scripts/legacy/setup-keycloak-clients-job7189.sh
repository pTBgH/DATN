#!/bin/bash

# ================================================
# Setup Keycloak Clients for job7189 Realm
# Creates candidate-app-dev and recruiter-app-dev clients
# ================================================

set -euo pipefail

# Configuration for local cluster
KEYCLOAK_ENDPOINT="${KEYCLOAK_ENDPOINT:-http://172.22.0.4:30003}"
KEYCLOAK_AUTH_HOST="${KEYCLOAK_AUTH_HOST:-auth.job7189.local}"
KEYCLOAK_REALM="job7189"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BLUE}=== Setting up Keycloak Clients (Realm: ${KEYCLOAK_REALM}) ===${NC}"
echo "Endpoint: ${KEYCLOAK_ENDPOINT}"
echo "Auth Host: ${KEYCLOAK_AUTH_HOST}"
echo ""

# Step 1: Get admin token
echo -e "${YELLOW}[1/3] Getting admin token...${NC}"

ADMIN_TOKEN=$(curl -sS -X POST \
  -H "Host: ${KEYCLOAK_AUTH_HOST}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  "${KEYCLOAK_ENDPOINT}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -k 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('access_token', ''))" 2>/dev/null || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
  echo -e "${RED}❌ Failed to get admin token${NC}"
  echo "   Ensure Keycloak is running and accessible at:"
  echo "     curl -H 'Host: ${KEYCLOAK_AUTH_HOST}' ${KEYCLOAK_ENDPOINT}/realms/master"
  exit 1
fi

echo -e "${GREEN}✓ Admin token obtained${NC}"
echo ""

# Step 2: Create clients
echo -e "${YELLOW}[2/3] Creating clients...${NC}"
echo ""

create_client() {
  local CLIENT_ID=$1
  local CLIENT_SECRET=$2
  local CLIENT_NAME=$3
  
  # Debug
  echo -e "  ${YELLOW}→${NC} Creating ${CLIENT_NAME} (${CLIENT_ID})..."
  
  RESPONSE=$(curl -sS -X POST \
    -H "Host: ${KEYCLOAK_AUTH_HOST}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    "${KEYCLOAK_ENDPOINT}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -d "{
      \"clientId\": \"${CLIENT_ID}\",
      \"name\": \"${CLIENT_NAME}\",
      \"secret\": \"${CLIENT_SECRET}\",
      \"enabled\": true,
      \"publicClient\": false,
      \"serviceAccountsEnabled\": true,
      \"standardFlowEnabled\": true,
      \"directAccessGrantsEnabled\": true,
      \"implicitFlowEnabled\": false,
      \"protocol\": \"openid-connect\",
      \"clientAuthenticatorType\": \"client-secret\",
      \"redirectUris\": [
        \"http://localhost:3000/*\",
        \"http://localhost:8000/*\",
        \"http://api.job7189.com/*\"
      ],
      \"webOrigins\": [
        \"http://localhost:3000\",
        \"http://localhost:8000\",
        \"http://api.job7189.com\"
      ]
    }" \
    -k 2>/dev/null)
  
  HTTP_CODE=$(echo "$RESPONSE" | tail -c 5)
  
  if echo "$RESPONSE" | grep -q "Conflict" || echo "$RESPONSE" | grep -q "already exists"; then
    echo -e "    ${YELLOW}⚠${NC}  Client already exists, skipping"
  elif echo "$RESPONSE" | grep -q "\"id\""; then
    echo -e "    ${GREEN}✓${NC}  ${CLIENT_NAME} created successfully"
  else
    echo -e "    ${RED}✗${NC}  Failed to create ${CLIENT_NAME}"
    echo "    Response: $(echo "$RESPONSE" | head -c 200)"
    return 1
  fi
}

create_client "candidate-app-dev" "KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x" "Candidate Service Client"
create_client "recruiter-app-dev" "yqKvrD4kuUC34robywaDmAcPmfyxhm5v" "Recruiter Service Client"

echo ""
echo -e "${YELLOW}[3/3] Verifying clients...${NC}"

# List clients
CLIENTS_JSON=$(curl -sS -X GET \
  -H "Host: ${KEYCLOAK_AUTH_HOST}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_ENDPOINT}/admin/realms/${KEYCLOAK_REALM}/clients" \
  -k 2>/dev/null)

FOUND_CLIENTS=$(echo "$CLIENTS_JSON" | python3 -c "
import sys, json
try:
    clients = json.load(sys.stdin)
    app_clients = [c for c in clients if 'app-dev' in c.get('clientId', '')]
    for client in app_clients:
        print(f\"{client['clientId']}: enabled={client['enabled']}, serviceAccounts={client.get('serviceAccountsEnabled')}\"  )
except:
    pass
" 2>/dev/null)

if [ -n "$FOUND_CLIENTS" ]; then
  echo "$FOUND_CLIENTS"
  echo ""
  echo -e "${GREEN}✅ Keycloak setup complete!${NC}"
  echo ""
  echo "Clients are now ready to use:"
  echo "  • candidate-app-dev (secret: KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x)"
  echo "  • recruiter-app-dev (secret: yqKvrD4kuUC34robywaDmAcPmfyxhm5v)"
  echo ""
  echo "To get a token:"
  echo "  cd /home/ptb/project/DOAN2"
  echo "  ./get-keycloak-token.sh"
  echo ""
else
  echo -e "${RED}❌ Could not verify clients${NC}"
  echo "Response: $(echo "$CLIENTS_JSON" | head -c 300)"
  exit 1
fi
