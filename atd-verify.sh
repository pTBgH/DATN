#!/usr/bin/env bash
# =============================================================================
# atd-verify.sh — Kiểm tra (read-only) luồng FE atd ↔ Keycloak ↔ Kong ↔ BE.
#
# Dùng SAU khi đã chạy atd-bringup.sh và Cloudflare Pages đã build xong.
# Không sửa gì, chỉ in PASS/FAIL từng tầng cụ thể.
#
# Chạy:
#   bash atd-verify.sh                          # auto-detect KONG_URL
#   KONG_URL=https://xxx.trycloudflare.com bash atd-verify.sh
#   TEST_USER=member2 bash atd-verify.sh
# =============================================================================
set -uo pipefail

REALM="${REALM:-job7189}"
CANDIDATE_CLIENT="${CANDIDATE_CLIENT:-candidate-app-dev}"
TEST_USER="${TEST_USER:-member1}"
TEST_PASSWORD="${TEST_PASSWORD:-dev1234}"
FE_ORIGIN="${FE_ORIGIN:-https://job7189-atd.pages.dev}"

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
FAILED=0

hdr "0) ENV"
info "FE_ORIGIN=$FE_ORIGIN  REALM=$REALM  CLIENT=$CANDIDATE_CLIENT  USER=$TEST_USER"
if [ -z "${KONG_URL:-}" ]; then
  KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null \
              | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)"
fi
KONG_URL="${KONG_URL%/}"
[ -z "$KONG_URL" ] && { fail "Không có KONG_URL"; exit 1; }
info "KONG_URL=$KONG_URL"

# ---------- 1) Kong reachability ----------
hdr "1) Kong reachability"
H=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$KONG_URL/api/health")
[ "$H" = "200" ] && pass "/api/health = 200" || fail "/api/health = $H"

# ---------- 2) FE Cloudflare Pages reachable ----------
hdr "2) FE Cloudflare Pages reachable"
F=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$FE_ORIGIN/login")
[ "$F" = "200" ] && pass "$FE_ORIGIN/login = 200" || fail "$FE_ORIGIN/login = $F (build chưa xong hoặc dự án sai)"

# Đọc HTML để xem biến NEXT_PUBLIC_* đã được "nướng" vào bundle chưa
HTML="$(curl -s --max-time 15 "$FE_ORIGIN/login")"
if echo "$HTML" | grep -q "$KONG_URL"; then
  pass "Bundle đã chứa KONG_URL — env build-time đã được apply"
else
  warn "Không thấy KONG_URL trong HTML /login (có thể nằm trong chunk JS — không đáng lo nếu mục 4 PASS)"
fi

# ---------- 3) Preflight OPTIONS (CORS) ----------
hdr "3) Preflight OPTIONS từ Origin: $FE_ORIGIN"
TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
for ep in "$TOKEN_EP" "$KONG_URL/api/candidates/profile"; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X OPTIONS "$ep" \
    -H "Origin: $FE_ORIGIN" \
    -H 'Access-Control-Request-Method: POST' \
    -H 'Access-Control-Request-Headers: content-type,authorization')
  if [ "$c" = "200" ] || [ "$c" = "204" ]; then pass "OPTIONS $ep = $c"
  else fail "OPTIONS $ep = $c (CORS preflight FAIL)"; fi
done

# ---------- 4) Password grant + decode token ----------
hdr "4) Password grant — $TEST_USER via $CANDIDATE_CLIENT"
RESP=$(curl -s -D /tmp/atd-v.$$ --max-time 20 -X POST "$TOKEN_EP" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H "Origin: $FE_ORIGIN" \
  -d grant_type=password \
  -d "client_id=$CANDIDATE_CLIENT" \
  -d "username=$TEST_USER" \
  -d "password=$TEST_PASSWORD" \
  -d scope=openid)
