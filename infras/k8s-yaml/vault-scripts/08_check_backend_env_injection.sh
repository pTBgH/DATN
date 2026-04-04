#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-job7189-apps}"

SERVICES=(
  identity-service
  workspace-service
  job-service
  hiring-service
  candidate-service
  communication-service
  storage-service
)

# Services that should have /vault/secrets/.env.extra injected.
EXTRA_SECRET_SERVICES=(
  identity-service
  communication-service
  storage-service
)

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

contains_service() {
  local svc="$1"
  local item
  for item in "${EXTRA_SECRET_SERVICES[@]}"; do
    if [ "$item" = "$svc" ]; then
      return 0
    fi
  done
  return 1
}

get_first_pod() {
  local svc="$1"
  kubectl get pods -n "$NAMESPACE" -l "app=${svc}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

get_pod_phase() {
  local pod="$1"
  kubectl get pod -n "$NAMESPACE" "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true
}

get_ready_containers() {
  local pod="$1"
  kubectl get pod -n "$NAMESPACE" "$pod" -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null || true
}

check_file_exists() {
  local pod="$1"
  local filepath="$2"
  kubectl exec -n "$NAMESPACE" "$pod" -- test -f "$filepath" >/dev/null 2>&1
}

check_key_in_file() {
  local pod="$1"
  local filepath="$2"
  local key="$3"
  kubectl exec -n "$NAMESPACE" "$pod" -- sh -lc "grep -Eq '^${key}=' ${filepath}" >/dev/null 2>&1
}

require_cmd kubectl
require_cmd grep

section "1) Scope"
if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  pass "namespace ${NAMESPACE} exists"
else
  fail "namespace ${NAMESPACE} missing"
  echo
  echo "Result: FAILED"
  exit 1
fi

section "2) Backend Vault env injection checks"
for svc in "${SERVICES[@]}"; do
  pod="$(get_first_pod "$svc")"
  if [ -z "$pod" ]; then
    fail "${svc}: no pod found"
    continue
  fi

  phase="$(get_pod_phase "$pod")"
  ready_flags="$(get_ready_containers "$pod")"

  if [ "$phase" != "Running" ] || ! printf '%s' "$ready_flags" | grep -q true; then
    fail "${svc}: pod ${pod} is not healthy (phase=${phase:-unknown}, ready=${ready_flags:-unknown})"
    continue
  fi

  pass "${svc}: found healthy pod ${pod}"

  if check_file_exists "$pod" "/vault/secrets/.env.common"; then
    pass "${svc}: /vault/secrets/.env.common exists"
  else
    fail "${svc}: missing /vault/secrets/.env.common"
  fi

  if check_file_exists "$pod" "/vault/secrets/.env.db"; then
    pass "${svc}: /vault/secrets/.env.db exists"
  else
    fail "${svc}: missing /vault/secrets/.env.db"
  fi

  if check_file_exists "$pod" "/app-secrets/.env"; then
    pass "${svc}: merged file /app-secrets/.env exists"
  else
    fail "${svc}: missing merged file /app-secrets/.env"
  fi

  if check_key_in_file "$pod" "/app-secrets/.env" "APP_KEY"; then
    pass "${svc}: APP_KEY present in /app-secrets/.env"
  else
    fail "${svc}: APP_KEY missing in /app-secrets/.env"
  fi

  if check_key_in_file "$pod" "/app-secrets/.env" "DB_USERNAME"; then
    pass "${svc}: DB_USERNAME present in /app-secrets/.env"
  else
    fail "${svc}: DB_USERNAME missing in /app-secrets/.env"
  fi

  if check_key_in_file "$pod" "/app-secrets/.env" "DB_PASSWORD"; then
    pass "${svc}: DB_PASSWORD present in /app-secrets/.env"
  else
    fail "${svc}: DB_PASSWORD missing in /app-secrets/.env"
  fi

  if contains_service "$svc"; then
    if check_file_exists "$pod" "/vault/secrets/.env.extra"; then
      pass "${svc}: expected extra secrets file exists (/vault/secrets/.env.extra)"
    else
      fail "${svc}: expected extra secrets file is missing (/vault/secrets/.env.extra)"
    fi
  else
    if check_file_exists "$pod" "/vault/secrets/.env.extra"; then
      warn "${svc}: has /vault/secrets/.env.extra though not required"
    else
      pass "${svc}: no extra secret file as expected"
    fi
  fi
done

section "3) Summary"
echo "PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} WARN=${WARN_COUNT}"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "Result: FAILED"
  exit 1
fi

echo
echo "Result: OK"
exit 0
