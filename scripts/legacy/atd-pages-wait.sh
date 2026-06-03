#!/usr/bin/env bash
# =============================================================================
# atd-pages-wait.sh — Đợi build CF Pages atd hoàn tất + verify bundle
# Build mới (3855729b-...) đã trigger ở lần trước. Script này CHỈ poll + verify,
# không trigger thêm. Safe khi chạy lại nhiều lần.
#
#   bash atd-pages-wait.sh
#
# Nếu muốn ép trigger lại (bằng deploy hook): FORCE_REBUILD=1 bash atd-pages-wait.sh
# =============================================================================
set -uo pipefail
PROJ="${CF_PAGES_PROJECT:-job7189-atd}"
CF_DIR="${CF_DIR:-/home/ptb/.config/cloudflare}"
CF_ACC="${CF_ACCOUNT_ID:-98601df846b714b6b64c29d2f199a854}"
CF_API="https://api.cloudflare.com/client/v4"
FE_ORIGIN="${FE_ORIGIN:-https://job7189-atd.pages.dev}"
FORCE_REBUILD="${FORCE_REBUILD:-0}"

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

TOKEN="$(cat "$CF_DIR/token" 2>/dev/null || true)"
HOOK="$(cat "$CF_DIR/deploy_hook_atd" 2>/dev/null || true)"
[ -z "$TOKEN" ] && { fail "Không đọc được $CF_DIR/token"; exit 1; }

# auto KONG_URL
if [ -z "${KONG_URL:-}" ]; then
  KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null \
              | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)"
fi
KONG_URL="${KONG_URL%/}"
HOST_KONG="$(printf '%s' "$KONG_URL" | sed -E 's#^https?://##')"
hdr "0) $FE_ORIGIN phải tham chiếu $HOST_KONG"

# ---------------------------------------------------------------------------
hdr "1) Optional: trigger thêm 1 build nữa (FORCE_REBUILD=1)"
if [ "$FORCE_REBUILD" = "1" ]; then
  [ -z "$HOOK" ] && { fail "không có deploy_hook_atd"; exit 1; }
  R=$(curl -s -X POST "$HOOK")
  echo "$R" | head -c 200; echo
  pass "rebuild triggered"
else
  info "(skip; thêm FORCE_REBUILD=1 nếu cần)"
fi

# ---------------------------------------------------------------------------
hdr "2) Latest deployment status (poll tới khi success/failure)"
get_latest(){
  local resp http
  resp=$(curl -sS -w "\n__HTTP__%{http_code}" -H "Authorization: Bearer $TOKEN" \
    "$CF_API/accounts/$CF_ACC/pages/projects/$PROJ/deployments?per_page=1" 2>&1)
  http=$(printf '%s' "$resp" | grep -oE '__HTTP__[0-9]+' | tail -1 | sed 's/__HTTP__//')
  body=$(printf '%s' "$resp" | sed 's/__HTTP__[0-9]*$//')
  echo "HTTP=$http"
  if ! printf '%s' "$body" | python3 -c '
import sys,json
try:
  d=json.loads(sys.stdin.read())
  if not d.get("success"):
    print("API_ERR:", d.get("errors")); sys.exit(2)
  r=d["result"][0]
  st=(r.get("latest_stage") or {})
  print("ID="+r.get("id","")[:8])
  print("ENV="+r.get("environment",""))
  print("STAGE="+st.get("name",""))
  print("STATUS="+st.get("status",""))
  print("CREATED="+r.get("created_on",""))
except SystemExit:
  raise
except Exception as e:
  print("PARSE_ERR:", e); sys.exit(3)
' 2>&1; then
    echo "RAW_BODY=$(printf '%s' "$body" | head -c 300)"
  fi
}

DONE=0
for i in $(seq 1 40); do
  echo "  --- poll #$i ---"
  OUT="$(get_latest)"
  echo "$OUT" | sed 's/^/    /'
  ST=$(echo "$OUT" | awk -F= '/^STATUS=/{print $2}')
  case "$ST" in
    success)  pass "build success"; DONE=1; break ;;
    failure|canceled) fail "build $ST — xem dashboard"; DONE=2; break ;;
  esac
  sleep 15
done
[ "$DONE" = "0" ] && warn "timeout chờ build — kiểm tra dashboard"

# ---------------------------------------------------------------------------
hdr "3) Verify bundle sau build"
TMPD=$(mktemp -d); cd "$TMPD"
curl -s --max-time 15 "$FE_ORIGIN/login" -o login.html
CHUNKS=$(grep -oE '/_next/static/[^"'\'']+\.js' login.html | sort -u | head -30)
info "chunks=$(echo "$CHUNKS" | wc -w)"
n_old=0; n_def=0; n_new=0
for c in $CHUNKS; do
  fn="$(basename "$c")"
  curl -s --max-time 15 "$FE_ORIGIN$c" -o "$fn"
  grep -q "auth.job7189.com" "$fn" 2>/dev/null && n_old=$((n_old+1))
  grep -q "api.job7189.com"  "$fn" 2>/dev/null && n_def=$((n_def+1))
  grep -q "$HOST_KONG"        "$fn" 2>/dev/null && n_new=$((n_new+1))
done
cd - >/dev/null
rm -rf "$TMPD"
[ "$n_def" -gt 0 ] && fail "$n_def chunk còn 'api.job7189.com'"
[ "$n_old" -gt 0 ] && fail "$n_old chunk còn 'auth.job7189.com'"
[ "$n_new" -gt 0 ] && pass "$n_new chunk có '$HOST_KONG'"
[ "$n_old" -eq 0 ] && [ "$n_def" -eq 0 ] && [ "$n_new" -gt 0 ] && \
  pass "bundle SẠCH dấu vết default & dùng KONG_URL"

# ---------------------------------------------------------------------------
hdr "4) NEXT"
cat <<EOF
  · Browser INCOGNITO: $FE_ORIGIN/login
    username: member1   password: dev1234
  · DevTools Network: POST /realms/.../token đi tới $HOST_KONG (KHÔNG phải auth.job7189.com)
  · Nếu cache cứng: Ctrl+Shift+R, hoặc DevTools → Application → Clear storage
EOF
