#!/bin/bash

# ================================================
# Keycloak Token Generator
# Gets access bearer token from Keycloak
# ================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_SECRET_ENV_FILE="${CLIENT_SECRET_ENV_FILE:-${SCRIPT_DIR}/keycloak-client-secrets.env}"

if [ -f "$CLIENT_SECRET_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CLIENT_SECRET_ENV_FILE"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Keycloak Config
# Use ingress endpoint by default, can override with env var
KEYCLOAK_URL="${KEYCLOAK_URL:-http://172.22.0.4:30003}"
KEYCLOAK_AUTH_HOST="${KEYCLOAK_AUTH_HOST:-auth.job7189.local}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-job7189}"
GRANT_TYPE="client_credentials"

CANDIDATE_CLIENT_ID="${KEYCLOAK_CANDIDATE_CLIENT_ID:-candidate-app-dev}"
CANDIDATE_CLIENT_SECRET="${KEYCLOAK_CANDIDATE_CLIENT_SECRET:-}"
RECRUITER_CLIENT_ID="${KEYCLOAK_RECRUITER_CLIENT_ID:-recruiter-app-dev}"
RECRUITER_CLIENT_SECRET="${KEYCLOAK_RECRUITER_CLIENT_SECRET:-}"

# Client configs
declare -A CLIENTS=(
    ["0"]="${CANDIDATE_CLIENT_ID}:${CANDIDATE_CLIENT_SECRET}"
    ["1"]="${RECRUITER_CLIENT_ID}:${RECRUITER_CLIENT_SECRET}"
)

declare -A NAMES=(
    ["0"]="Candidate Service"
    ["1"]="Recruiter Service"
)

ARG1="${1:-}"

# Parse arguments or prompt
if [ "$ARG1" != "" ] && [ "$ARG1" != "0" ] && [ "$ARG1" != "1" ]; then
    echo "Usage: $0 [0|1]"
    echo "  0 = Candidate Service token"
    echo "  1 = Recruiter Service token"
    exit 1
fi

if [ "$ARG1" == "" ]; then
    echo ""
    echo -e "${BLUE}=== Keycloak Token Generator ===${NC}"
    echo ""
    echo "Select which token to generate:"
    echo "  0) Candidate Service (candidate-app-dev)"
    echo "  1) Recruiter Service (recruiter-app-dev)"
    echo ""
    read -p "Enter choice [0-1]: " CHOICE
else
    CHOICE=$ARG1
fi

# Validate choice
if [[ ! "$CHOICE" =~ ^[0-1]$ ]]; then
    echo -e "${RED}❌ Invalid choice. Use 0 or 1.${NC}"
    exit 1
fi

# Get client credentials
IFS=':' read -r CLIENT_ID CLIENT_SECRET <<< "${CLIENTS[$CHOICE]}"
SERVICE_NAME="${NAMES[$CHOICE]}"

if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}❌ Client secret is empty for ${CLIENT_ID}.${NC}"
    echo "   Run ./setup-auth.sh to synchronize current secrets from Keycloak,"
    echo "   or set KEYCLOAK_*_CLIENT_SECRET env vars before running this script."
    exit 1
fi

echo ""
echo -e "${YELLOW}Getting token for: ${SERVICE_NAME}${NC}"
echo "Client ID: $CLIENT_ID"
echo ""

# Request token from Keycloak
TOKEN_ENDPOINT="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token"

echo -e "${BLUE}Requesting token from Keycloak...${NC}"
echo "  URL: $TOKEN_ENDPOINT"
echo "  Host: $KEYCLOAK_AUTH_HOST"
echo ""
RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Host: ${KEYCLOAK_AUTH_HOST}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=${GRANT_TYPE}" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -k)

# Parse response
TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('access_token', ''))" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Failed to get token!${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

# Get token expiry
EXPIRES_IN=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('expires_in', 'unknown'))" 2>/dev/null || echo "unknown")
TOKEN_TYPE=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('token_type', 'Bearer'))" 2>/dev/null || echo "Bearer")

# Display token
echo ""
echo -e "${GREEN}✅ Token acquired successfully!${NC}"
echo ""
echo -e "${BLUE}Token Details:${NC}"
echo "  Service: $SERVICE_NAME"
echo "  Token Type: $TOKEN_TYPE"
echo "  Expires In: ${EXPIRES_IN}s"
echo ""
echo -e "${BLUE}Full Bearer Token:${NC}"
echo ""
echo "$TOKEN"
echo ""
echo -e "${BLUE}Use this in API requests:${NC}"
echo "  curl -H \"Authorization: ${TOKEN_TYPE} \$TOKEN\" https://api-endpoint"
echo ""
echo -e "${YELLOW}Token copied to clipboard (if xclip available)${NC}"
echo "$TOKEN" | xclip -selection clipboard 2>/dev/null || true

# Show decoded token header and payload (basic info)
echo ""
echo -e "${BLUE}Token Info (decoded):${NC}"
echo "$TOKEN" | python3 << 'EOF'
import sys
import json
import base64

token = sys.stdin.read().strip()
parts = token.split('.')

if len(parts) >= 2:
    try:
        # Decode header
        header = json.loads(base64.urlsafe_b64decode(parts[0] + '=='))
        print(f"  Header: {json.dumps(header, indent=4)}")
        
        # Decode payload
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + '=='))
        print(f"\n  Payload (Claims):")
        for key in ['sub', 'iss', 'aud', 'exp', 'iat', 'client_id', 'preferred_username']:
            if key in payload:
                print(f"    {key}: {payload[key]}")
    except Exception as e:
        print(f"  Could not decode: {e}")
EOF

echo ""
