#!/bin/bash
# ================================================================
# API Authentication & Testing Guide
# ================================================================
# This guide shows how to authenticate with Keycloak and test APIs
# ================================================================

set -euo pipefail

# ================================================================
# SECTION 1: GET ACCESS TOKEN
# ================================================================

cat << 'EOF'

════════════════════════════════════════════════════════════════════
   STEP 1: GET ACCESS TOKEN FROM KEYCLOAK
════════════════════════════════════════════════════════════════════

Use one of these methods:

Option A: Use the provided shell script
─────────────────────────────────────
  cd /home/ptb/project/DOAN2
  ./get-keycloak-token.sh

  Select: 0 (for candidate-app-dev)
  
  This will display your access token.

Option B: Manual cURL with Client Credentials Flow
──────────────────────────────────────────────────

  export ENDPOINT="http://172.22.0.4:30003"
  export AUTH_HOST="auth.job7189.local"
  export REALM="job7189"
  export CLIENT_ID="candidate-app-dev"
  export CLIENT_SECRET="KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x"

  curl -X POST \
    -H "Host: ${AUTH_HOST}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    "${ENDPOINT}/realms/${REALM}/protocol/openid-connect/token" \
    -d "grant_type=client_credentials" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}"

  Expected response:
  {
    "access_token": "eyJhbGciOiJSUzI1NiIsInR5...",
    "expires_in": 300,
    "token_type": "Bearer"
  }

Option C: Using Postman
──────────────────────

  1. Create new POST request to:
     http://172.22.0.4:30003/realms/job7189/protocol/openid-connect/token

  2. Set Header:
     Host: auth.job7189.local
     Content-Type: application/x-www-form-urlencoded

  3. Set Body (form-data):
     grant_type: client_credentials
     client_id: candidate-app-dev
     client_secret: KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x

  4. Send → Copy access_token value

════════════════════════════════════════════════════════════════════
   STEP 2: DECODE & VERIFY TOKEN
════════════════════════════════════════════════════════════════════

The token is a JWT with 3 parts separated by dots:
  [header].[payload].[signature]

To decode and see the claims:

  # Using the test script:
  ./test-keycloak-token.sh

  # Or manually (replace TOKEN below):
  TOKEN="your-access-token-here"
  
  # Extract and decode payload:
  echo "$TOKEN" | cut -d'.' -f2 | base64 -d | jq .

Expected payload claims:
{
  "jti": "...",
  "exp": 1234567890,      # Expiration time
  "iat": 1234567800,      # Issued at
  "iss": "http://auth.job7189.local/realms/job7189",  # Issuer
  "aud": "account",
  "sub": "...",           # Subject (client or user)
  "client_id": "candidate-app-dev",
  "preferred_username": "service-account-candidate-app-dev"
}

════════════════════════════════════════════════════════════════════
   STEP 3: USE TOKEN TO CALL PROTECTED APIs
════════════════════════════════════════════════════════════════════

Once you have the access token, include it in API requests:

Option A: Using cURL
────────────────────

  export TOKEN="<your-access-token>"
  export ENDPOINT="http://172.22.0.4:30003"
  export API_HOST="api.job7189.com"

  # Example: Get candidate profile
  curl -X GET \
    -H "Host: ${API_HOST}" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${ENDPOINT}/api/candidate/profile"

  # Other common endpoints:
  ${ENDPOINT}/api/candidate/jobs          # Get candidate jobs
  ${ENDPOINT}/api/candidate/applications  # Get applications
  ${ENDPOINT}/api/workspace/projects      # Get workspace projects

Option B: Using Postman
──────────────────────

  1. Create new GET request to:
     http://172.22.0.4:30003/api/candidate/profile

  2. Set Header:
     Host: api.job7189.com

  3. Go to Authorization tab:
     Type: Bearer Token
     Token: <paste your access_token>

  4. Send

Option C: Using Bash Script
───────────────────────────

  TOKEN=$(./get-keycloak-token.sh 0 | grep "^eyJ" | head -1)

  curl -X GET \
    -H "Host: api.job7189.com" \
    -H "Authorization: Bearer ${TOKEN}" \
    "http://172.22.0.4:30003/api/candidate/profile"

════════════════════════════════════════════════════════════════════
   TROUBLESHOOTING
════════════════════════════════════════════════════════════════════

Issue: "Invalid client or Invalid client credentials"
Solution:
  1. Verify endpoint is reachable:
     curl -I -H "Host: auth.job7189.local" http://172.22.0.4:30003/realms/job7189

  2. Check Client ID and Secret are correct:
     - Look in: /home/ptb/project/DOAN2/get-keycloak-token.sh
     - Or in Vault: vault kv get secret/keycloak/clients

  3. Verify client grant types enabled in Keycloak admin:
     - Realm: job7189
     - Client: candidate-app-dev
     - Check "Standard Flow", "Direct Access Grants", etc.

Issue: "Token expired" or "Signature verification failed"
Solution:
  1. Get a fresh token (expires in 300 seconds by default)
  2. Verify issuer URL matches:
     curl -H "Host: auth.job7189.local" http://172.22.0.4:30003/realms/job7189

Issue: API returns 401 even with valid token
Solution:
  1. Check token is still valid:
     export CURRENT_TIME=$(date +%s)
     TOKEN_EXP=$(echo $TOKEN | cut -d'.' -f2 | base64 -d | jq .exp)
     [ $TOKEN_EXP -gt $CURRENT_TIME ] && echo "Valid" || echo "Expired"

  2. Check Kong is forwarding Authorization header:
     curl -v ... (look for Authorization header in logs)

════════════════════════════════════════════════════════════════════
   KEY INFORMATION
════════════════════════════════════════════════════════════════════

Realm: job7189
Auth Host: auth.job7189.local
API Host: api.job7189.com
Ingress Endpoint: http://172.22.0.4:30003

Available Clients:
  - candidate-app-dev (Client Secret: KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x)
  - recruiter-app-dev (available in get-keycloak-token.sh)

Token Endpoint:
  http://172.22.0.4:30003/realms/job7189/protocol/openid-connect/token

Default Token Expiration: 300 seconds (5 minutes)

════════════════════════════════════════════════════════════════════

EOF
