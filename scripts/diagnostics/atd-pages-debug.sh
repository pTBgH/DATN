#!/usr/bin/env bash
# =============================================================================
# atd-pages-debug.sh — Tại sao FE atd vẫn gọi https://auth.job7189.com (default)
# thay vì $KONG_URL hiện tại?
#
# Triệu chứng từ browser:
#   POST https://auth.job7189.com/realms/job7189/protocol/openid-connect/token
#        → ERR_NAME_NOT_RESOLVED / fail to fetch
# Lý do: NEXT_PUBLIC_* được "nướng" vào lúc BUILD. Nếu build chạy TRƯỚC khi env
# được PATCH (hoặc build mới chưa xong, hoặc CDN vẫn cache HTML cũ) thì bundle
# vẫn dùng giá trị fallback trong src/lib/config.ts:
#   keycloak.baseUrl  ?? "https://auth.job7189.com"
#
# Script này (chỉ đọc Cloudflare API + bundle):
#   1. Liệt kê 5 deployment mới nhất + status + commit_hash
#   2. Xem env_vars production hiện tại
#   3. Bundle JS hiện đang phục vụ: tìm "auth.job7189.com" vs $KONG_URL
#   4. Nếu cần: trigger rebuild MỚI (deploy hook), wait 4-6 phút, retest
#
# Chạy:
#   bash atd-pages-debug.sh
#   FORCE_REBUILD=1 bash atd-pages-debug.sh
# =============================================================================
set -uo pipefail
PROJ="${CF_PAGES_PROJECT:-job7189-atd}"
CF_DIR="${CF_DIR:-/home/ptb/.config/cloudflare}"
CF_ACC="${CF_ACCOUNT_ID:-98601df846b714b6b64c29d2f199a854}"
CF_API="https://api.cloudflare.com/client/v4"
FE_ORIGIN="${FE_ORIGIN:-https://job7189-atd.pages.dev}"
FORCE_REBUILD="${FORCE_REBUILD:-0}"
WAIT_BUILD="${WAIT_BUILD:-1}"

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

TOKEN_FILE="$CF_DIR/token"
HOOK_FILE="$CF_DIR/deploy_hook_atd"
[ -r "$TOKEN_FILE" ] || { fail "Không đọc được $TOKEN_FILE"; exit 1; }
TOKEN="$(cat "$TOKEN_FILE")"

# auto KONG_URL
if [ -z "${KONG_URL:-}" ]; then
  KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null \
              | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)"
fi
KONG_URL="${KONG_URL%/}"

hdr "0) Mong đợi: bundle phải gọi $KONG_URL, KHÔNG phải auth.job7189.com"
info "FE_ORIGIN = $FE_ORIGIN"
info "KONG_URL  = $KONG_URL"

# ----------------------------------------------------------------------------
hdr "1) 5 deployment mới nhất ($PROJ)"
DEPS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$CF_API/accounts/$CF_ACC/pages/projects/$PROJ/deployments?per_page=5")
echo "$DEPS" | python3 - <<'PY'
import sys,json
d=json.load(sys.stdin)
if not d.get("success"):
  print("  API ERROR:", d.get("errors")); sys.exit(0)
for r in d.get("result", []):
  st = (r.get("latest_stage") or {}).get("status","?")
  name = (r.get("latest_stage") or {}).get("name","?")
  env = r.get("environment","?")
  url = r.get("url","?")
  ct  = r.get("created_on","?")
  shrt= (r.get("short_id") or r.get("id",""))[:8]
  src = ((r.get("source") or {}).get("config") or {}).get("repo_name") or "hook"
  print(f"  {ct}  {env:11s}  {st:9s}  stage={name:10s}  id={shrt}  src={src}  url={url}")
PY

