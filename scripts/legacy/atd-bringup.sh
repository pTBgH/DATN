#!/usr/bin/env bash
# =============================================================================
# atd-bringup.sh — Bật-luồng-thật cho FE atd (candidate) ↔ BE qua Keycloak.
#
# Script này TỰ-CHỨA: chỉ cần kubectl + curl + python3 + jq, đọc Cloudflare token
# từ $CF_DIR (mặc định /home/ptb/.config/cloudflare/token), KHÔNG sửa repo, KHÔNG
# build lại image. Mục tiêu: sau khi chạy xong, FE https://job7189-atd.pages.dev
# có thể login bằng member1/dev1234 và gọi /api/candidates/profile = 200.
#
# Chạy:
#   bash atd-bringup.sh                       # auto-detect KONG_URL từ journal
#   KONG_URL=https://xxx.trycloudflare.com bash atd-bringup.sh
#   SKIP_PAGES=1 bash atd-bringup.sh          # chỉ fix Keycloak + test, không đụng CF Pages
#   DRY_RUN=1 bash atd-bringup.sh             # in các bước nhưng không sửa gì
#
# Sau khi script chạy xong:
#   - Mục 3,4 phải xanh (PASS): token OK + /api/candidates/profile = 200
#   - Mục 6 sẽ trigger CF Pages rebuild ~2-4 phút; sau khi build xong, test browser
#     mở https://job7189-atd.pages.dev/login -> đăng nhập member1/dev1234
# =============================================================================
set -uo pipefail

# ---------------------------- Config ---------------------------------------
REALM="${REALM:-job7189}"
CANDIDATE_CLIENT="${CANDIDATE_CLIENT:-candidate-app}"
TEST_USER="${TEST_USER:-member1}"
TEST_PASSWORD="${TEST_PASSWORD:-dev1234}"
FE_ORIGIN="${FE_ORIGIN:-https://job7189-atd.pages.dev}"

KC_NAMESPACE="${KC_NAMESPACE:-security}"
KC_POD_LABEL="${KC_POD_LABEL:-app=keycloak}"
KC_BASE_URL_IN_POD="${KC_BASE_URL_IN_POD:-http://localhost:8080}"

CF_DIR="${CF_DIR:-/home/ptb/.config/cloudflare}"
CF_ACC="${CF_ACCOUNT_ID:-98601df846b714b6b64c29d2f199a854}"
CF_PAGES_PROJECT="${CF_PAGES_PROJECT:-job7189-atd}"
CF_API="https://api.cloudflare.com/client/v4"

DRY_RUN="${DRY_RUN:-0}"
SKIP_PAGES="${SKIP_PAGES:-0}"

# ---------------------------- Colors / helpers -----------------------------
c_g(){ printf '\033[32m%s\033[0m' "$1"; }
c_r(){ printf '\033[31m%s\033[0m' "$1"; }
c_y(){ printf '\033[33m%s\033[0m' "$1"; }
c_b(){ printf '\033[1;34m%s\033[0m' "$1"; }
line(){ printf '%.0s─' {1..78}; echo; }
hdr(){ echo; line; echo "  $(c_b "$1")"; line; }
pass(){ echo "  $(c_g "PASS") $1"; }
fail(){ echo "  $(c_r "FAIL") $1"; FAILED=1; }
warn(){ echo "  $(c_y "WARN") $1"; }
info(){ echo "  · $1"; }
need(){ command -v "$1" >/dev/null || { echo "Thiếu $1"; exit 1; }; }
FAILED=0

# ---------------------------- 0) ENV ---------------------------------------
hdr "0) ENV"
need kubectl; need curl; need python3; need jq
info "host=$(hostname)  date=$(date -u +'%F %T %Z')"
info "REALM=$REALM  CANDIDATE_CLIENT=$CANDIDATE_CLIENT  TEST_USER=$TEST_USER"
info "FE_ORIGIN=$FE_ORIGIN  CF_PAGES_PROJECT=$CF_PAGES_PROJECT"
info "DRY_RUN=$DRY_RUN  SKIP_PAGES=$SKIP_PAGES"

