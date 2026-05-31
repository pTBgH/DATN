#!/usr/bin/env bash
# recheck-opa.sh — kiểm tra OPA đã NẠP recruiters.rego/admin.rego chưa + test lại.
# Chạy trên baosrc. Chỉ đọc.
set -uo pipefail
NS="${OPA_NAMESPACE:-security}"; CM="${CM_NAME:-opa-policies}"
REALM="${REALM:-job7189}"; CLIENT_ID="${CLIENT_ID:-web-frontend}"; PASSWORD="${PASSWORD:-dev1234}"

echo "== 1) policy-status annotation (opa-kube-mgmt ghi kết quả nạp) =="
kubectl -n "$NS" get configmap "$CM" -o jsonpath='{.metadata.annotations}' 2>/dev/null \
  | python3 -c 'import sys,json
try: a=json.load(sys.stdin)
except: a={}
import re
raw=a if isinstance(a,dict) else {}
for k,v in (raw.items() if raw else []):
    if "policy" in k.lower(): print(" ",k,"=",v)
print("  (nếu thấy error ở recruiters.rego/admin.rego => nạp lỗi)") ' 2>/dev/null \
  || kubectl -n "$NS" get configmap "$CM" -o yaml 2>/dev/null | grep -iA2 'policy-status\|annotations' | head -30

echo; echo "== 2) opa mgmt sidecar logs (lọc nạp/lỗi) =="
OPAP="$(kubectl -n "$NS" get pods -l app=opa -o name 2>/dev/null | head -1 | sed 's@pod/@@')"
[ -z "$OPAP" ] && OPAP="$(kubectl -n "$NS" get pods 2>/dev/null | grep -i '^opa' | awk '{print $1}' | head -1)"
echo "opa pod = $OPAP"
kubectl -n "$NS" logs "$OPAP" -c mgmt --tail=120 2>&1 | grep -iE 'recruiters|admin|error|err"|load|bundle|reload|added|removed' | tail -40 \
  || kubectl -n "$NS" logs "$OPAP" -c mgmt --tail=40 2>&1 | tail -40

echo; echo "== 3) re-test qua Kong =="
KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"; KONG_URL="${KONG_URL%/}"
echo "KONG_URL=$KONG_URL"
gt(){ curl -s --max-time 20 -X POST "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$CLIENT_ID" -d "username=$1" -d "password=$PASSWORD" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null; }
hb(){ curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H "Authorization: Bearer $2" "$KONG_URL$1"; }
for u in recruiter1 admin1 member1; do
  t="$(gt "$u")"; echo "--- $u (token_len=${#t}) ---"
  echo "  /api/recruiters/profile : $(hb /api/recruiters/profile "$t")"
  echo "  /api/admin/users        : $(hb /api/admin/users "$t")"
done
echo
echo ">> Đọc kết quả:"
echo "   recruiter1 /recruiters/profile : 401 = OPA OK (đã qua OPA, kẹt azp ở identity).  403 = OPA CHƯA nạp."
echo "   admin1     /admin/users        : 404 = OPA OK (identity chưa có route).          403 = OPA CHƯA nạp."
echo "   member1    /recruiters/profile : nên 403 (chặn đúng role)."
