#!/usr/bin/env bash
# tok.sh — token endpoint 403 do Cloudflare/Kong edge hay do Keycloak? + job-service sau restart.
set -uo pipefail
KONG_URL="${1:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"; KONG_URL="${KONG_URL%/}"
echo "KONG_URL=$KONG_URL"

echo; echo "== A) token qua tunnel — FULL body + code =="
curl -s --max-time 20 -X POST "$KONG_URL/realms/job7189/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d client_id=web-frontend -d username=member1 -d password=dev1234 \
  -w '\n[HTTP %{http_code}]\n'
echo "health cùng tunnel -> $(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$KONG_URL/api/health")"

echo; echo "== B) token TRỰC TIẾP trong cluster (bỏ qua Cloudflare/Kong) =="
JP="$(kubectl -n job7189-apps get pods -l app=job-service -o name 2>/dev/null | head -1 | sed 's@pod/@@')"
kubectl -n job7189-apps exec "$JP" -c app -- sh -lc '
  wget -qO- --timeout=15 \
    --header="Content-Type: application/x-www-form-urlencoded" \
    --post-data="grant_type=password&client_id=web-frontend&username=member1&password=dev1234" \
    http://keycloak.security.svc.cluster.local:8080/realms/job7189/protocol/openid-connect/token 2>&1 | head -c 300; echo' 2>&1 | tail -5

echo; echo "== C) job-service sau restart (502?) =="
echo "public/jobs -> $(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$KONG_URL/api/public/jobs")"
echo "pod=$JP"
kubectl -n job7189-apps logs "$JP" -c app --tail=25 2>&1 | grep -iE 'denied|sqlstate|error|listen|fpm|ready|exited|backend' | tail -12