# ----------------------------------------------------------------------------
hdr "2) Env_vars production hiện tại ($PROJ)"
ENVRES=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$CF_API/accounts/$CF_ACC/pages/projects/$PROJ")
echo "$ENVRES" | python3 - "$KONG_URL" <<'PY'
import sys,json
want=sys.argv[1]
d=json.load(sys.stdin)
if not d.get("success"):
  print("  API ERROR:", d.get("errors")); sys.exit(0)
ev = ((d.get("result") or {}).get("deployment_configs") or {}).get("production", {}).get("env_vars") or {}
keys=["NEXT_PUBLIC_USE_MOCK","NEXT_PUBLIC_API_BASE_URL","NEXT_PUBLIC_KEYCLOAK_URL","NEXT_PUBLIC_KEYCLOAK_REALM","NEXT_PUBLIC_KEYCLOAK_CLIENT_ID"]
for k in keys:
  v = ev.get(k)
  if v is None:
    print(f"  {k:34s} = <KHÔNG SET>")
  else:
    val = v.get("value","")
    t   = v.get("type","")
    mark = ""
    if k in ("NEXT_PUBLIC_API_BASE_URL","NEXT_PUBLIC_KEYCLOAK_URL") and val != want:
      mark = "  ← KHÔNG khớp KONG_URL hiện tại"
    print(f"  {k:34s} = {val}  [{t}]{mark}")
PY

# ----------------------------------------------------------------------------
hdr "3) Bundle JS hiện đang phục vụ — grep auth.job7189.com / KONG_URL"
HOST_KONG="$(printf '%s' "$KONG_URL" | sed -E 's#^https?://##')"
TMPD=$(mktemp -d); cd "$TMPD"
curl -s --max-time 15 "$FE_ORIGIN/login" -o login.html
# Trích các URL chunk
CHUNKS=$(grep -oE '/_next/static/[^"'\'']+\.js' login.html | sort -u | head -30)
[ -z "$CHUNKS" ] && warn "Không thấy chunk /_next/static/...js trong /login (FE không phải Next, hoặc HTML bị cache lạ)"
n_old=0; n_new=0; n_default=0
for c in $CHUNKS; do
  fn="$(basename "$c")"
  curl -s --max-time 15 "$FE_ORIGIN$c" -o "$fn"
  if grep -q "auth.job7189.com" "$fn" 2>/dev/null; then n_old=$((n_old+1)); fi
  if grep -q "api.job7189.com"  "$fn" 2>/dev/null; then n_default=$((n_default+1)); fi
  if grep -q "$HOST_KONG"        "$fn" 2>/dev/null; then n_new=$((n_new+1)); fi
done
info "chunks scanned = $(echo "$CHUNKS" | wc -w)"
[ "$n_default" -gt 0 ] && fail "$n_default chunk chứa 'api.job7189.com' (default API_BASE_URL — env chưa apply)"
[ "$n_old" -gt 0 ]     && fail "$n_old chunk chứa 'auth.job7189.com' (default KEYCLOAK_URL — env chưa apply) ← chính là cái browser đang gọi"
[ "$n_new" -gt 0 ]     && pass "$n_new chunk chứa '$HOST_KONG' (env mới đã vào bundle)"
[ "$n_old" -eq 0 ] && [ "$n_default" -eq 0 ] && [ "$n_new" -eq 0 ] && \
   warn "Không thấy URL nào trong các chunk vừa scan (có thể env nằm trong webpack-runtime chunk khác)"
cd - >/dev/null
rm -rf "$TMPD"

# ----------------------------------------------------------------------------
hdr "4) (TÙY CHỌN) Trigger rebuild + chờ"
NEEDS_REBUILD=0
if [ "$n_old" -gt 0 ] || [ "$n_default" -gt 0 ]; then NEEDS_REBUILD=1; fi
if [ "$FORCE_REBUILD" = "1" ]; then NEEDS_REBUILD=1; fi

if [ "$NEEDS_REBUILD" = "0" ]; then
  info "Bundle có vẻ đã đúng. Không trigger rebuild."
