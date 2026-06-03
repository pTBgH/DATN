#!/usr/bin/env bash
# =============================================================================
# diagnose-auth-v3.sh — lấy ĐÚNG log container `app` + cơ chế deploy app
# Mục tiêu: (1) nguyên nhân job-service 500  (2) xác nhận identity "Unknown AZP"
#           (3) app deploy bằng image baked hay mount source (để biết cách fix)
# Chạy trên baosrc. Chỉ đọc. Ghi ra /tmp/diag-v3-*.txt — gửi lại nguyên file.
# =============================================================================
set -uo pipefail
NS="${NS:-job7189-apps}"
REALM="${REALM:-job7189}"; CLIENT_ID="${CLIENT_ID:-web-frontend}"; PASSWORD="${PASSWORD:-dev1234}"
OUT="/tmp/diag-v3-$(date +%Y%m%d-%H%M%S).txt"; exec > >(tee "$OUT") 2>&1
sec(){ printf '\n══════════════════════════════════════════════════════════════\n  %s\n══════════════════════════════════════════════════════════════\n' "$*"; }
sub(){ printf '\n----- %s -----\n' "$*"; }
pod(){ kubectl -n "$NS" get pods -l app="$1" -o name 2>/dev/null | head -1 | sed 's@pod/@@'; }

KONG_URL="${1:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"
echo "KONG_URL=$KONG_URL  NS=$NS"

sec "1. JOB-SERVICE — nguyên nhân /api/public/jobs 500 (container app)"
JP="$(pod job-service)"; echo "pod=$JP"
sub "gọi thử /api/public/jobs để sinh log mới"
curl -s -o /dev/null -w 'public/jobs -> HTTP %{http_code}\n' --max-time 15 "$KONG_URL/api/public/jobs" 2>/dev/null
sleep 1
sub "logs job-service -c app (120 dòng cuối)"
[ -n "$JP" ] && kubectl -n "$NS" logs "$JP" -c app --tail=120 2>&1 | tail -120 || echo "(no pod)"
sub "laravel log file (nếu có) -c app"
[ -n "$JP" ] && kubectl -n "$NS" exec "$JP" -c app -- sh -lc 'tail -n 60 storage/logs/laravel.log 2>/dev/null || tail -n 60 /var/www/html/storage/logs/laravel.log 2>/dev/null || echo "(không thấy laravel.log)"' 2>&1 | tail -65

sec "2. IDENTITY-SERVICE — xác nhận lỗi azp trên /api/candidates/profile"
IP="$(pod identity-service)"; echo "pod=$IP"
TOK="$(curl -s --max-time 15 -X POST "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$CLIENT_ID" -d username=member1 -d "password=$PASSWORD" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)"
echo "member1 token len=${#TOK}"
sub "gọi /api/candidates/profile kèm token (sinh log)"
curl -s --max-time 15 -H "Authorization: Bearer $TOK" "$KONG_URL/api/candidates/profile" -w '\n-> HTTP %{http_code}\n' | head -c 300; echo
sleep 1
sub "logs identity-service -c app (60 dòng cuối — tìm 'Unknown AZP')"
[ -n "$IP" ] && kubectl -n "$NS" logs "$IP" -c app --tail=60 2>&1 | tail -60 || echo "(no pod)"

sec "3. CƠ CHẾ DEPLOY APP (image baked hay mount source?)"
for D in identity-service job-service workspace-service; do
  sub "$D"
  echo "image    : $(kubectl -n "$NS" get deploy "$D" -o jsonpath='{range .spec.template.spec.containers[?(@.name=="app")]}{.image}{end}' 2>/dev/null)"
  echo "volMounts(app):"
  kubectl -n "$NS" get deploy "$D" -o jsonpath='{range .spec.template.spec.containers[?(@.name=="app")].volumeMounts[*]}  - {.name} -> {.mountPath}{"\n"}{end}' 2>/dev/null
  echo "volumes:"
  kubectl -n "$NS" get deploy "$D" -o jsonpath='{range .spec.template.spec.volumes[*]}  - {.name}: hostPath={.hostPath.path} cm={.configMap.name} pvc={.persistentVolumeClaim.claimName} empty={.emptyDir}{"\n"}{end}' 2>/dev/null
done

sec "4. IDENTITY env: client IDs Keycloak (để khớp fix azp)"
[ -n "$IP" ] && kubectl -n "$NS" exec "$IP" -c app -- sh -lc 'env | grep -iE "KEYCLOAK|CLIENT|REALM" | sort' 2>&1 | sed 's/SECRET=.*/SECRET=<redacted>/' || echo "(no pod)"

sec "XONG — gửi lại nguyên file: $OUT"
