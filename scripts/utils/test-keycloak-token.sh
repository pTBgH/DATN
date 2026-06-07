#!/bin/bash
# ================================================================
# Test Keycloak Token & API Calls
# ================================================================
# This script demonstrates how to:
# 1. Get access token from Keycloak
# 2. Make authenticated API calls using the token
# ================================================================

set -uo pipefail

# Configuration
REALM="${REALM:-job7189}"
AUTH_HOST="${AUTH_HOST:-auth.job7189.local}"
API_HOST="${API_HOST:-api.job7189.com}"
INGRESS_PORT="${INGRESS_PORT:-30003}"
INGRESS_IP="${INGRESS_IP:-172.22.0.4}"

# Credentials - you should store these securely in Vault
CLIENT_ID="${CLIENT_ID:-candidate-app}"
CLIENT_SECRET="${CLIENT_SECRET:-MYIpuUHIlIFyrfk1zjktZcnChO3WTFYW}"  # Get from Vault secret
USERNAME="${USERNAME:-testuser}"
PASSWORD="${PASSWORD:-testpass}"

# Which grant type to use: password or client_credentials
GRANT_TYPE="${GRANT_TYPE:-client_credentials}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_section() {
  echo
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
  echo -e "${YELLOW}→${NC} $1"
}

print_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
  echo -e "${RED}✗${NC} $1"
}

print_section "KEYCLOAK TOKEN & API TEST"

# Step 1: Display configuration
print_step "Configuration"
echo "Realm: $REALM"
echo "Auth Host: $AUTH_HOST"
echo "API Host: $API_HOST"
echo "Ingress Endpoint: http://${INGRESS_IP}:${INGRESS_PORT}"
echo "Client ID: $CLIENT_ID"
echo ""

# Step 2: Determine endpoint
print_step "Determining reachable endpoint..."
ENDPOINT="http://${INGRESS_IP}:${INGRESS_PORT}"

# Test connectivity
if curl -sf -o /dev/null -H "Host: ${AUTH_HOST}" "${ENDPOINT}/realms/${REALM}" 2>/dev/null; then
  print_pass "Endpoint reachable: ${ENDPOINT}"
else
  print_fail "Endpoint not reachable: ${ENDPOINT}"
  echo "Try one of these alternatives:"
  echo "  - INGRESS_IP=localhost INGRESS_PORT=80 $0"
  echo "  - INGRESS_IP=<your-machine-ip> $0"
  exit 1
fi

# Step 3: Get token using Resource Owner Password flow
print_section "STEP 1: GET ACCESS TOKEN (Resource Owner Password Flow)"

echo "Request:"
echo "POST http://${INGRESS_IP}:${INGRESS_PORT}/realms/${REALM}/protocol/openid-connect/token"
echo ""

if [ "$GRANT_TYPE" = "client_credentials" ]; then
  TOKEN_RESPONSE=$(curl -sS -X POST \
    -H "Host: ${AUTH_HOST}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    "${ENDPOINT}/realms/${REALM}/protocol/openid-connect/token" \
    -d "grant_type=client_credentials" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}")
else
  TOKEN_RESPONSE=$(curl -sS -X POST \
    -H "Host: ${AUTH_HOST}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    "${ENDPOINT}/realms/${REALM}/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "client_id=${CLIENT_ID}" \
    -d "username=${USERNAME}" \
    -d "password=${PASSWORD}")
fi

echo "Response:"
echo "$TOKEN_RESPONSE" | jq . 2>/dev/null || echo "$TOKEN_RESPONSE"
echo ""

# Extract token
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "")
TOKEN_TYPE=$(echo "$TOKEN_RESPONSE" | jq -r '.token_type' 2>/dev/null || echo "Bearer")
EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in' 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ] || [ "$ACCESS_TOKEN" = "" ]; then
  ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description' 2>/dev/null || echo "Unknown error")
  print_fail "Failed to get token: $ERROR_DESC"
  echo ""
  echo "Troubleshooting:"
  if [ "$GRANT_TYPE" = "password" ]; then
    echo "1. Check if user credentials are correct: USERNAME=$USERNAME PASSWORD=$PASSWORD"
    echo "2. Verify user exists in Keycloak realm"
  else
    echo "1. Check if client credentials are correct:"
    echo "   CLIENT_ID=$CLIENT_ID"
    echo "   CLIENT_SECRET=$CLIENT_SECRET"
    echo "2. Verify client is configured with client_credentials auth flow enabled"
  fi
  echo "3. Verify Keycloak realm setup with:"
  echo "   curl -H 'Host: ${AUTH_HOST}' http://${INGRESS_IP}:${INGRESS_PORT}/realms/${REALM}"
  exit 1
fi

print_pass "Token received"
echo "Token Type: $TOKEN_TYPE"
echo "Expires In: $EXPIRES_IN seconds"
echo ""

# Step 4: Decode and display token claims
print_section "STEP 2: DECODE TOKEN (JWT Claims)"

# Extract payload (second part of JWT)
PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2)

# Add padding if needed
PADDING=$((${#PAYLOAD} % 4))
if [ $PADDING -eq 1 ]; then
  PAYLOAD="${PAYLOAD}==="
elif [ $PADDING -eq 2 ]; then
  PAYLOAD="${PAYLOAD}=="
elif [ $PADDING -eq 3 ]; then
  PAYLOAD="${PAYLOAD}="
fi

echo "Decoded Claims:"
echo "$PAYLOAD" | base64 -d 2>/dev/null | jq . || echo "Cannot decode (install jq for better output)"
echo ""

# Step 5: Make authenticated API call
print_section "STEP 3: MAKE AUTHENTICATED API CALL"

# Try candidate profile endpoint
API_ENDPOINT="/api/candidate/profile"
echo "Request:"
echo "GET http://${INGRESS_IP}:${INGRESS_PORT}${API_ENDPOINT}"
echo "Host: ${API_HOST}"
echo "Authorization: ${TOKEN_TYPE} <token>"
echo ""

API_RESPONSE=$(curl -sS -X GET \
  -H "Host: ${API_HOST}" \
  -H "Authorization: ${TOKEN_TYPE} ${ACCESS_TOKEN}" \
  "${ENDPOINT}${API_ENDPOINT}")

echo "Response:"
echo "$API_RESPONSE" | jq . 2>/dev/null || echo "$API_RESPONSE"
echo ""

# Step 6: Summary
print_section "SUMMARY"

if [ -n "$TOKEN_TYPE" ] && [ -n "$ACCESS_TOKEN" ]; then
  print_pass "Token obtained successfully"
  echo ""
  echo "For use in Postman:"
  echo ""
  echo "1. Go to 'Authorization' tab"
  echo "2. Set Type to 'Bearer Token'"
  echo "3. Paste this token:"
  echo "   ${ACCESS_TOKEN:0:50}..."
  echo ""
  echo "Or use curl:"
  echo "   curl -H \"Authorization: ${TOKEN_TYPE} ${ACCESS_TOKEN}\" \\"
  echo "        http://${INGRESS_IP}:${INGRESS_PORT}${API_ENDPOINT} \\"
  echo "        -H \"Host: ${API_HOST}\""
else
  print_fail "Could not obtain token"
fi

echo ""