else
  if [ ! -r "$HOOK_FILE" ]; then
    fail "Cần rebuild nhưng không đọc được $HOOK_FILE. Vào Cloudflare dashboard → Pages → $PROJ → Retry/Build manually."
    exit 1
  fi
  HOOK="$(cat "$HOOK_FILE")"
  info "POST deploy hook để build mới với env hiện tại..."
  RESP=$(curl -s -X POST "$HOOK")
  NEW_ID=$(printf '%s' "$RESP" | python3 -c 'import sys,json
try:print(json.load(sys.stdin).get("result",{}).get("id",""))
except:print("")')
  pass "rebuild triggered (deploy id=$NEW_ID)"

  if [ "$WAIT_BUILD" != "1" ]; then
    info "Bỏ wait. Theo dõi: https://dash.cloudflare.com/$CF_ACC/pages/view/$PROJ"
    exit 0
  fi

  echo
  echo "  Chờ build hoàn tất (~3-5 phút). Polling mỗi 15s..."
  for i in $(seq 1 30); do
    sleep 15
    if [ -z "$NEW_ID" ]; then
      LD=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$CF_API/accounts/$CF_ACC/pages/projects/$PROJ/deployments?per_page=1" \
        | python3 -c 'import sys,json
try:r=json.load(sys.stdin)["result"][0];print(r["id"],(r.get("latest_stage") or {}).get("status",""),(r.get("latest_stage") or {}).get("name",""))
except:print("","","")')
      read NEW_ID STATUS STAGE <<<"$LD"
    else
      LD=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$CF_API/accounts/$CF_ACC/pages/projects/$PROJ/deployments/$NEW_ID" \
        | python3 -c 'import sys,json
try:r=json.load(sys.stdin)["result"];print((r.get("latest_stage") or {}).get("status",""),(r.get("latest_stage") or {}).get("name",""))
except:print("","")')
      read STATUS STAGE <<<"$LD"
    fi
    printf "    [%02d] id=%s  stage=%s  status=%s\n" "$i" "${NEW_ID:0:8}" "$STAGE" "$STATUS"
    case "$STATUS" in
      success|failure|canceled) break ;;
    esac
  done

  if [ "$STATUS" = "success" ]; then
    pass "build success"
  else
    fail "build status=$STATUS — xem chi tiết tại Cloudflare dashboard"
    exit 1
  fi

  echo
  info "Retest bundle sau build mới:"
  TMPD=$(mktemp -d); cd "$TMPD"
  curl -s --max-time 15 "$FE_ORIGIN/login" -o login2.html
  C2=$(grep -oE '/_next/static/[^"'\'']+\.js' login2.html | sort -u | head -30)
  m_old=0; m_new=0
  for c in $C2; do
    fn="$(basename "$c")"
    curl -s --max-time 15 "$FE_ORIGIN$c" -o "$fn"
    grep -q "auth.job7189.com" "$fn" 2>/dev/null && m_old=$((m_old+1))
    grep -q "$HOST_KONG"        "$fn" 2>/dev/null && m_new=$((m_new+1))
  done
  cd - >/dev/null
  rm -rf "$TMPD"
  info "chunks scanned: $(echo "$C2" | wc -w)  | có 'auth.job7189.com'=$m_old  | có '$HOST_KONG'=$m_new"
  [ "$m_old" -eq 0 ] && [ "$m_new" -gt 0 ] && pass "bundle đã sạch & dùng KONG_URL" \
                                           || warn "vẫn còn dấu vết default — clear browser cache rồi reload Ctrl+Shift+R"
fi

hdr "5) NEXT"
cat <<EOF
  Sau khi PASS ở mục 3 hoặc retest mục 4 đã sạch:
  · Mở browser INCOGNITO (tránh service worker / cache cũ): $FE_ORIGIN/login
  · DevTools Network: POST /realms/.../token PHẢI gọi $KONG_URL/realms/...
  · Nếu trình duyệt cũ vẫn cache, Ctrl+Shift+R hoặc xóa cookies cho domain pages.dev
EOF
