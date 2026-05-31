#!/usr/bin/env bash
# Repoint Cloudflare Pages env -> current Kong quick-tunnel URL, then rebuild via deploy hooks.
#
# Vì NEXT_PUBLIC_* của Next.js bị "nướng" vào lúc BUILD, mỗi lần quick-tunnel đổi URL
# (cloudflared restart) thì FE phải build lại với URL mới. Script này:
#   1. Đọc URL trycloudflare hiện tại từ journal của service cloudflared-kong
#   2. PATCH env (secret_text) cho 2 Pages project trỏ về URL đó
#   3. Trigger build lại qua deploy hook (build kiểu git mới nạp được env;
#      POST /deployments ad_hoc KHÔNG nạp env -> build log "(none found)")
#
# Secrets KHÔNG nằm trong repo. Đọc từ $CF_DIR (mặc định /home/ptb/.config/cloudflare):
#   token             - Cloudflare API token (Pages:Edit), chmod 600
#   deploy_hook_atd   - URL deploy hook project job7189-atd
#   deploy_hook_rct   - URL deploy hook project job7189-rct
set -euo pipefail

CF_DIR="${CF_DIR:-/home/ptb/.config/cloudflare}"
TOKEN="$(cat "$CF_DIR/token")"
ACC="${CF_ACCOUNT_ID:-98601df846b714b6b64c29d2f199a854}"
HOOK_ATD="$(cat "$CF_DIR/deploy_hook_atd")"
HOOK_RCT="$(cat "$CF_DIR/deploy_hook_rct")"
API=https://api.cloudflare.com/client/v4

# 1) current Kong tunnel URL (override: pass as $1). Wait up to 60s for it to appear in log.
KONG_URL="${1:-}"
if [ -z "$KONG_URL" ]; then
  for _ in $(seq 1 30); do
    KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)"
    [ -n "$KONG_URL" ] && break
    sleep 2
  done
fi
[ -z "$KONG_URL" ] && { echo "ERR: no trycloudflare URL found" >&2; exit 1; }
echo "KONG_URL=$KONG_URL"

# 2) wait until reachable
code=000
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$KONG_URL/api/health" || true)"
  [ "$code" = "200" ] && break; sleep 2
done
echo "kong health=$code"

# 3) PATCH env (secret_text) for both projects
EV="{\"NEXT_PUBLIC_USE_MOCK\":{\"type\":\"secret_text\",\"value\":\"false\"},\"NEXT_PUBLIC_API_BASE_URL\":{\"type\":\"secret_text\",\"value\":\"$KONG_URL\"},\"NEXT_PUBLIC_KEYCLOAK_URL\":{\"type\":\"secret_text\",\"value\":\"$KONG_URL\"}}"
for P in job7189-atd job7189-rct; do
  curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$API/accounts/$ACC/pages/projects/$P" \
    --data "{\"deployment_configs\":{\"production\":{\"env_vars\":$EV},\"preview\":{\"env_vars\":$EV}}}" \
    | python3 -c "import sys,json;d=json.load(sys.stdin);print('  PATCH','$P',':',('OK' if d.get('success') else d.get('errors')))"
done

# 4) trigger rebuild via deploy hooks
curl -s -X POST "$HOOK_ATD" | python3 -c "import sys,json;print('  hook atd:',json.load(sys.stdin).get('result'))" || echo "  hook atd: posted"
curl -s -X POST "$HOOK_RCT" | python3 -c "import sys,json;print('  hook rct:',json.load(sys.stdin).get('result'))" || echo "  hook rct: posted"
echo "Done. Build ~2-4 phut."
