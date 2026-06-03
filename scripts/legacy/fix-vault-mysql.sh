#!/usr/bin/env bash
# fix-vault-mysql.sh — vì sao creds động lệch + sửa luôn (restart để re-lease & reload).
# Chạy trên baosrc.
set -uo pipefail
NS=job7189-apps
KONG_URL="${1:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"; KONG_URL="${KONG_URL%/}"
echo "KONG_URL=$KONG_URL"

echo; echo "== A) token endpoint raw (vì sao token_len=0) =="
curl -s -i --max-time 20 -X POST "$KONG_URL/realms/job7189/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d client_id=web-frontend -d username=member1 -d password=dev1234 \
  | sed -n '1,5p;/error/p;/access_token/s/.*/[got access_token]/p' | head -10

echo; echo "== B) DB creds job-service đang nắm trong /app-secrets (so với user lỗi 1045) =="
JP="$(kubectl -n $NS get pods -l app=job-service -o name 2>/dev/null | head -1 | sed 's@pod/@@')"
echo "pod=$JP   (user lỗi log trước: v-kubernetes-job-servic-7bhwtZWm)"
kubectl -n $NS exec "$JP" -c app -- sh -lc 'grep -rhIiE "DB_USERNAME|DB_HOST|DB_DATABASE" /app-secrets 2>/dev/null' 2>&1 | head

echo; echo "== C) vault-agent + env-watcher logs (job-service) =="
echo "--- vault-agent ---"; kubectl -n $NS logs "$JP" -c vault-agent --tail=20 2>&1 | tail -20
echo "--- env-watcher ---"; kubectl -n $NS logs "$JP" -c env-watcher --tail=20 2>&1 | tail -20

echo; echo "== D) keycloak có mất DB không (token_len=0) =="
KCP="$(kubectl -n security get pods -l app=keycloak -o name 2>/dev/null | head -1 | sed 's@pod/@@')"
kubectl -n security logs "$KCP" --tail=60 2>&1 | grep -iE 'error|exception|denied|sqlexception|jdbc|connection ref|could not' | tail -15 || echo "(không thấy lỗi DB rõ)"

echo; echo "== E) FIX: rollout restart job-service (re-lease creds + reload php-fpm) =="
kubectl -n $NS rollout restart deploy/job-service
kubectl -n $NS rollout status deploy/job-service --timeout=150s
sleep 4
echo "public/jobs sau restart -> HTTP $(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$KONG_URL/api/public/jobs")"
echo
echo ">> Nếu public/jobs về 200 => đúng là php-fpm giữ creds cũ sau khi Vault xoay (env-watcher không reload)."
echo ">> Nếu token (mục A) vẫn lỗi => Keycloak cũng mất DB; chạy thêm:"
echo "     kubectl -n security rollout restart deploy/keycloak && kubectl -n security rollout status deploy/keycloak --timeout=150s"
