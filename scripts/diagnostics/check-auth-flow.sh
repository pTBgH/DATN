#!/usr/bin/env bash
# =============================================================================
# check-auth-flow.sh  —  kiểm tra ĐẦY ĐỦ luồng auth Keycloak(password-grant) →
# Kong(jwt+OPA) → identity-service cho atd(candidate)/rct(recruiter+admin).
#
# CHẠY TRÊN baosrc. KHÔNG sửa gì cả (read-only), an toàn chạy lại.
#   bash check-auth-flow.sh                 # auto: KONG_URL từ tunnel
#   KONG_URL=https://xxx.trycloudflare.com bash check-auth-flow.sh
#   USE_PF=1 bash check-auth-flow.sh        # ép dùng port-forward kong-proxy:18000
#
# Mục tiêu: in ra ground-truth để quyết định, đặc biệt là claim `azp` của token
# (identity-service phân loại user theo azp) và HTTP code/ body từng route.
# =============================================================================
set -uo pipefail

REALM="${REALM:-job7189}"
PASSWORD="${PASSWORD:-dev1234}"
GW_NS="${GW_NS:-gateway}"
SEC_NS="${SEC_NS:-security}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"
REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"
WEB_CLIENT="${WEB_CLIENT:-web-frontend}"

c_g(){ printf '\033[32m%s\033[0m' "$1"; }   # green
c_r(){ printf '\033[31m%s\033[0m' "$1"; }   # red
c_y(){ printf '\033[33m%s\033[0m' "$1"; }   # yellow
line(){ printf '%.0s─' {1..78}; echo; }
hdr(){ echo; line; echo "  $1"; line; }

PF_PID=""
cleanup(){ [ -n "$PF_PID" ] && kill "$PF_PID" 2>/dev/null; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 0) Resolve KONG_URL
# ---------------------------------------------------------------------------
hdr "0) KONG_URL"
if [ "${USE_PF:-0}" = "1" ] || [ -z "${KONG_URL:-}" ]; then
  TUN="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null \
        | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)"
fi
KONG_URL="${KONG_URL:-$TUN}"
KONG_URL="${KONG_URL%/}"
if [ "${USE_PF:-0}" = "1" ] || [ -z "$KONG_URL" ]; then
  echo "→ dùng port-forward svc/kong-proxy 18000:80 (KONG_URL trống hoặc USE_PF=1)"
  kubectl -n "$GW_NS" port-forward svc/kong-proxy 18000:80 >/tmp/kpf.log 2>&1 &
  PF_PID=$!; sleep 3
  KONG_URL="http://localhost:18000"
fi
echo "KONG_URL = $KONG_URL"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"

# get_token <client_id> <username> -> in token ra stdout (rỗng nếu fail), lỗi -> stderr
get_token(){
  local cid="$1" user="$2" resp
  resp="$(curl -s --max-time 20 -X POST "$TOKEN_EP" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      -d grant_type=password -d "client_id=$cid" \
      -d "username=$user" -d "password=$PASSWORD" -d scope=openid)"
  echo "$resp" | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except: d={}
sys.stdout.write(d.get("access_token",""))
sys.stderr.write(d.get("error_description") or d.get("error") or "")
'
}

# decode <token> -> "azp | iss | roles"
decode(){
  echo "$1" | python3 -c '
import sys,json,base64
t=sys.stdin.read().strip()
if not t or t.count(".")<2: print("(no token)"); sys.exit()
p=t.split(".")[1]; p+="="*(-len(p)%4)
d=json.loads(base64.urlsafe_b64decode(p))
roles=",".join((d.get("realm_access") or {}).get("roles",[]))
print("azp=%s | iss=%s | roles=[%s]"%(d.get("azp","?"),d.get("iss","?"),roles))
'
}

# call <token> <path> -> "HTTP <code>  body=<first 160 chars>"
call(){
  local tok="$1" path="$2" out code body
  out="$(curl -s --max-time 20 -w '\n%{http_code}' \
        -H "Authorization: Bearer $tok" "$KONG_URL$path")"
  code="$(echo "$out" | tail -1)"
  body="$(echo "$out" | sed '$d' | tr -d '\n' | cut -c1-160)"
  echo "HTTP $code  body=$body"
}

# ---------------------------------------------------------------------------
# 1) Keycloak client config (publicClient + directAccessGrants?)
# ---------------------------------------------------------------------------
hdr "1) Keycloak client config (cần publicClient=true & directAccessGrantsEnabled=true)"
KC_POD="$(kubectl -n "$SEC_NS" get pod -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ -z "$KC_POD" ]; then
  echo "$(c_y '!! không thấy pod keycloak (app=keycloak) — bỏ qua phần này')"
