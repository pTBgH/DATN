#!/usr/bin/env bash
# =============================================================================
# zta-fix-dbcreds.sh — Vault dynamic DB creds lệch MySQL (1045 Access denied).
# MySQL bị reseed (pod 11h) → user động Vault cấp trước đó mất, nhưng pod còn
# giữ lease cũ trong /app-secrets/.env. Restart deploy → vault-agent xin lease
# MỚI (tạo lại user trong MySQL hiện tại) + reload php-fpm. Rồi verify.
#
# !!! CÓ SỬA cluster: rollout restart các deploy app trong job7189-apps.
# Chạy trên baosrc. An toàn chạy lại.
#   bash zta-fix-dbcreds.sh
# =============================================================================
set -uo pipefail
NS="${NS:-job7189-apps}"; REALM="${REALM:-job7189}"; PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"; REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
APPS=(identity-service candidate-service workspace-service job-service hiring-service communication-service storage-service)
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }

KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"; TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
hdr "0) KONG_URL = $KONG_URL"

hdr "1) rollout restart ${#APPS[@]} deploy (re-lease creds động)"
for a in "${APPS[@]}"; do kubectl -n "$NS" rollout restart "deploy/$a" 2>/dev/null && echo "  restarted $a" || echo "  (skip $a — không có deploy)"; done
echo "  --- chờ ready ---"
for a in "${APPS[@]}"; do kubectl -n "$NS" rollout status "deploy/$a" --timeout=150s 2>/dev/null | tail -1; done

hdr "2) Kiểm DB sau restart (PDO) — 3 service chính"
dbcheck(){
  local a="$1" pod
  pod="$(kubectl -n "$NS" get pod -l app="$a" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  [ -z "$pod" ] && { echo "  $a: (không thấy pod)"; return; }
  local u; u="$(kubectl -n "$NS" exec "$pod" -c app -- sh -lc 'grep ^DB_USERNAME= /var/www/.env 2>/dev/null' 2>/dev/null)"
  local r; r="$(kubectl -n "$NS" exec "$pod" -c app -- sh -lc 'cd /var/www && php artisan tinker --execute="try{DB::connection()->getPdo();echo \"DB_OK db=\".DB::connection()->getDatabaseName();}catch(\Throwable \$e){echo \"DB_FAIL: \".\$e->getMessage();}"' 2>/dev/null | tail -1)"
  echo "  $a [$u] -> $r"
}
dbcheck identity-service
dbcheck candidate-service
dbcheck workspace-service

hdr "3) VERIFY routes qua Kong"
gettok(){ curl -s --max-time 20 -X POST "$TOKEN_EP" -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASSWORD" -d scope=openid \
  | python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("access_token",""))
except Exception: print("")'; }
call(){ local out code body; out="$(curl -s --max-time 20 -w "\n%{http_code}" -H "Authorization: Bearer $1" "$KONG_URL$2")"
  code="$(echo "$out"|tail -1)"; body="$(echo "$out"|sed '$d'|tr -d '\n'|cut -c1-160)"; echo "HTTP $code  $body"; }
TC="$(gettok "$CAND_CLIENT" member1)"; TR="$(gettok "$REC_CLIENT" recruiter1)"; TA="$(gettok "$REC_CLIENT" admin1)"
echo "  candidate → /api/candidates/profile : $(call "$TC" /api/candidates/profile)"
echo "  candidate → /api/my-applications    : $(call "$TC" /api/my-applications)"
echo "  recruiter → /api/recruiters/profile : $(call "$TR" /api/recruiters/profile)"
echo "  recruiter → /api/my-workspaces      : $(call "$TR" /api/my-workspaces)"
echo "  admin     → /api/admin/users        : $(call "$TA" /api/admin/users)   (404 = identity chưa có route — bình thường)"

hdr "4) Nếu vẫn DB_FAIL: in log vault-agent của identity (chẩn đoán Vault không tạo được user)"
POD="$(kubectl -n "$NS" get pod -l app=identity-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -n "$POD" ]; then
  kubectl -n "$NS" exec "$POD" -c app -- sh -lc 'cd /var/www && php artisan tinker --execute="try{DB::connection()->getPdo();echo \"OK\";}catch(\Throwable \$e){echo \"FAIL\";}"' 2>/dev/null | tail -1 | grep -q OK \
    || { echo "  --- vault-agent log (identity) ---"; kubectl -n "$NS" logs "$POD" -c vault-agent --tail=25 2>&1 | grep -iE 'error|denied|mysql|lease|render|database' | tail -15 || true; }
fi

hdr "XONG — copy toàn bộ output gửi lại."
