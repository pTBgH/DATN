#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_UTILS_DIR="${ROOT_DIR}/scripts/utils"

REALM="${REALM:-job7189}"
AUTH_HOST="${AUTH_HOST:-auth.job7189.local}"
API_HOST="${API_HOST:-api.job7189.com}"
KONG_HOST="${KONG_HOST:-kong.job7189.com}"
HOST_IP="${HOST_IP:-127.0.0.1}"
KEYCLOAK_LOCAL_ENDPOINT="${KEYCLOAK_LOCAL_ENDPOINT:-}"

KONG_NAMESPACE="${KONG_NAMESPACE:-gateway}"
SECURITY_NAMESPACE="${SECURITY_NAMESPACE:-security}"

KONG_CONFIG="${KONG_CONFIG:-${ROOT_DIR}/infras/kong/kong.yml}"
CLIENT_SECRETS_ENV_FILE="${CLIENT_SECRETS_ENV_FILE:-${SCRIPT_UTILS_DIR}/keycloak-client-secrets.env}"

SYNC_CLIENT_SECRETS="${SYNC_CLIENT_SECRETS:-1}"

HOSTS_BLOCK_START="# BEGIN job7189-auth-sync"
HOSTS_BLOCK_END="# END job7189-auth-sync"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

ok() {
  echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

fail() {
  echo -e "${RED}[ERROR]${NC} $*"
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

detect_ingress_nodeport() {
  kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null || true
}

can_reach_keycloak_endpoint() {
  local endpoint="$1"
  local code

  code="$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Host: ${AUTH_HOST}" \
    "${endpoint}/realms/${REALM}" || true)"

  [ "$code" != "000" ]
}

resolve_keycloak_local_endpoint() {
  local node_port candidate

  if [ -n "$KEYCLOAK_LOCAL_ENDPOINT" ]; then
    ok "Using configured Keycloak endpoint: ${KEYCLOAK_LOCAL_ENDPOINT}"
    return 0
  fi

  node_port="$(detect_ingress_nodeport)"
  if [ -z "$node_port" ]; then
    fail "Could not detect ingress NodePort for HTTP"
  fi

  candidate="http://127.0.0.1:${node_port}"
  if can_reach_keycloak_endpoint "$candidate"; then
    KEYCLOAK_LOCAL_ENDPOINT="$candidate"
    ok "Detected reachable Keycloak endpoint: ${KEYCLOAK_LOCAL_ENDPOINT}"
    return 0
  fi

  while IFS= read -r node_ip; do
    [ -z "$node_ip" ] && continue
    candidate="http://${node_ip}:${node_port}"
    if can_reach_keycloak_endpoint "$candidate"; then
      KEYCLOAK_LOCAL_ENDPOINT="$candidate"
      ok "Detected reachable Keycloak endpoint: ${KEYCLOAK_LOCAL_ENDPOINT}"
      return 0
    fi
  done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' 2>/dev/null)

  fail "Could not find a reachable local Keycloak endpoint via ingress NodePort"
}

write_with_optional_sudo() {
  local src="$1"
  local dst="$2"

  if [ -w "$dst" ]; then
    cp "$src" "$dst"
  elif command -v sudo >/dev/null 2>&1; then
    if ! sudo -n cp "$src" "$dst" 2>/dev/null; then
      warn "Cannot write $dst without interactive sudo. Skipping."
      return 1
    fi
  else
    warn "Cannot write $dst (no permission and sudo not available). Skipping."
    return 1
  fi

  return 0
}

ensure_local_hosts_block() {
  local tmp_current tmp_new
  tmp_current="$(mktemp)"
  tmp_new="$(mktemp)"

  awk -v begin="$HOSTS_BLOCK_START" -v end="$HOSTS_BLOCK_END" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    skip != 1 {print}
  ' /etc/hosts > "$tmp_current"

  cat "$tmp_current" > "$tmp_new"
  {
    echo "$HOSTS_BLOCK_START"
    echo "$HOST_IP $AUTH_HOST $API_HOST $KONG_HOST"
    echo "$HOSTS_BLOCK_END"
  } >> "$tmp_new"

  if cmp -s "$tmp_new" /etc/hosts; then
    ok "/etc/hosts already synchronized"
    rm -f "$tmp_current" "$tmp_new"
    return 0
  fi

  if write_with_optional_sudo "$tmp_new" /etc/hosts; then
    ok "Updated /etc/hosts for auth/api hostnames"
  fi

  rm -f "$tmp_current" "$tmp_new"
}

fetch_keycloak_jwks() {
  curl -fsS \
    -H "Host: ${AUTH_HOST}" \
    "${KEYCLOAK_LOCAL_ENDPOINT}/realms/${REALM}/protocol/openid-connect/certs"
}

extract_public_key_from_jwks() {
  local jwks_json="$1"
  local x5c cert_pem

  x5c="$(printf '%s' "$jwks_json" | python3 -c '
import json, sys
jwks = json.load(sys.stdin)
selected = None
for key in jwks.get("keys", []):
    if key.get("kty") == "RSA" and key.get("use", "sig") == "sig" and key.get("x5c"):
        selected = key
        break
if selected is None:
    for key in jwks.get("keys", []):
        if key.get("kty") == "RSA" and key.get("x5c"):
            selected = key
            break
if selected is None:
    raise SystemExit(1)
print(selected["x5c"][0])
' 2>/dev/null || true)"

  if [ -z "$x5c" ]; then
    fail "Unable to extract x5c from Keycloak JWKS"
  fi

  cert_pem="$(printf -- '-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n' "$(printf '%s' "$x5c" | fold -w 64)")"

  printf '%s\n' "$cert_pem" | openssl x509 -pubkey -noout
}

replace_managed_kong_public_keys() {
  local pubkey_file="$1"

  python3 - "$KONG_CONFIG" "$pubkey_file" <<'PY'
import re
import sys

config_path = sys.argv[1]
pubkey_path = sys.argv[2]

with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()

with open(pubkey_path, 'r', encoding='utf-8') as f:
    pem_lines = [line.rstrip('\n') for line in f if line.strip()]

replacement = "        # BEGIN JOB7189 JWT PUBLIC KEY\n"
replacement += "        rsa_public_key: |\n"
for line in pem_lines:
    replacement += f"          {line}\n"
replacement += "        # END JOB7189 JWT PUBLIC KEY\n"

pattern = re.compile(
    r"^[ \t]*# BEGIN JOB7189 JWT PUBLIC KEY\n"
    r"[ \t]*rsa_public_key: \|\n"
    r"(?:[ \t].*\n)*?"
    r"[ \t]*# END JOB7189 JWT PUBLIC KEY\n",
    flags=re.MULTILINE,
)

new_content, count = pattern.subn(replacement, content)
if count == 0:
    print("no managed key blocks found", file=sys.stderr)
    sys.exit(1)

with open(config_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(count)
PY
}

reload_kong_config() {
  bash "$ROOT_DIR/infras/kong/01_setup_kong_config.sh"
  kubectl rollout restart deployment/kong-gateway -n "$KONG_NAMESPACE" >/dev/null
  kubectl rollout status deployment/kong-gateway -n "$KONG_NAMESPACE" --timeout=240s >/dev/null
  ok "Kong config reloaded"
}

get_secret_value() {
  local namespace="$1"
  local secret_name="$2"
  local key="$3"

  kubectl get secret -n "$namespace" "$secret_name" -o jsonpath="{.data.${key}}" 2>/dev/null | base64 -d 2>/dev/null || true
}

get_keycloak_admin_password() {
  local password

  password="$(get_secret_value "$SECURITY_NAMESPACE" app-secrets keycloak-admin-password)"
  if [ -z "$password" ]; then
    password="$(get_secret_value data app-secrets keycloak-admin-password)"
  fi

  if [ -z "$password" ]; then
    fail "Could not read keycloak-admin-password from app-secrets"
  fi

  printf '%s' "$password"
}

fetch_keycloak_admin_token() {
  local admin_user admin_pass response token

  admin_user="${KEYCLOAK_ADMIN_USER:-admin}"
  admin_pass="$(get_keycloak_admin_password)"

  response="$(curl -fsS -X POST \
    -H "Host: ${AUTH_HOST}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    "${KEYCLOAK_LOCAL_ENDPOINT}/realms/master/protocol/openid-connect/token")"

  token="$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null || true)"

  if [ -z "$token" ]; then
    fail "Unable to get Keycloak admin token"
  fi

  printf '%s' "$token"
}

fetch_keycloak_client_uuid() {
  local admin_token="$1"
  local client_id="$2"
  local response client_uuid

  response="$(curl -fsS -G \
    -H "Host: ${AUTH_HOST}" \
    -H "Authorization: Bearer ${admin_token}" \
    --data-urlencode "clientId=${client_id}" \
    "${KEYCLOAK_LOCAL_ENDPOINT}/admin/realms/${REALM}/clients")"

  client_uuid="$(printf '%s' "$response" | python3 -c '
import json,sys
items = json.load(sys.stdin)
if isinstance(items, list) and items:
    print(items[0].get("id", ""))
' 2>/dev/null || true)"

  if [ -z "$client_uuid" ]; then
    fail "Could not resolve client UUID for ${client_id}"
  fi

  printf '%s' "$client_uuid"
}

fetch_keycloak_client_secret() {
  local admin_token="$1"
  local client_id="$2"
  local client_uuid response client_secret

  client_uuid="$(fetch_keycloak_client_uuid "$admin_token" "$client_id")"

  response="$(curl -fsS \
    -H "Host: ${AUTH_HOST}" \
    -H "Authorization: Bearer ${admin_token}" \
    "${KEYCLOAK_LOCAL_ENDPOINT}/admin/realms/${REALM}/clients/${client_uuid}/client-secret")"

  client_secret="$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("value",""))' 2>/dev/null || true)"

  if [ -z "$client_secret" ]; then
    fail "Could not fetch secret for client ${client_id}"
  fi

  printf '%s' "$client_secret"
}

sync_client_secrets_file() {
  local admin_token candidate_client recruiter_client candidate_secret recruiter_secret tmp_file

  candidate_client="${KEYCLOAK_CANDIDATE_CLIENT_ID:-candidate-app-dev}"
  recruiter_client="${KEYCLOAK_RECRUITER_CLIENT_ID:-recruiter-app-dev}"

  admin_token="$(fetch_keycloak_admin_token)"
  candidate_secret="$(fetch_keycloak_client_secret "$admin_token" "$candidate_client")"
  recruiter_secret="$(fetch_keycloak_client_secret "$admin_token" "$recruiter_client")"

  mkdir -p "$(dirname "$CLIENT_SECRETS_ENV_FILE")"
  tmp_file="$(mktemp)"

  cat > "$tmp_file" <<EOF_SECRETS
# Generated by setup-auth.sh. Do not edit manually.
KEYCLOAK_URL=${KEYCLOAK_LOCAL_ENDPOINT}
KEYCLOAK_AUTH_HOST=${AUTH_HOST}
KEYCLOAK_REALM=${REALM}
KEYCLOAK_CANDIDATE_CLIENT_ID=${candidate_client}
KEYCLOAK_CANDIDATE_CLIENT_SECRET=${candidate_secret}
KEYCLOAK_RECRUITER_CLIENT_ID=${recruiter_client}
KEYCLOAK_RECRUITER_CLIENT_SECRET=${recruiter_secret}
EOF_SECRETS

  if [ -f "$CLIENT_SECRETS_ENV_FILE" ] && cmp -s "$tmp_file" "$CLIENT_SECRETS_ENV_FILE"; then
    ok "Client secrets env file already up to date"
    rm -f "$tmp_file"
    return 0
  fi

  mv "$tmp_file" "$CLIENT_SECRETS_ENV_FILE"
  chmod 600 "$CLIENT_SECRETS_ENV_FILE"
  ok "Wrote synchronized client secrets: ${CLIENT_SECRETS_ENV_FILE}"
}

main() {
  require_cmd kubectl
  require_cmd curl
  require_cmd awk
  require_cmd sed
  require_cmd python3
  require_cmd openssl
  require_cmd fold
  require_cmd base64
  require_cmd cmp

  [ -f "$KONG_CONFIG" ] || fail "Missing Kong config file: $KONG_CONFIG"

  resolve_keycloak_local_endpoint

  log "1/5 Syncing local hostname mappings"
  ensure_local_hosts_block

  log "2/5 Refreshing Kong JWT public key(s) from live Keycloak JWKS"
  jwks_json="$(fetch_keycloak_jwks)"
  pubkey_pem="$(extract_public_key_from_jwks "$jwks_json")"

  tmp_pubkey="$(mktemp)"
  printf '%s\n' "$pubkey_pem" > "$tmp_pubkey"

  replaced_blocks="$(replace_managed_kong_public_keys "$tmp_pubkey")"
  rm -f "$tmp_pubkey"
  ok "Updated ${replaced_blocks} managed JWT key block(s) in kong.yml"

  log "3/5 Reloading Kong"
  reload_kong_config

  if [ "$SYNC_CLIENT_SECRETS" = "1" ]; then
    log "4/5 Syncing local client secrets from Keycloak"
    sync_client_secrets_file
  else
    warn "Skipping client secret sync (SYNC_CLIENT_SECRETS=${SYNC_CLIENT_SECRETS})"
  fi

  log "5/5 Running Kong/Keycloak verification"
  if [ -x "$ROOT_DIR/infras/kong/02_check_kong_keycloak.sh" ]; then
    if bash "$ROOT_DIR/infras/kong/02_check_kong_keycloak.sh"; then
      ok "Kong/Keycloak verification passed"
    else
      warn "Kong/Keycloak verification reported issues"
    fi
  else
    warn "Verification script not found: infras/kong/02_check_kong_keycloak.sh"
  fi

  echo
  ok "setup-auth completed"
}

main "$@"
