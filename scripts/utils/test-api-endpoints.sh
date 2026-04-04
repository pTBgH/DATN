#!/bin/bash

# ================================================================
# API Endpoint Testing Guide
# ================================================================
# Since authentication setup is complex, this guide shows how to
# test APIs with whatwe have and identify auth requirements
# ================================================================

set -euo pipefail

ENDPOINT="http://172.22.0.4:30003"
API_HOST="api.job7189.com"

echo "Testing available API endpoints..."
echo ""
echo "=================================================================="
echo "  API ENDPOINT TESTING"
echo "=================================================================="
echo ""

# Test 1: Health check (usually public)
echo "TEST 1: Health/Status Endpoints (typically public)"
echo "─────────────────────────────────────────────────"
echo ""
echo "Request:"
echo "  curl -i -H 'Host: ${API_HOST}' '${ENDPOINT}/api/health'"
echo ""
echo "Response:"
curl -sS -i -H "Host: ${API_HOST}" "${ENDPOINT}/api/health" | head -20
echo ""
echo ""

# Test 2: Candidate profile (likely requires auth)
echo "TEST 2: Candidate Profile (likely requires auth)"
echo "─────────────────────────────────────────────────"
echo ""
echo "Request:"
echo "  curl -i -H 'Host: ${API_HOST}' '${ENDPOINT}/api/candidate/profile'"
echo ""
echo "Response:"
curl -sS -i -H "Host: ${API_HOST}" "${ENDPOINT}/api/candidate/profile" 2>&1 | head -30
echo ""
echo ""

# Test 3: Job listings (might be public)
echo "TEST 3: Job Listings (might be public)"
echo "────────────────────────────────────"
echo ""
echo "Request:"
echo "  curl -i -H 'Host: ${API_HOST}' '${ENDPOINT}/api/jobs'"
echo ""
echo "Response:"
curl -sS -i -H "Host: ${API_HOST}" "${ENDPOINT}/api/jobs" 2>&1 | head -30
echo ""
echo ""

# Test 4: Check OPTIONS (CORS preflight, API metadata)
echo "TEST 4: OPTIONS Request (API Metadata)"
echo "─────────────────────────────────────"
echo ""
echo "Request:"  
echo "  curl -i -X OPTIONS -H 'Host: ${API_HOST}' '${ENDPOINT}/api/candidate/profile'"
echo ""
echo "Response:"
curl -sS -i -X OPTIONS -H "Host: ${API_HOST}" "${ENDPOINT}/api/candidate/profile" 2>&1 | head -30
echo ""
echo ""
echo ""
echo "=================================================================="
echo "  POSTMAN QUICK SETUP"
echo "=================================================================="
echo ""
echo "For testing in Postman:"
echo ""
echo "1. Create a GET request"
echo "2. URL: http://172.22.0.4:30003/api/health"
echo "3. Headers:"
echo "   Host: api.job7189.com"
echo "4. Send"
echo ""
echo "If you get 401:"
echo "  - Endpoint requires authentication"
echo "  - You need to pass an Authorization token"
echo "  - See API-AUTHENTICATION-GUIDE.md for how to get a token"
echo ""
echo "If you get 404:"
echo "  - Endpoint doesn't exist"
echo "  - Check the correct path"
echo ""
echo "If you get 200:"
echo "  - Endpoint is public and working!"
echo ""
