#!/usr/bin/env bash
# =============================================================================
# zta-diag-sync.sh — READ-ONLY: vì sao /api/my-applications & /api/my-workspaces
# trả 403 "User identity not found". Re-verify (pod đã ấm) rồi, nếu vẫn 403,
# test THẲNG cuộc gọi nội bộ candidate/workspace → identity-service.
# KHÔNG sửa cluster. Chạy trên baosrc.
#   bash zta-diag-sync.sh
# =============================================================================
set -uo pipefail
NS="${NS:-job7189-apps}"; REALM="${REALM:-job7189}"; PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"; REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }
KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"; TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
hdr "0) KONG_URL = $KONG_URL"

gettok(){ curl -s --max-time 20 -X POST "$TOKEN_EP" -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASSWORD" -d scope=openid \
  | python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("access_token",""))
except Exception: print("")'; }
subof(){ echo "$1" | python3 -c 'import sys,json,base64
t=sys.stdin.read().strip();p=t.split(".")[1];p+="="*(-len(p)%4)
print(json.loads(base64.urlsafe_b64decode(p)).get("sub",""))'; }
call(){ local out code body; out="$(curl -s --max-time 20 -w "\n%{http_code}" -H "Authorization: Bearer $1" "$KONG_URL$2")"
  code="$(echo "$out"|tail -1)"; body="$(echo "$out"|sed '$d'|tr -d '\n'|cut -c1-160)"; echo "HTTP $code  $body"; }

TC="$(gettok "$CAND_CLIENT" member1)"; TR="$(gettok "$REC_CLIENT" recruiter1)"
SUB_C="$(subof "$TC")"; SUB_R="$(subof "$TR")"

hdr "1) Re-verify (pod đã ấm)"
MA="$(call "$TC" /api/my-applications)"; MW="$(call "$TR" /api/my-workspaces)"
echo "  candidate → /api/my-applications : $MA"
echo "  recruiter → /api/my-workspaces   : $MW"

hdr "2) Test cuộc gọi nội bộ → identity-service (từ trong pod)"
probe(){
  local app="$1" sub="$2" type="$3" pod
  pod="$(kubectl -n "$NS" get pod -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  [ -z "$pod" ] && { echo "  $app: (không thấy pod)"; return; }
  echo "  [$app] pod=$pod  (sub=$sub type=$type)"
  echo -n "    identity /api/health           : "
  kubectl -n "$NS" exec "$pod" -c app -- sh -lc 'curl -s -m5 -o /dev/null -w "%{http_code}" http://identity-service/api/health' 2>/dev/null; echo
  echo -n "    POST /api/internal/auth/sync-user: "
  kubectl -n "$NS" exec "$pod" -c app -- sh -lc \
    "curl -s -m5 -w ' [%{http_code}]' -X POST http://identity-service/api/internal/auth/sync-user -H 'Content-Type: application/json' -d '{\"keycloak_id\":\"$sub\",\"type\":\"$type\",\"email\":null,\"name\":\"x\"}'" 2>/dev/null | cut -c1-200; echo
  echo "    --- ServiceUser table + log sync ---"
  kubectl -n "$NS" exec "$pod" -c app -- sh -lc 'cd /var/www && php artisan tinker --execute="try{echo \"ServiceUser_count=\".\App\Models\ServiceUser::count();}catch(\Throwable \$e){echo \"TABLE_ERR: \".\$e->getMessage();}"' 2>/dev/null | tail -1
  kubectl -n "$NS" exec "$pod" -c app -- sh -lc 'f=$(ls -t /var/www/storage/logs/*.log 2>/dev/null|head -1); [ -n "$f" ] && grep -iE "Identity Sync Failed|Sync" "$f" | tail -5 || echo "(log trống)"' 2>/dev/null
}
probe candidate-service "$SUB_C" candidate
probe workspace-service "$SUB_R" recruiter

hdr "XONG — copy toàn bộ output gửi lại."