ACAO=$(grep -i '^access-control-allow-origin:' /tmp/atd-v.$$ 2>/dev/null | tr -d '\r' || true)
rm -f /tmp/atd-v.$$
TOK=$(printf '%s' "$RESP" | python3 -c 'import sys,json
try:print(json.load(sys.stdin).get("access_token",""))
except:print("")' 2>/dev/null || echo "")

if [ -z "$TOK" ]; then
  fail "Token endpoint không trả access_token. Body: $(printf '%s' "$RESP" | head -c 200)"
  exit 1
fi

read AZP ISS USERN ROLES < <(python3 - <<PY "$TOK"
import sys,base64,json
t=sys.argv[1]; p=t.split('.')[1]; p+='='*(-len(p)%4)
d=json.loads(base64.urlsafe_b64decode(p))
print(d.get('azp',''), d.get('iss',''), d.get('preferred_username',''),
      ','.join(d.get('realm_access',{}).get('roles',[])))
PY
)
pass "token len=${#TOK}  user=$USERN"
info "azp=$AZP  iss=$ISS  roles=$ROLES"
[ -n "$ACAO" ] && pass "ACAO header: $ACAO" || fail "Token endpoint không có ACAO (browser sẽ chặn)"
[ "$AZP" = "$CANDIDATE_CLIENT" ] && pass "azp == $CANDIDATE_CLIENT" \
                                 || fail "azp ($AZP) ≠ $CANDIDATE_CLIENT"

# ---------- 5) Protected route ----------
hdr "5) GET /api/candidates/profile với Bearer + Origin"
C=$(curl -s -o /tmp/atd-p.$$ -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer $TOK" \
  -H "Origin: $FE_ORIGIN" \
  "$KONG_URL/api/candidates/profile")
B=$(head -c 240 /tmp/atd-p.$$ 2>/dev/null || echo "")
rm -f /tmp/atd-p.$$
case "$C" in
  200|404) pass "/api/candidates/profile = $C  (token vào BE, OPA pass)";;
  401)     fail "401 — token chưa thông. body: $B";;
  403)     fail "403 — OPA chặn. body: $B";;
  *)       warn "$C — body: $B";;
esac

# ---------- 6) Một số API liên quan candidate (smoke) ----------
hdr "6) Smoke các API candidate khác"
for path in /api/resumes /api/jobs/saved /api/applications/my; do
  c=$(curl -s -o /tmp/atd-s.$$ -w '%{http_code}' --max-time 20 \
    -H "Authorization: Bearer $TOK" -H "Origin: $FE_ORIGIN" "$KONG_URL$path")
  b=$(head -c 140 /tmp/atd-s.$$ 2>/dev/null || echo "")
  rm -f /tmp/atd-s.$$
  case "$c" in
    200|404) pass "$path = $c";;
    401)     fail "$path = 401 — token chưa thông qua được BE; body: $b";;
    403)     warn "$path = 403 — OPA chặn (kiểm tra .rego); body: $b";;
    405)     warn "$path = 405 — route/method app chưa khớp; body: $b";;
    *)       warn "$path = $c — body: $b";;
  esac
done

# ---------- 7) Summary ----------
hdr "7) SUMMARY"
if [ "$FAILED" = "0" ]; then
  echo "  $(c_g "Tất cả tầng PASS.") Tiếp theo:"
  echo "    1) Mở $FE_ORIGIN/login → đăng nhập $TEST_USER / $TEST_PASSWORD"
  echo "    2) Mở DevTools → Network: xác nhận POST /realms/.../token = 200,"
  echo "       các GET /api/* gắn Authorization Bearer = 200/404 (không 401)."
else
  echo "  $(c_r "Có bước FAIL — xem chi tiết trên.")"
  cat <<EOF

  Hint nhanh theo lỗi thường gặp:
   · /login = HTTP 500   → CF Pages build crash (xem dashboard) HOẶC trang chủ
                            phụ thuộc /api/public/jobs (job-service đang 500).
                            Test thẳng /login để bỏ qua trang chủ.
   · ACAO trống          → Keycloak webOrigins không khớp Origin FE.
                            Chạy lại: bash atd-bringup.sh
   · azp ≠ candidate-app-dev → CF Pages env NEXT_PUBLIC_KEYCLOAK_CLIENT_ID sai
                                hoặc bundle build trước khi env được set.
                                Trigger lại deploy hook để build mới.
   · /api/candidates/profile = 401 'Unauthorized Client'
                          → azp trong token không khớp KEYCLOAK_CANDIDATE_CLIENT_ID
                             trong identity-service. Kiểm tra deployment env.
   · /api/candidates/profile = 403 OPA denied
                          → candidates.rego đang chặn role 'member'. Kiểm tra
                             configmap opa-policies ns security.
EOF
fi

exit $FAILED
