#!/usr/bin/env bash
# =============================================================================
# zta-verify-gateway.sh — READ-ONLY: chờ Kong healthy, kiểm tra pod/log nếu lỗi,
# rồi verify 5 route. KHÔNG sửa cluster. Chạy trên baosrc.
#   bash zta-verify-gateway.sh
# =============================================================================
set -uo pipefail
GW_NS="${GW_NS:-gateway}"; APP_NS="${APP_NS:-job7189-apps}"
REALM="${REALM:-job7189}"; PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"; REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }

KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"
hdr "0) KONG_URL = $KONG_URL"

hdr "1) Trạng thái Kong pod"
kubectl -n "$GW_NS" get pods -l app=kong-gateway -o wide
echo "--- 40 dòng log cuối (tìm lỗi load config) ---"
kubectl -n "$GW_NS" logs deploy/kong-gateway --tail=40 2>/dev/null | tail -40

hdr "2) Chờ Kong /api/health = 200 (tối đa 90s)"
code=000
for i in $(seq 1 45); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$KONG_URL/api/health" 2>/dev/null)"
  echo "  [$i] /api/health = $code"
  [ "$code" = "200" ] && break
  sleep 2
done
if [ "$code" != "200" ]; then
  echo "  !! Kong vẫn chưa serve (code=$code). Thử qua port-forward (bỏ qua tunnel):"
  kubectl -n "$GW_NS" port-forward svc/kong-proxy 18080:80 >/tmp/kpf2.log 2>&1 & PF=$!; sleep 3
  echo "  PF /api/health = $(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://localhost:18080/api/health)"
  echo "  (nếu PF=200 mà tunnel!=200 → cloudflared-kong cần restart: sudo systemctl restart cloudflared-kong)"
  kill $PF 2>/dev/null
fi

TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
gettok(){
  local r; r="$(curl -s --max-time 20 -X POST "$TOKEN_EP" \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASSWORD" -d scope=openid)"
  echo "$r" | python3 -c 'import sys,json
s=sys.stdin.read()
try: print(json.loads(s).get("access_token",""))
except Exception: print("")'
}
call(){ local out code body; out="$(curl -s --max-time 20 -w "\n%{http_code}" -H "Authorization: Bearer $1" "$KONG_URL$2")"
  code="$(echo "$out"|tail -1)"; body="$(echo "$out"|sed '$d'|tr -d '\n'|cut -c1-180)"; echo "HTTP $code  $body"; }

hdr "3) VERIFY end-to-end"
TC="$(gettok "$CAND_CLIENT" member1)"; TR="$(gettok "$REC_CLIENT" recruiter1)"; TA="$(gettok "$REC_CLIENT" admin1)"
echo "  token candidate: $([ -n "$TC" ] && echo OK || echo FAIL)  recruiter: $([ -n "$TR" ] && echo OK || echo FAIL)  admin: $([ -n "$TA" ] && echo OK || echo FAIL)"
echo "  candidate → /api/candidates/profile : $(call "$TC" /api/candidates/profile)"
echo "  candidate → /api/my-applications    : $(call "$TC" /api/my-applications)"
echo "  recruiter → /api/recruiters/profile : $(call "$TR" /api/recruiters/profile)"
echo "  recruiter → /api/my-workspaces      : $(call "$TR" /api/my-workspaces)"
echo "  admin     → /api/admin/users        : $(call "$TA" /api/admin/users)"

hdr "4) identity-service: pod + log (chẩn đoán 401/500 ở profile)"
kubectl -n "$APP_NS" get pods | grep -iE 'identity|NAME' || true
echo "--- log identity 40 dòng cuối ---"
ID="$(kubectl -n "$APP_NS" get deploy -o name 2>/dev/null | grep -i identity | head -1)"
[ -n "$ID" ] && kubectl -n "$APP_NS" logs "$ID" --tail=40 2>/dev/null | tail -40 || echo "  (không thấy deploy identity)"

hdr "XONG — copy toàn bộ output gửi lại."
