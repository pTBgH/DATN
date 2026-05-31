#!/usr/bin/env bash
# =============================================================================
# zta-fix-intra-ns-8000.sh — Apply CNP intra-ns (đã thêm port 8000) + gỡ CNP
# no-op cổng-80 của PR#3, rồi verify. Chạy trên baosrc (nhớ `git pull` để có
# 10-data.yaml mới — PR#4 đã merge).
#
# !!! CÓ SỬA cluster: kubectl apply 10-data.yaml + delete cnp no-op (idempotent).
#   bash zta-fix-intra-ns-8000.sh
# =============================================================================
set -uo pipefail
REPO="${REPO:-$HOME/projects/DATN}"
DATA_CNP="${DATA_CNP:-$REPO/infras/k8s-yaml/cilium-policies/namespaces/10-data.yaml}"
NS="${NS:-job7189-apps}"; REALM="${REALM:-job7189}"; PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"; REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }
[ -f "$DATA_CNP" ] || { echo "ERR: không thấy $DATA_CNP — chạy 'cd $REPO && git pull' trước"; exit 1; }
grep -q '"8000"' "$DATA_CNP" || { echo "ERR: $DATA_CNP CHƯA có port 8000 — git pull lại (PR#4)"; exit 1; }

KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"; TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
hdr "0) KONG_URL = $KONG_URL"

hdr "1) Apply 10-data.yaml (intra-ns + port 8000) + gỡ CNP no-op PR#3"
kubectl apply -f "$DATA_CNP"
kubectl -n "$NS" delete cnp allow-internal-identity-sync --ignore-not-found
echo "  chờ Cilium nạp policy…"; sleep 6
kubectl -n "$NS" get cnp allow-apps-intra-ns-services 2>/dev/null

hdr "2) Test cuộc gọi nội bộ trong pod (mong != 000)"
ex(){ local app="$1" desc="$2"; shift 2
  local pod; pod="$(kubectl -n "$NS" get pod -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  [ -z "$pod" ] && { printf '    %-50s : (no pod)\n' "$desc"; return; }
  printf '    %-50s : %s\n' "$desc" "$(kubectl -n "$NS" exec "$pod" -c app -- sh -lc "$*" 2>/dev/null)"; }
ex candidate-service "candidate→identity GET /api/health"      "curl -s -m5 -o /dev/null -w '%{http_code}' http://identity-service/api/health"
ex candidate-service "candidate→identity POST sync-user"       "curl -s -m5 -o /dev/null -w '%{http_code}' -X POST http://identity-service/api/internal/auth/sync-user -H 'Content-Type: application/json' -d '{\"keycloak_id\":\"x\",\"type\":\"candidate\"}'"
ex workspace-service "workspace→identity GET /api/health"      "curl -s -m5 -o /dev/null -w '%{http_code}' http://identity-service/api/health"

hdr "3) VERIFY end-to-end qua Kong"
gettok(){ curl -s --max-time 20 -X POST "$TOKEN_EP" -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASSWORD" -d scope=openid \
  | python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("access_token",""))
except Exception: print("")'; }
call(){ local out code body; out="$(curl -s --max-time 20 -w "\n%{http_code}" -H "Authorization: Bearer $1" "$KONG_URL$2")"
  code="$(echo "$out"|tail -1)"; body="$(echo "$out"|sed '$d'|tr -d '\n'|cut -c1-150)"; echo "HTTP $code  $body"; }
TC="$(gettok "$CAND_CLIENT" member1)"; TR="$(gettok "$REC_CLIENT" recruiter1)"; TA="$(gettok "$REC_CLIENT" admin1)"
echo "  candidate → /api/candidates/profile : $(call "$TC" /api/candidates/profile)"
echo "  candidate → /api/my-applications    : $(call "$TC" /api/my-applications)"
echo "  recruiter → /api/recruiters/profile : $(call "$TR" /api/recruiters/profile)"
echo "  recruiter → /api/my-workspaces      : $(call "$TR" /api/my-workspaces)"
echo "  admin     → /api/admin/users        : $(call "$TA" /api/admin/users)   (404 = identity chưa có route)"

hdr "XONG — copy toàn bộ output gửi lại."
