#!/usr/bin/env bash
# =============================================================================
# zta-apply-identity-cnp.sh — Apply CNP cho phép app -> identity-service gọi
# nội bộ /api/internal/auth/sync-user (sửa 403 "User identity not found"),
# rồi verify lại. Chạy trên baosrc (cần `git pull` để có file CNP mới).
#
# !!! CÓ SỬA cluster: kubectl apply 1 CiliumNetworkPolicy (additive, không xoá gì).
#   bash zta-apply-identity-cnp.sh
# =============================================================================
set -uo pipefail
REPO="${REPO:-$HOME/projects/DATN}"
CNP="${CNP:-$REPO/infras/k8s-yaml/cilium-policies/05-allow-internal-identity-sync.yaml}"
NS="${NS:-job7189-apps}"; REALM="${REALM:-job7189}"; PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"; REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }
[ -f "$CNP" ] || { echo "ERR: không thấy $CNP — chạy 'cd $REPO && git pull' trước"; exit 1; }

KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"; TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
hdr "0) KONG_URL = $KONG_URL"

hdr "1) Apply CNP allow-internal-identity-sync"
kubectl apply -f "$CNP"
echo "  chờ Cilium nạp policy…"; sleep 6
kubectl -n "$NS" get cnp allow-internal-identity-sync 2>/dev/null

hdr "2) Test lại cuộc gọi nội bộ candidate -> identity (trong pod)"
POD="$(kubectl -n "$NS" get pod -l app=candidate-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -n "$POD" ]; then
  echo -n "    POST /api/internal/auth/sync-user (member1 sub bất kỳ, mong != 000): "
  kubectl -n "$NS" exec "$POD" -c app -- sh -lc \
    "curl -s -m5 -o /dev/null -w '%{http_code}' -X POST http://identity-service/api/internal/auth/sync-user -H 'Content-Type: application/json' -d '{\"keycloak_id\":\"probe\",\"type\":\"candidate\"}'" 2>/dev/null; echo
fi

hdr "3) VERIFY end-to-end qua Kong"
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
echo "  admin     → /api/admin/users        : $(call "$TA" /api/admin/users)   (404 = identity chưa có route)"

hdr "XONG — copy toàn bộ output gửi lại."
