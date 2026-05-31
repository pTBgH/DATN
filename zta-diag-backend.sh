#!/usr/bin/env bash
# =============================================================================
# zta-diag-backend.sh — READ-ONLY: lấy lỗi THẬT của 401/500 ở backend.
# Gửi 1 request tới mỗi route (để sinh log mới), rồi đọc laravel.log + thử
# kết nối DB + migrate:status trong container `app` của từng service.
# KHÔNG sửa cluster. Chạy trên baosrc.
#   bash zta-diag-backend.sh
# =============================================================================
set -uo pipefail
APP_NS="${APP_NS:-job7189-apps}"; REALM="${REALM:-job7189}"; PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"; REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }

KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"
TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
hdr "0) KONG_URL = $KONG_URL"

gettok(){ curl -s --max-time 20 -X POST "$TOKEN_EP" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASSWORD" -d scope=openid \
  | python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("access_token",""))
except Exception: print("")'; }
hit(){ curl -s -o /dev/null -w '  %{http_code}' --max-time 20 -H "Authorization: Bearer $1" "$KONG_URL$2"; echo "  <- $2"; }

TC="$(gettok "$CAND_CLIENT" member1)"; TR="$(gettok "$REC_CLIENT" recruiter1)"
hdr "1) Bắn request để sinh log mới"
hit "$TC" /api/candidates/profile
hit "$TR" /api/recruiters/profile
hit "$TC" /api/my-applications
hit "$TR" /api/my-workspaces

# app container của từng service
diag_svc(){
  local deploy="$1"
  hdr "SERVICE: $deploy"
  local pod; pod="$(kubectl -n "$APP_NS" get pod -l app="$deploy" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  [ -z "$pod" ] && pod="$(kubectl -n "$APP_NS" get pods --no-headers 2>/dev/null | awk -v d="$deploy" '$1 ~ d {print $1; exit}')"
  [ -z "$pod" ] && { echo "  (không tìm thấy pod cho $deploy)"; return; }
  echo "  pod=$pod"
  echo "  --- DB config (.env, ẩn password) ---"
  kubectl -n "$APP_NS" exec "$pod" -c app -- sh -lc \
    'grep -E "^DB_(CONNECTION|HOST|PORT|DATABASE|USERNAME)=" /var/www/.env 2>/dev/null; echo "DB_PASSWORD=$(grep -c ^DB_PASSWORD= /var/www/.env) line(s) set"' 2>/dev/null || echo "  (không đọc được .env)"
  echo "  --- thử kết nối DB (PDO) ---"
  kubectl -n "$APP_NS" exec "$pod" -c app -- sh -lc \
    'cd /var/www && php artisan tinker --execute="try{ DB::connection()->getPdo(); echo \"DB_OK db=\".DB::connection()->getDatabaseName(); }catch(\Throwable \$e){ echo \"DB_FAIL: \".\$e->getMessage(); }"' 2>/dev/null | tail -3 || echo "  (tinker lỗi)"
  echo "  --- 40 dòng cuối laravel.log ---"
  kubectl -n "$APP_NS" exec "$pod" -c app -- sh -lc \
    'f=$(ls -t /var/www/storage/logs/*.log 2>/dev/null | head -1); [ -n "$f" ] && tail -n 40 "$f" || echo "(không có log file)"' 2>/dev/null || echo "  (không đọc được log)"
}

diag_svc identity-service
diag_svc candidate-service
diag_svc workspace-service

hdr "2) MySQL pod (ns data) + Cilium egress nhanh"
kubectl -n data get pods 2>/dev/null | grep -iE 'mysql|NAME' || echo "  (không thấy ns data / mysql)"
echo "  CNP trong $APP_NS:"
kubectl -n "$APP_NS" get cnp 2>/dev/null | sed 's/^/    /' || echo "    (không có cnp)"

hdr "XONG — copy toàn bộ output gửi lại."
