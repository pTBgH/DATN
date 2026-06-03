#!/usr/bin/env bash
# Diagnose Kong JWT error: {"message":"No credentials found for given 'iss'"}
#
# Root cause this error always means: token's `iss` claim does NOT match the
# `key` field of any Kong jwt_secret (in DB-less kong.yml, under consumers.[].jwt_secrets[].key).
#
# Run from baosrc. Output is grouped so easy to paste back.

set -uo pipefail

log()   { echo -e "\n=== $1 ==="; }
PORT_FORWARD_PID=""
cleanup() { [[ -n "$PORT_FORWARD_PID" ]] && kill "$PORT_FORWARD_PID" 2>/dev/null || true; }
trap cleanup EXIT

# ---- 0. Find Kong + Keycloak ----
log "0. Locate Kong + Keycloak"
KONG_NS=$(kubectl get pods -A -l app=kong -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null \
       || kubectl get pods -A -l app.kubernetes.io/name=kong -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null \
       || kubectl get pods -A 2>/dev/null | awk '/kong/ {print $1; exit}')
KONG_POD=$(kubectl -n "$KONG_NS" get pods 2>/dev/null | awk '/kong/ && /Running/ {print $1; exit}')
echo "Kong: ns=$KONG_NS  pod=$KONG_POD"
KC_NS=security
KC_POD=$(kubectl -n "$KC_NS" get pods -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "Keycloak: ns=$KC_NS  pod=$KC_POD"

# ---- 1. Recent Kong errors (the SMOKING GUN: which iss is the token using) ----
log "1. Kong recent JWT/iss errors (last ~200 lines)"
kubectl -n "$KONG_NS" logs "$KONG_POD" --tail=300 2>/dev/null \
  | grep -iE 'iss|jwt|credential|"401"|"403"|unauth' | tail -40 \
  || echo "(no matches — try increasing --tail or doing a fresh FE login attempt then re-run)"

# ---- 2. Decode iss/aud/azp from Kong access log of failing request ----
log "2. Tail Kong access log (live) — DO a fresh login from FE now, then Ctrl+C"
echo "Skipping live tail in script. To capture: in another terminal run:"
echo "  kubectl -n $KONG_NS logs -f $KONG_POD | grep -iE 'iss|jwt|401'"

# ---- 3. Kong DB-less config: list all jwt_secrets ----
log "3. Kong consumers + jwt_secrets (from ConfigMap kong.yml)"
# DB-less Kong reads /etc/kong/kong.yml from a ConfigMap; find that ConfigMap
KONG_CM=$(kubectl -n "$KONG_NS" get cm -o name 2>/dev/null \
  | xargs -I{} sh -c "kubectl -n $KONG_NS get {} -o json | jq -e '.data | to_entries[] | select(.value | contains(\"jwt_secrets\") or contains(\"_format_version\"))' >/dev/null 2>&1 && echo {}" \
  | head -1)
echo "ConfigMap: $KONG_CM"
if [[ -n "$KONG_CM" ]]; then
  kubectl -n "$KONG_NS" get "$KONG_CM" -o jsonpath='{.data.kong\.yml}' 2>/dev/null \
    | yq -r '.consumers[]? | {username, jwt_secrets: (.jwt_secrets // [] | map({algorithm, key}))}' 2>/dev/null \
    || kubectl -n "$KONG_NS" get "$KONG_CM" -o jsonpath='{.data.kong\.yml}' 2>/dev/null \
      | grep -E '^  - username:|^    - algorithm:|^      key:' | head -40
fi

# ---- 4. Keycloak: list ALL realms + their iss URLs (most important) ----
log "4. Keycloak — iss URL of every realm"
ss -lntp 2>/dev/null | grep -q ':8080 ' || {
  kubectl -n "$KC_NS" port-forward svc/keycloak 8080:8080 >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
  sleep 3
}

KC_ADMIN_PASS=$(kubectl -n "$KC_NS" get secret app-secrets -o jsonpath='{.data.keycloak-admin-password}' | base64 -d)
ADMIN_TOK=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -d client_id=admin-cli -d username=admin -d "password=$KC_ADMIN_PASS" -d grant_type=password \
  | jq -r .access_token)

if [[ -z "$ADMIN_TOK" || "$ADMIN_TOK" == "null" ]]; then
  echo "Failed to get admin token"
else
  REALMS=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" http://localhost:8080/admin/realms | jq -r '.[].realm')
  for r in $REALMS; do
    iss=$(curl -s -H "Host: auth.job7189.local" "http://localhost:8080/realms/$r/.well-known/openid-configuration" | jq -r '.issuer')
    iss_no_host=$(curl -s "http://localhost:8080/realms/$r/.well-known/openid-configuration" | jq -r '.issuer')
    printf "  %-25s iss(Host header) = %s\n" "$r" "$iss"
    printf "  %-25s iss(direct)      = %s\n" "" "$iss_no_host"
  done
fi

# ---- 5. Get a sample FE token + decode (replace user/pass if FE uses different realm) ----
log "5. Sample token from FE realm — EDIT script with FE realm + client + user"
echo "Edit these variables in the script then re-run section 5 only:"
echo "  FE_REALM=...   # e.g. 7189_business"
echo "  FE_CLIENT=...  # e.g. atd-frontend"
echo "  FE_USER=...    # e.g. test_user"
echo "  FE_PASS=..."
# Example (uncomment + edit):
# FE_REALM=7189_business
# FE_CLIENT=atd-frontend
# FE_CLIENT_SECRET=...   # optional if public client
# FE_USER=test_user
# FE_PASS=test_pass
# RESP=$(curl -s -X POST "http://localhost:8080/realms/$FE_REALM/protocol/openid-connect/token" \
#   -d grant_type=password -d client_id="$FE_CLIENT" \
#   ${FE_CLIENT_SECRET:+-d client_secret=$FE_CLIENT_SECRET} \
#   -d username="$FE_USER" -d password="$FE_PASS" -d 'scope=openid')
# echo "$RESP" | jq -r .access_token | cut -d. -f2 | base64 -d 2>/dev/null | jq '{iss, aud, azp}'

# ---- 6. Compare: token iss vs Kong jwt_secrets keys ----
log "6. Manual comparison checklist"
cat <<EOF
The error 'No credentials found for given iss' means:
  token.iss  !=  any consumers[].jwt_secrets[].key  in Kong config.

What changed recently: setting KC_HOSTNAME_URL=http://auth.job7189.local made
Keycloak issue 'iss' as 'http://auth.job7189.local/realms/<realm>' for ALL realms
(not just 7189_internal). If Kong jwt_secrets were registered with OLD iss
(e.g. http://localhost:8080/... or http://keycloak.security.svc.cluster.local:8080/...)
those credentials are now stale.

To fix:
  1. From section 4 above, note the new iss for the FE realm.
  2. From section 3 above, note the keys in jwt_secrets.
  3. Update the kong.yml ConfigMap so the key matches the new iss EXACTLY (incl. http vs https, trailing slash, etc.).
  4. Reload Kong:
       kubectl -n $KONG_NS rollout restart deploy/<kong-deploy>
EOF
