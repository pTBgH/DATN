#!/usr/bin/env bash
# fix-azp-keycloak.sh — Hướng 1: bật 2 client thành PUBLIC + Direct Access Grants
# để FE (atd/rct) login bằng đúng client_id của nó -> azp khớp -> backend nhận token.
# KHÔNG build lại image. Theo quy ước add-app-roles.sh (kcadm trong pod keycloak).
# Chạy trên baosrc. CHECK trước -> APPLY -> VERIFY.
set -uo pipefail

NAMESPACE="${KC_NAMESPACE:-security}"
REALM="${KC_REALM:-job7189}"
KC_POD_LABEL="${KC_POD_LABEL:-app=keycloak}"
KC_BASE_URL="${KC_BASE_URL:-http://localhost:8080}"
CLIENTS=(candidate-app-dev recruiter-app-dev)
KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"; KONG_URL="${KONG_URL%/}"
PASS="${TEST_USER_PASSWORD:-dev1234}"

KC_POD=$(kubectl -n "$NAMESPACE" get pod -l "$KC_POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[ -z "$KC_POD" ] && { echo "ERROR: không thấy pod keycloak ($KC_POD_LABEL) trong ns $NAMESPACE"; exit 1; }
echo "keycloak pod = $NAMESPACE/$KC_POD"
echo "KONG_URL     = $KONG_URL"

if [ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ]; then
  KEYCLOAK_ADMIN_PASSWORD=$(kubectl -n "$NAMESPACE" get secret app-secrets -o jsonpath='{.data.keycloak-admin-password}' 2>/dev/null | base64 -d || true)
fi
[ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ] && { echo "ERROR: không đọc được admin pass (secret app-secrets key keycloak-admin-password). Chạy lại với KEYCLOAK_ADMIN_PASSWORD=... bash $0"; exit 1; }

kc(){ kubectl -n "$NAMESPACE" exec -i "$KC_POD" -- /opt/keycloak/bin/kcadm.sh "$@"; }
cid(){ kc get clients -r "$REALM" -q clientId="$1" --fields id 2>/dev/null | python3 -c 'import sys,json;a=json.load(sys.stdin);print(a[0]["id"] if a else "")'; }

echo; echo "== login kcadm (admin@master) =="
kc config credentials --server "$KC_BASE_URL" --realm master --user admin --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null && echo "  OK" || { echo "  login FAIL"; exit 1; }

echo; echo "════════ CHECK (cấu hình client TRƯỚC khi sửa) ════════"
declare -A ID
for C in "${CLIENTS[@]}"; do
  ID[$C]="$(cid "$C")"
  echo "--- $C  (id=${ID[$C]:-KHÔNG THẤY}) ---"
  [ -z "${ID[$C]}" ] && { echo "   !! client không tồn tại trong realm $REALM"; continue; }
  kc get "clients/${ID[$C]}" -r "$REALM" --fields clientId,publicClient,directAccessGrantsEnabled,serviceAccountsEnabled,standardFlowEnabled
done

echo; echo "════════ APPLY (publicClient=true, directAccessGrants=on, serviceAccounts=off) ════════"
for C in "${CLIENTS[@]}"; do
  [ -z "${ID[$C]:-}" ] && { echo "  bỏ qua $C (không có id)"; continue; }
  kc update "clients/${ID[$C]}" -r "$REALM" \
    -s publicClient=true \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=false \
    && echo "  $C: updated" || echo "  $C: update FAIL"
  kc get "clients/${ID[$C]}" -r "$REALM" --fields clientId,publicClient,directAccessGrantsEnabled,serviceAccountsEnabled
done

echo; echo "════════ VERIFY (qua Kong: token theo đúng client + soi azp + route protected) ════════"
gt(){ curl -s --max-time 20 -X POST "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASS"; }
azp(){ python3 -c 'import sys,json,base64;
t=json.load(sys.stdin).get("access_token","")
p=t.split(".")[1] if t else ""
p+="="*(-len(p)%4)
d=json.loads(base64.urlsafe_b64decode(p)) if p else {}
print("len=%d azp=%s roles=%s"%(len(t),d.get("azp"),",".join(d.get("realm_access",{}).get("roles",[]))))' ; }
hb(){ curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H "Authorization: Bearer $2" "$KONG_URL$1"; }

run(){ local client="$1" user="$2" route="$3"; local j t;
  j="$(gt "$client" "$user")"; t="$(printf '%s' "$j" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)"
  echo "--- $user via $client ---"
  if [ -z "$t" ]; then echo "   token FAIL: $(printf '%s' "$j" | head -c 160)"; else
    printf '   '; printf '%s' "$j" | azp
    echo "   $route : $(hb "$route" "$t")"
  fi; }

run recruiter-app-dev recruiter1 /api/recruiters/profile
run candidate-app-dev member1    /api/candidates/profile

echo
echo ">> Mong đợi: token len>0; azp = đúng client (candidate-app-dev / recruiter-app-dev);"
echo "   /api/recruiters/profile & /api/candidates/profile HẾT 401 'Unauthorized Client'"
echo "   (200 nếu có data, hoặc 404/500 tầng app — nhưng KHÔNG còn 401 azp)."
