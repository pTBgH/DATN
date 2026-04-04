#!/bin/bash

# ================================================
# Setup Keycloak Clients
# Creates candidate-app-dev and recruiter-app-dev clients
# ================================================

set -e

KEYCLOAK_URL="https://cv-auth.neu.edu.vn"
KEYCLOAK_REALM="topjob"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin123"

echo "=== Setting up Keycloak Clients ==="
echo ""

# Get admin token
echo "[1/3] Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASSWORD" \
  -k | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Failed to get admin token"
  exit 1
fi

echo "✓ Admin token obtained"
echo ""

# Function to create client
create_client() {
  local CLIENT_ID=$1
  local CLIENT_SECRET=$2
  local NAME=$3
  
  echo "[Creating] $NAME"
  
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$KEYCLOAK_REALM/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d @- \
    -k << EOF
{
  "clientId": "$CLIENT_ID",
  "name": "$NAME",
  "secret": "$CLIENT_SECRET",
  "enabled": true,
  "directAccessGrantsEnabled": true,
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "protocol": "openid-connect",
  "clientAuthenticatorType": "client-secret",
  "redirectUris": [
    "http://localhost:3000/*",
    "http://localhost:8000/*",
    "https://cv-auth.neu.edu.vn/*"
  ],
  "webOrigins": [
    "http://localhost:3000",
    "http://localhost:8000",
    "https://cv-auth.neu.edu.vn"
  ]
}
EOF
  
  echo "  ✓ $NAME created"
}

# Create clients
echo "[2/3] Creating clients..."
echo ""

create_client "candidate-app-dev" "KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x" "Candidate Service Client"
create_client "recruiter-app-dev" "yqKvrD4kuUC34robywaDmAcPmfyxhm5v" "Recruiter Service Client"

echo ""
echo "[3/3] Verifying clients..."

# List all clients
CLIENTS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$KEYCLOAK_REALM/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -k | python3 -c "import sys, json; clients = json.load(sys.stdin); print('\\n'.join([c['clientId'] for c in clients if 'app-dev' in c.get('clientId', '')]))" 2>/dev/null)

echo "Created clients:"
echo "$CLIENTS"

echo ""
echo -e "\033[0;32m✅ Keycloak setup complete!\033[0m"
echo ""
echo "Clients are now ready to use:"
echo "  • candidate-app-dev"
echo "  • recruiter-app-dev"
echo ""