# ---------------------------- 1) KONG_URL ----------------------------------
hdr "1) KONG_URL"
if [ -z "${KONG_URL:-}" ]; then
  KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null \
              | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)"
fi
KONG_URL="${KONG_URL%/}"
if [ -z "$KONG_URL" ]; then
  fail "Không tìm thấy KONG_URL (journal cloudflared-kong trống). Pass KONG_URL=... rồi chạy lại."
  exit 1
fi
info "KONG_URL = $KONG_URL"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$KONG_URL/api/health" || true)
[ "$code" = "200" ] && pass "Kong /api/health = 200" || fail "Kong /api/health = $code (Kong/tunnel không sẵn sàng)"

# ---------------------------- 2) KEYCLOAK CLIENT (CHECK + FIX) -------------
hdr "2) KEYCLOAK CLIENT ($CANDIDATE_CLIENT) — CHECK + FIX"
KC_POD=$(kubectl -n "$KC_NAMESPACE" get pod -l "$KC_POD_LABEL" \
         -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[ -z "$KC_POD" ] && { fail "Không thấy pod keycloak ($KC_POD_LABEL) trong ns $KC_NAMESPACE"; exit 1; }
info "keycloak pod = $KC_NAMESPACE/$KC_POD"

if [ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ]; then
  KEYCLOAK_ADMIN_PASSWORD="$(kubectl -n "$KC_NAMESPACE" get secret app-secrets \
    -o jsonpath='{.data.keycloak-admin-password}' 2>/dev/null | base64 -d || true)"
fi
[ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ] && { fail "Không đọc được KEYCLOAK_ADMIN_PASSWORD (secret app-secrets). Set var rồi chạy lại."; exit 1; }

kc(){ kubectl -n "$KC_NAMESPACE" exec -i "$KC_POD" -- /opt/keycloak/bin/kcadm.sh "$@"; }

# login (không in mật khẩu)
kc config credentials --server "$KC_BASE_URL_IN_POD" --realm master \
   --user admin --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null \
   && pass "kcadm login (admin@master) OK" \
   || { fail "kcadm login FAIL"; exit 1; }

CID="$(kc get clients -r "$REALM" -q "clientId=$CANDIDATE_CLIENT" --fields id 2>/dev/null \
       | python3 -c 'import sys,json;a=json.load(sys.stdin);print(a[0]["id"] if a else "")' || true)"
if [ -z "$CID" ]; then
  fail "Client $CANDIDATE_CLIENT KHÔNG tồn tại trong realm $REALM. Tạo trước bằng setup-keycloak-clients-job7189.sh."
  exit 1
fi
info "client id = $CID"

echo "  ── trạng thái TRƯỚC ──"
kc get "clients/$CID" -r "$REALM" --fields \
  clientId,publicClient,directAccessGrantsEnabled,serviceAccountsEnabled,standardFlowEnabled,redirectUris,webOrigins \
  2>/dev/null | sed 's/^/    /'

if [ "$DRY_RUN" = "1" ]; then
  warn "DRY_RUN=1 → bỏ qua APPLY"
else
  echo "  ── APPLY (public + direct-access + webOrigins/redirectUris cho FE) ──"
  WEB_ORIGINS_JSON="[\"$FE_ORIGIN\",\"+\"]"
  REDIRECT_URIS_JSON="[\"$FE_ORIGIN/*\",\"https://*.${CF_PAGES_PROJECT}.pages.dev/*\",\"http://localhost:3002/*\"]"
  kc update "clients/$CID" -r "$REALM" \
    -s publicClient=true \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=false \
    -s standardFlowEnabled=true \
    -s "webOrigins=$WEB_ORIGINS_JSON" \
    -s "redirectUris=$REDIRECT_URIS_JSON" \
    && pass "client updated" || fail "client update FAIL"

  echo "  ── trạng thái SAU ──"
  kc get "clients/$CID" -r "$REALM" --fields \
    clientId,publicClient,directAccessGrantsEnabled,serviceAccountsEnabled,standardFlowEnabled,redirectUris,webOrigins \
    2>/dev/null | sed 's/^/    /'
fi

# ---------------------------- 3) PASSWORD GRANT (CORS-aware) ---------------
hdr "3) PASSWORD GRANT ($TEST_USER via $CANDIDATE_CLIENT, Origin: $FE_ORIGIN)"
TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"

# preflight OPTIONS
PREFLIGHT_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -X OPTIONS "$TOKEN_EP" \
  -H "Origin: $FE_ORIGIN" \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type')
[ "$PREFLIGHT_CODE" = "200" ] || [ "$PREFLIGHT_CODE" = "204" ] \
  && pass "preflight OPTIONS = $PREFLIGHT_CODE" \
  || fail "preflight OPTIONS = $PREFLIGHT_CODE (cần 200/204)"

# token + ACAO header
RESP=$(curl -s -D /tmp/atd-h.$$ --max-time 20 -X POST "$TOKEN_EP" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H "Origin: $FE_ORIGIN" \
  -d grant_type=password \
  -d "client_id=$CANDIDATE_CLIENT" \
  -d "username=$TEST_USER" \
  -d "password=$TEST_PASSWORD" \
  -d scope=openid)
ACAO=$(grep -i '^access-control-allow-origin:' /tmp/atd-h.$$ 2>/dev/null | tr -d '\r' || true)
rm -f /tmp/atd-h.$$

ACCESS_TOKEN=$(printf '%s' "$RESP" | python3 -c 'import sys,json
try:print(json.load(sys.stdin).get("access_token",""))
except:print("")' 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  fail "Không lấy được access_token. Response: $(printf '%s' "$RESP" | head -c 200)"
  exit 1
fi

# decode
read AZP ISS USERN ROLES < <(python3 - <<PY "$ACCESS_TOKEN"
import sys, base64, json
t=sys.argv[1]; p=t.split('.')[1]; p+='='*(-len(p)%4)
d=json.loads(base64.urlsafe_b64decode(p))
print(d.get('azp',''), d.get('iss',''), d.get('preferred_username',''),
      ','.join(d.get('realm_access',{}).get('roles',[])))
PY
)

pass "token len=${#ACCESS_TOKEN}  azp=$AZP  user=$USERN"
info "iss   = $ISS"
info "roles = $ROLES"
[ -n "$ACAO" ] && pass "ACAO header có: $ACAO" || fail "Token endpoint KHÔNG có Access-Control-Allow-Origin (browser sẽ chặn)"

[ "$AZP" = "$CANDIDATE_CLIENT" ] && pass "azp == $CANDIDATE_CLIENT (identity-service sẽ phân loại đúng candidate)" \
                                 || fail "azp ($AZP) ≠ $CANDIDATE_CLIENT — sẽ ra 401 'Unauthorized Client'"

# ---------------------------- 4) PROTECTED ROUTE ---------------------------
hdr "4) PROTECTED ROUTE — GET /api/candidates/profile"
PROF_CODE=$(curl -s -o /tmp/atd-prof.$$ -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Origin: $FE_ORIGIN" \
  "$KONG_URL/api/candidates/profile")
PROF_BODY=$(head -c 240 /tmp/atd-prof.$$ 2>/dev/null || echo "")
rm -f /tmp/atd-prof.$$

if [ "$PROF_CODE" = "200" ] || [ "$PROF_CODE" = "404" ]; then
  pass "/api/candidates/profile = $PROF_CODE (200 hoặc 404 đều OK: token vào BE, OPA cho qua, candidate đã/chưa có profile)"
elif [ "$PROF_CODE" = "401" ]; then
  fail "401 — token chưa thông. body: $PROF_BODY"
elif [ "$PROF_CODE" = "403" ]; then
  fail "403 — OPA chặn. body: $PROF_BODY"
else
  warn "$PROF_CODE — body: $PROF_BODY"
fi

# ---------------------------- 5) CF PAGES ENV ------------------------------
hdr "5) CF PAGES env_vars ($CF_PAGES_PROJECT)"
if [ "$SKIP_PAGES" = "1" ]; then
  warn "SKIP_PAGES=1 → bỏ qua CF Pages"
else
  CF_TOKEN_FILE="$CF_DIR/token"
  if [ ! -r "$CF_TOKEN_FILE" ]; then
    fail "Không đọc được $CF_TOKEN_FILE — set CF_DIR hoặc tạo file token."
  else
    CF_TOKEN="$(cat "$CF_TOKEN_FILE")"
    EV=$(python3 - <<PY "$KONG_URL" "$REALM" "$CANDIDATE_CLIENT"
import json,sys
k,r,c=sys.argv[1],sys.argv[2],sys.argv[3]
print(json.dumps({
  "NEXT_PUBLIC_USE_MOCK":{"type":"plain_text","value":"false"},
  "NEXT_PUBLIC_API_BASE_URL":{"type":"plain_text","value":k},
  "NEXT_PUBLIC_KEYCLOAK_URL":{"type":"plain_text","value":k},
  "NEXT_PUBLIC_KEYCLOAK_REALM":{"type":"plain_text","value":r},
  "NEXT_PUBLIC_KEYCLOAK_CLIENT_ID":{"type":"plain_text","value":c},
}))
PY
)
    if [ "$DRY_RUN" = "1" ]; then
      warn "DRY_RUN=1 → in body nhưng không PATCH"
      printf '  payload: %s\n' "$EV" | head -c 200; echo
    else
      RESP=$(curl -s -X PATCH \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        "$CF_API/accounts/$CF_ACC/pages/projects/$CF_PAGES_PROJECT" \
        --data "{\"deployment_configs\":{\"production\":{\"env_vars\":$EV},\"preview\":{\"env_vars\":$EV}}}")
      OK=$(printf '%s' "$RESP" | python3 -c 'import sys,json
try:d=json.load(sys.stdin);print("yes" if d.get("success") else d.get("errors"))
except:print("parse-error")')
      [ "$OK" = "yes" ] && pass "PATCH env_vars OK ($CF_PAGES_PROJECT)" \
                       || fail "PATCH env_vars FAIL: $OK"
    fi
  fi
fi

# ---------------------------- 6) TRIGGER REBUILD ---------------------------
hdr "6) CF PAGES REBUILD (deploy hook)"
if [ "$SKIP_PAGES" = "1" ]; then
  warn "SKIP_PAGES=1 → bỏ qua trigger build"
else
  HOOK_FILE="$CF_DIR/deploy_hook_atd"
  if [ ! -r "$HOOK_FILE" ]; then
    fail "Không đọc được $HOOK_FILE — không thể trigger rebuild. Bạn có thể vào Cloudflare dashboard → Pages → $CF_PAGES_PROJECT → Retry deployment."
  else
    HOOK="$(cat "$HOOK_FILE")"
    if [ "$DRY_RUN" = "1" ]; then
      warn "DRY_RUN=1 → bỏ qua POST hook"
    else
      RESP=$(curl -s -X POST "$HOOK")
      ID=$(printf '%s' "$RESP" | python3 -c 'import sys,json
try:print(json.load(sys.stdin).get("result",{}).get("id",""))
except:print("")')
      [ -n "$ID" ] && pass "rebuild triggered (deploy id=$ID)" || warn "hook posted (response: $(printf '%s' "$RESP" | head -c 120))"
    fi
  fi
fi

# ---------------------------- 7) SUMMARY ----------------------------------
hdr "7) NEXT STEPS"
if [ "$FAILED" = "0" ]; then
  echo "  $(c_g "Tất cả bước cốt lõi PASS.")"
else
  echo "  $(c_r "Có bước FAIL ở trên — xem lại trước khi test browser.")"
fi
cat <<EOF
  · CF Pages build mất ~2-4 phút. Theo dõi: https://dash.cloudflare.com/$CF_ACC/pages/view/$CF_PAGES_PROJECT
  · Sau khi build xong (status=success), mở:
      $FE_ORIGIN/login
    → đăng nhập: username=$TEST_USER  password=$TEST_PASSWORD
    → kỳ vọng: chuyển về /applications, các API gọi qua $KONG_URL không bị 401.
  · Verify lại bất kỳ lúc nào (không build lại):
      bash scripts/diagnostics/atd-verify.sh
  · Nếu trang chủ ('/') vẫn HTTP 500 sau khi build xong: đó là vì /api/public/jobs (job-service) đang 500
    — KHÔNG liên quan đăng nhập. Mở thẳng /login để test luồng auth.

EOF

[ "$FAILED" = "0" ] && exit 0 || exit 1
