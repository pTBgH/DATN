#!/usr/bin/env bash
# =============================================================================
# atd-fix-identity-jwt.sh — Chẩn đoán + sửa /api/candidates/profile 401 "Unauthorized"
# (catch-all exception trong identity-service VerifyKeycloakToken).
#
# Nguyên nhân hay gặp:
#   (A) Cache JWKS cũ trong Redis của identity-service: Keycloak rotate signing key
#       nhưng identity-service vẫn dùng JWKS đã cache 1h trước -> kid không khớp ->
#       JWT::decode throw -> catch-all trả 401 "Unauthorized".
#   (B) Identity-service không gọi được http://keycloak.security.svc.cluster.local:8080
#       (Cilium L4 policy chặn) -> Cache::remember nhận về [] -> parseKeySet ném.
#   (C) Token quá ngắn (exp đã qua) — ít khả năng vì test ngay sau khi cấp.
#
# Script làm: tìm pod, dump log lỗi gần nhất, test JWKS từ trong pod,
# so kid token vs kid JWKS, clear Redis cache jwks_identity, retest.
#
# Chạy:
#   bash atd-fix-identity-jwt.sh
#   KONG_URL=https://xxx.trycloudflare.com bash atd-fix-identity-jwt.sh
# =============================================================================
set -uo pipefail

REALM="${REALM:-job7189}"
CANDIDATE_CLIENT="${CANDIDATE_CLIENT:-candidate-app}"
TEST_USER="${TEST_USER:-member1}"
TEST_PASSWORD="${TEST_PASSWORD:-dev1234}"
FE_ORIGIN="${FE_ORIGIN:-https://job7189-atd.pages.dev}"

APP_NS="${APP_NS:-job7189-apps}"
IDENT_LABEL="${IDENT_LABEL:-app=identity-service}"
REDIS_LABEL="${REDIS_LABEL:-app=identity-service-redis}"
KC_INTERNAL_URL="${KC_INTERNAL_URL:-http://keycloak.security.svc.cluster.local:8080}"

c_g(){ printf '\033[32m%s\033[0m' "$1"; }
c_r(){ printf '\033[31m%s\033[0m' "$1"; }
c_y(){ printf '\033[33m%s\033[0m' "$1"; }
c_b(){ printf '\033[1;34m%s\033[0m' "$1"; }
line(){ printf '%.0s─' {1..78}; echo; }
hdr(){ echo; line; echo "  $(c_b "$1")"; line; }
pass(){ echo "  $(c_g "PASS") $1"; }
fail(){ echo "  $(c_r "FAIL") $1"; }
warn(){ echo "  $(c_y "WARN") $1"; }
info(){ echo "  · $1"; }

# ---------------------------- 0) ENV --------------------------------------
hdr "0) ENV + tìm pod"
if [ -z "${KONG_URL:-}" ]; then
  KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null \
              | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)"
fi
KONG_URL="${KONG_URL%/}"
[ -z "$KONG_URL" ] && { fail "Không có KONG_URL"; exit 1; }
info "KONG_URL=$KONG_URL"

IDENT_POD=$(kubectl -n "$APP_NS" get pod -l "$IDENT_LABEL" \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null \
  | tr ' ' '\n' | head -1)
[ -z "$IDENT_POD" ] && { fail "Không thấy pod identity-service ($IDENT_LABEL) ns $APP_NS"; exit 1; }
info "identity-service pod = $APP_NS/$IDENT_POD"

REDIS_POD=$(kubectl -n "$APP_NS" get pod -l "$REDIS_LABEL" \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null \
  | tr ' ' '\n' | head -1)
[ -z "$REDIS_POD" ] && warn "Không thấy pod identity-service-redis (sẽ clear cache qua php artisan thay thế)"
[ -n "$REDIS_POD" ] && info "redis pod = $APP_NS/$REDIS_POD"

