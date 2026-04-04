#!/bin/bash

set -euo pipefail

REALM="${REALM:-job7189}"
AUTH_HOST="${AUTH_HOST:-auth.job7189.local}"
API_HOST="${API_HOST:-api.job7189.com}"
KONG_NAMESPACE="${KONG_NAMESPACE:-gateway}"
SECURITY_NAMESPACE="${SECURITY_NAMESPACE:-security}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_SERVICE="${INGRESS_SERVICE:-ingress-nginx-controller}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo
  echo -e "${BLUE}======================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}======================================================${NC}"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 2
  fi
}

collect_ingress_endpoints() {
  local lb_ip lb_host node_port
  lb_ip="$(kubectl get svc -n "$INGRESS_NAMESPACE" "$INGRESS_SERVICE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  lb_host="$(kubectl get svc -n "$INGRESS_NAMESPACE" "$INGRESS_SERVICE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  node_port="$(kubectl get svc -n "$INGRESS_NAMESPACE" "$INGRESS_SERVICE" -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null || true)"

  if [ -n "$lb_ip" ]; then
    echo "$lb_ip:80"
  fi

  if [ -n "$lb_host" ]; then
    echo "$lb_host:80"
  fi

  if [ -n "$node_port" ]; then
    echo "127.0.0.1:${node_port}"
    kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' 2>/dev/null | awk 'NF{print $1":"np}' np="$node_port"
  fi
}

http_code_with_host() {
  local endpoint="$1"
  local host="$2"
  local path="$3"
  curl -sS -o /tmp/check_kong_keycloak_resp.json -w '%{http_code}' -H "Host: ${host}" "http://${endpoint}${path}" || true
}

require_cmd kubectl
require_cmd curl
require_cmd awk
require_cmd grep

section "1) Runtime prerequisites"
if kubectl cluster-info >/dev/null 2>&1; then
  pass "kubectl can reach cluster"
else
  fail "kubectl cannot reach cluster"
fi

if kubectl get ns "$KONG_NAMESPACE" >/dev/null 2>&1; then
  pass "namespace ${KONG_NAMESPACE} exists"
else
  fail "namespace ${KONG_NAMESPACE} missing"
fi

if kubectl get ns "$SECURITY_NAMESPACE" >/dev/null 2>&1; then
  pass "namespace ${SECURITY_NAMESPACE} exists"
else
  fail "namespace ${SECURITY_NAMESPACE} missing"
fi

section "2) Kong declarative config checks"
ISSUER="http://${AUTH_HOST}/realms/${REALM}"
CM_CONTENT="$(kubectl get configmap -n "$KONG_NAMESPACE" kong-declarative-config -o jsonpath='{.data.kong\.yml}' 2>/dev/null || true)"
if [ -z "$CM_CONTENT" ]; then
  fail "configmap kong-declarative-config or key kong.yml not found"
else
  pass "loaded kong declarative config from configmap"
  if printf '%s\n' "$CM_CONTENT" | grep -F "key: \"${ISSUER}\"" >/dev/null 2>&1; then
    pass "JWT issuer key matches expected issuer ${ISSUER}"
  else
    fail "JWT issuer key does not match expected issuer ${ISSUER}"
  fi
fi

section "3) In-cluster Keycloak realm reachability"
REALM_URL="http://keycloak.${SECURITY_NAMESPACE}.svc.cluster.local:8080/realms/${REALM}"
REALM_HTTP_CODE="$(kubectl run -i --rm --restart=Never --image=curlimages/curl:8.7.1 -n "$KONG_NAMESPACE" kc-realm-check --command -- sh -c "code=\$(curl -sS -o /tmp/r.json -w '%{http_code}' ${REALM_URL} || true); echo HTTP_CODE=\$code; head -c 120 /tmp/r.json; echo" 2>/dev/null | awk -F= '/^HTTP_CODE=/{print $2}' | tail -n1)"
if [ "$REALM_HTTP_CODE" = "200" ]; then
  pass "Kong namespace can reach Keycloak realm URL (${REALM_URL})"
else
  fail "Kong namespace cannot reach Keycloak realm URL (${REALM_URL}), HTTP=${REALM_HTTP_CODE:-none}"
fi

section "4) Local host routing checks"
ENDPOINTS="$(collect_ingress_endpoints | awk 'NF' | awk '!seen[$0]++')"
if [ -z "$ENDPOINTS" ]; then
  fail "cannot determine ingress endpoint from service ${INGRESS_NAMESPACE}/${INGRESS_SERVICE}"
  ENDPOINT=""
else
  pass "collected candidate ingress endpoints"
  ENDPOINT=""
  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    code="$(http_code_with_host "$candidate" "$AUTH_HOST" "/realms/${REALM}")"
    if [ "$code" != "000" ]; then
      ENDPOINT="$candidate"
      break
    fi
  done <<EOF
$ENDPOINTS
EOF

  if [ -n "$ENDPOINT" ]; then
    pass "selected reachable ingress endpoint ${ENDPOINT}"
  else
    fail "no candidate ingress endpoint is reachable from this host"
  fi
fi

if [ -n "$ENDPOINT" ]; then
  AUTH_CODE="$(http_code_with_host "$ENDPOINT" "$AUTH_HOST" "/realms/${REALM}")"
  if [ "$AUTH_CODE" = "200" ]; then
    pass "local route for ${AUTH_HOST} serves Keycloak realm ${REALM}"
  else
    fail "local route for ${AUTH_HOST} did not return realm JSON (HTTP=${AUTH_CODE})"
  fi

  API_CODE="$(http_code_with_host "$ENDPOINT" "$API_HOST" "/api/health")"
  if [ "$API_CODE" = "200" ] || [ "$API_CODE" = "401" ] || [ "$API_CODE" = "404" ]; then
    pass "api host ${API_HOST} is reachable through ingress/Kong (HTTP=${API_CODE})"
  else
    warn "api host ${API_HOST} response looks unusual (HTTP=${API_CODE})"
  fi
fi

section "5) Summary"
echo "PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} WARN=${WARN_COUNT}"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "Result: FAILED"
  echo "Hint: if local host test fails but in-cluster realm test passes, check /etc/hosts and ingress NodePort usage."
  exit 1
fi

echo
echo "Result: OK"
exit 0