else
  KCADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:-$(kubectl -n "$SEC_NS" get secret app-secrets -o jsonpath='{.data.keycloak-admin-password}' 2>/dev/null | base64 -d)}"
  kc(){ kubectl -n "$SEC_NS" exec -i "$KC_POD" -- /opt/keycloak/bin/kcadm.sh "$@"; }
  if kc config credentials --server http://localhost:8080 --realm master --user admin --password "$KCADMIN_PASS" >/dev/null 2>&1; then
    for C in "$CAND_CLIENT" "$REC_CLIENT" "$WEB_CLIENT"; do
      ID="$(kc get clients -r "$REALM" -q clientId="$C" --fields id 2>/dev/null | python3 -c 'import sys,json;a=json.load(sys.stdin);print(a[0]["id"] if a else "")')"
      if [ -z "$ID" ]; then echo "  $C: $(c_r 'KHÔNG TỒN TẠI trong realm')"; continue; fi
      kc get "clients/$ID" -r "$REALM" --fields clientId,publicClient,directAccessGrantsEnabled,serviceAccountsEnabled 2>/dev/null \
        | tr -d '\n ' | sed 's/^/  /'; echo
    done
  else
    echo "$(c_y '!! kcadm login fail — set KEYCLOAK_ADMIN_PASSWORD=... rồi chạy lại nếu cần')"
  fi
fi

# ---------------------------------------------------------------------------
# 2) Token matrix — lấy token + soi azp/iss/roles
# ---------------------------------------------------------------------------
hdr "2) Token matrix (password grant qua Kong)"
declare -A TOK
get_and_show(){
  local label="$1" cid="$2" user="$3" err
  err="$(get_token "$cid" "$user" 2>&1 1>/tmp/.tok)"; local t; t="$(cat /tmp/.tok)"
  TOK["$label"]="$t"
  if [ -n "$t" ]; then
    echo "  [$label] $cid / $user : $(c_g OK)  $(decode "$t")"
  else
    echo "  [$label] $cid / $user : $(c_r FAIL)  err=$err"
  fi
}
get_and_show cand   "$CAND_CLIENT" member1
get_and_show rec    "$REC_CLIENT"  recruiter1
get_and_show admin  "$REC_CLIENT"  admin1
get_and_show webcand "$WEB_CLIENT" member1
echo "  (lưu ý: identity-service phân loại user theo azp == KEYCLOAK_{CANDIDATE,RECRUITER}_CLIENT_ID."
echo "   azp=web-frontend => identity trả 401 'Unauthorized Client'.)"

# ---------------------------------------------------------------------------
# 3) Kong gate — preflight + no-token (xác nhận jwt plugin đã áp chưa)
# ---------------------------------------------------------------------------
hdr "3) Kong gate (CORS preflight & no-token)"
for r in /api/candidates/profile /api/recruiters/profile /api/admin/users; do
  pf="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X OPTIONS "$KONG_URL$r" \
        -H 'Origin: https://job7189-atd.pages.dev' \
        -H 'Access-Control-Request-Method: GET' \
        -H 'Access-Control-Request-Headers: authorization')"
  nt="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$KONG_URL$r")"
  echo "  $r : OPTIONS=$pf (mong 200)   no-token GET=$nt (mong 401 nếu jwt plugin ĐÃ áp)"
done

# ---------------------------------------------------------------------------
# 4) End-to-end: token đúng -> route tương ứng
# ---------------------------------------------------------------------------
hdr "4) End-to-end (token đúng client → route)"
echo "  candidate → /api/candidates/profile (mong 2xx):"
echo "    $(call "${TOK[cand]}"  /api/candidates/profile)"
echo "  recruiter → /api/recruiters/profile (mong 2xx):"
echo "    $(call "${TOK[rec]}"   /api/recruiters/profile)"
echo "  admin     → /api/admin/users (mong 2xx, hoặc 404 nếu route chưa có ở identity):"
echo "    $(call "${TOK[admin]}" /api/admin/users)"
echo "  candidate → /api/my-applications (PR#2, mong 2xx; 404=Kong chưa apply, 403=OPA chưa apply):"
echo "    $(call "${TOK[cand]}"  /api/my-applications)"
echo "  recruiter → /api/my-workspaces (PR#2, mong 2xx; 404=Kong chưa apply, 403=OPA chưa apply):"
echo "    $(call "${TOK[rec]}"   /api/my-workspaces)"
echo
echo "  [neg] candidate → /api/recruiters/profile (mong 403 OPA — sai role):"
echo "    $(call "${TOK[cand]}"  /api/recruiters/profile)"
echo "  [neg] web-frontend token → /api/candidates/profile (mong 401 'Unauthorized Client' từ identity):"
echo "    $(call "${TOK[webcand]}" /api/candidates/profile)"

# ---------------------------------------------------------------------------
# 5) OPA policies đã nạp?
# ---------------------------------------------------------------------------
hdr "5) OPA configmap rego keys (expected: default.rego + public.rego)"
kubectl -n "$SEC_NS" get configmap opa-policies -o jsonpath='{.data}' 2>/dev/null \
  | grep -oE '"[a-z]+\.rego"' | sort -u | sed 's/^/  /' || echo "  $(c_y '!! không đọc được configmap opa-policies')"

hdr "XONG. Copy toàn bộ output này gửi lại."