# ---------------------------- 1) Lấy token hiện tại -----------------------
hdr "1) Lấy token mới (member1 via candidate-app-dev)"
TOK_JSON=$(curl -s --max-time 20 -X POST \
  "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H "Origin: $FE_ORIGIN" \
  -d grant_type=password \
  -d "client_id=$CANDIDATE_CLIENT" \
  -d "username=$TEST_USER" \
  -d "password=$TEST_PASSWORD" \
  -d scope=openid)
TOK=$(printf '%s' "$TOK_JSON" | python3 -c 'import sys,json
try:print(json.load(sys.stdin).get("access_token",""))
except:print("")')
[ -z "$TOK" ] && { fail "Không lấy được token. Body: $(printf '%s' "$TOK_JSON" | head -c 200)"; exit 1; }

read TOK_KID TOK_AZP TOK_ISS TOK_EXP < <(python3 - <<PY "$TOK"
import sys, base64, json, time
t=sys.argv[1]; parts=t.split('.')
def b64u(s):
    s+='='*(-len(s)%4); return json.loads(base64.urlsafe_b64decode(s))
h=b64u(parts[0]); p=b64u(parts[1])
print(h.get('kid',''), p.get('azp',''), p.get('iss',''), p.get('exp',0))
PY
)
NOW=$(date +%s)
info "token kid = $TOK_KID"
info "token azp = $TOK_AZP"
info "token iss = $TOK_ISS"
info "token exp = $TOK_EXP (còn $(( TOK_EXP - NOW )) giây)"
[ $(( TOK_EXP - NOW )) -lt 60 ] && warn "Token gần hết hạn — chạy lại script ngay sau khi clear cache."

# ---------------------------- 2) Log identity-service ----------------------
hdr "2) Log identity-service (50 dòng cuối có 'Identity Auth Failed' / 'Unauthorized')"
LOGS=$(kubectl -n "$APP_NS" logs "$IDENT_POD" -c app --tail=500 2>/dev/null || true)
LASTLOG=$(printf '%s' "$LOGS" | grep -E 'Identity Auth Failed|Auth Failed|Unable to fetch|JWK|Signature|kid|Expired|InvalidArgument|UnexpectedValue' | tail -10)
if [ -n "$LASTLOG" ]; then
  echo "$LASTLOG" | sed 's/^/    /'
else
  warn "Không thấy log lỗi auth trong 500 dòng cuối. Có thể request 401 hôm trước đã rotate khỏi tail."
  info "Đang gọi /api/candidates/profile để tạo log mới..."
  kubectl -n "$APP_NS" exec "$IDENT_POD" -c app -- curl -s -o /dev/null -w '  in-pod call -> %{http_code}\n' \
    -H "Authorization: Bearer $TOK" "http://identity-service.${APP_NS}.svc.cluster.local/api/candidates/profile" || true
  # ngoài cluster (đi qua Kong) cho chắc chắn middleware bắt
  curl -s -o /dev/null -w '  via-kong call -> %{http_code}\n' \
    -H "Authorization: Bearer $TOK" -H "Origin: $FE_ORIGIN" "$KONG_URL/api/candidates/profile"
  sleep 1
  LASTLOG=$(kubectl -n "$APP_NS" logs "$IDENT_POD" -c app --tail=80 2>/dev/null \
    | grep -E 'Identity Auth Failed|Auth Failed|Unable to fetch|JWK|Signature|kid|Expired|InvalidArgument|UnexpectedValue' | tail -10)
  if [ -n "$LASTLOG" ]; then
    echo "$LASTLOG" | sed 's/^/    /'
  else
    warn "Vẫn không thấy log lỗi. Log Laravel có thể đang chỉ ghi stderr — show toàn bộ 80 dòng cuối để bạn nhìn:"
    kubectl -n "$APP_NS" logs "$IDENT_POD" -c app --tail=80 2>/dev/null | tail -40 | sed 's/^/    /'
  fi
fi

# ---------------------------- 3) JWKS reachability ------------------------
hdr "3) JWKS từ trong pod identity-service"
JWKS=$(kubectl -n "$APP_NS" exec "$IDENT_POD" -c app -- \
  curl -s --max-time 8 "${KC_INTERNAL_URL}/realms/${REALM}/protocol/openid-connect/certs" 2>/dev/null || true)
if [ -z "$JWKS" ] || ! printf '%s' "$JWKS" | python3 -c 'import sys,json;json.load(sys.stdin)' 2>/dev/null; then
  fail "Identity-service KHÔNG fetch được JWKS từ $KC_INTERNAL_URL"
  info "  -> nguyên nhân (B): Cilium policy chặn identity-service -> security/keycloak:8080,"
  info "     hoặc Keycloak chưa lắng nghe. Kiểm tra:"
  info "     kubectl -n security get svc keycloak -o jsonpath='{.spec.ports}'"
  info "     kubectl -n $APP_NS exec $IDENT_POD -c app -- curl -v --max-time 5 $KC_INTERNAL_URL/realms/$REALM"
else
  KIDS=$(printf '%s' "$JWKS" | python3 -c 'import sys,json
d=json.load(sys.stdin)
print(",".join([k.get("kid","") for k in d.get("keys",[])]))')
  pass "JWKS fetch OK — kids: $KIDS"
  if printf ",%s," "$KIDS" | grep -q ",$TOK_KID,"; then
    pass "kid của token ($TOK_KID) CÓ trong JWKS hiện tại"
  else
    fail "kid token ($TOK_KID) KHÔNG có trong JWKS đang phục vụ — nhưng cache cũ có thể vẫn có"
  fi
fi

# ---------------------------- 4) Redis cache content ----------------------
hdr "4) Cache Redis 'jwks_identity' (xem có cũ không)"
REDIS_CONT=""
if [ -n "$REDIS_POD" ]; then
  REDIS_CONT=$(kubectl -n "$APP_NS" get pod "$REDIS_POD" -o jsonpath='{.spec.containers[0].name}' 2>/dev/null || echo "")
  # tìm key trong redis: laravel cache có thể prefix 'laravel_database_' hoặc tương tự.
  KEYS=$(kubectl -n "$APP_NS" exec "$REDIS_POD" -c "$REDIS_CONT" -- \
    redis-cli --scan --pattern '*jwks_identity*' 2>/dev/null | tr -d '\r')
  if [ -n "$KEYS" ]; then
    info "keys khớp:"
    echo "$KEYS" | sed 's/^/      /'
    for K in $KEYS; do
      VAL=$(kubectl -n "$APP_NS" exec "$REDIS_POD" -c "$REDIS_CONT" -- redis-cli GET "$K" 2>/dev/null | tr -d '\r')
      CACHED_KIDS=$(printf '%s' "$VAL" | python3 -c 'import sys,json,re
raw=sys.stdin.read()
# Laravel serializer wraps; try parse pure JSON first
try:d=json.loads(raw)
except Exception:
  # naive extract kid from serialized payload
  d={"keys":[{"kid":x} for x in re.findall(r"\"kid\";s:\d+:\"([^\"]+)\"",raw)]}
print(",".join([k.get("kid","") for k in d.get("keys",[])]))' 2>/dev/null || echo "?")
      info "  $K -> cached kids: $CACHED_KIDS"
      if printf ",%s," "$CACHED_KIDS" | grep -q ",$TOK_KID,"; then
        pass "  cache có kid của token"
      else
        fail "  cache KHÔNG có kid token -> đây là nguyên nhân (A) stale cache"
      fi
    done
  else
    warn "Không tìm thấy key 'jwks_identity' trong Redis (có thể cache driver != redis hoặc prefix khác)"
  fi
else
  warn "Không có redis pod để inspect"
fi

# ---------------------------- 5) Clear cache + retest ---------------------
hdr "5) Clear cache identity-service + retest"
echo "  → php artisan cache:clear"
kubectl -n "$APP_NS" exec "$IDENT_POD" -c app -- sh -c 'cd /var/www/html && php artisan cache:clear' 2>&1 | sed 's/^/    /'
# fallback: xóa thẳng trên redis
if [ -n "$REDIS_POD" ] && [ -n "$REDIS_CONT" ]; then
  echo "  → redis-cli DEL các key jwks_identity*"
  kubectl -n "$APP_NS" exec "$REDIS_POD" -c "$REDIS_CONT" -- sh -c '
    for k in $(redis-cli --scan --pattern "*jwks_identity*"); do redis-cli DEL "$k"; done
  ' 2>&1 | sed 's/^/    /'
fi

sleep 1
echo "  → retest /api/candidates/profile"
RC=$(curl -s -o /tmp/atdj.$$ -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer $TOK" -H "Origin: $FE_ORIGIN" \
  "$KONG_URL/api/candidates/profile")
RB=$(head -c 240 /tmp/atdj.$$ 2>/dev/null || echo "")
rm -f /tmp/atdj.$$
case "$RC" in
  200|404) pass "/api/candidates/profile = $RC — đã thông";;
  401)     fail "vẫn 401 — body: $RB"
           info "Xem log lại để biết exception thật sự:"
           info "  kubectl -n $APP_NS logs $IDENT_POD -c app --tail=200 | grep -E 'Identity Auth Failed|Auth Failed'";;
  403)     warn "403 (OPA chặn) — body: $RB";;
  *)       warn "$RC — body: $RB";;
esac

# ---------------------------- 6) NEXT ------------------------------------
hdr "6) NEXT"
cat <<EOF
  · Nếu mục 5 đã = 200/404 → BE thông. Mở $FE_ORIGIN/login đăng nhập $TEST_USER/$TEST_PASSWORD.
  · Nếu vẫn 401: gửi mình:
      kubectl -n $APP_NS logs $IDENT_POD -c app --tail=300 | grep -E 'Identity|Auth|JWK|Signature|kid|Expired'
  · Nếu mục 3 báo identity-service KHÔNG fetch được JWKS → là Cilium policy chặn.
    Mình sẽ gửi tiếp script mở L4 cho identity-service -> security/keycloak:8080.
EOF
