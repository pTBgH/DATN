#!/usr/bin/env bash
# fix-opa-allow-realms.sh — token 403 do OPA chặn path /realms (Keycloak).
# Mở /realms ở tầng OPA (Keycloak tự bảo vệ endpoint của nó). CHECK trước, APPLY, VERIFY.
# Chạy trên baosrc.
set -uo pipefail
NS=security; CM=opa-policies
DIR="${POLICIES_DIR:-/home/ptb/projects/DATN/infras/k8s-yaml/opa/policies}"
PUB="$DIR/public.rego"
KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"; KONG_URL="${KONG_URL%/}"
echo "KONG_URL=$KONG_URL"; echo "DIR=$DIR"
[ -f "$PUB" ] || { echo "KHÔNG thấy $PUB — chỉnh POLICIES_DIR rồi chạy lại."; exit 1; }

echo; echo "════════ CHECK (trước khi áp) ════════"
echo "-- public.rego LIVE trong configmap có '/realms' chưa? --"
kubectl -n $NS get configmap $CM -o jsonpath='{.data.public\.rego}' 2>/dev/null | grep -n 'realms' \
  || echo "  (KHÔNG có /realms  => đúng là lý do token 403)"
echo "-- token member1 hiện tại --"
curl -s -o /dev/null -w "  token -> HTTP %{http_code}\n" --max-time 20 \
  -X POST "$KONG_URL/realms/job7189/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d client_id=web-frontend -d username=member1 -d password=dev1234

echo; echo "════════ APPLY ════════"
if grep -q 'KEYCLOAK_REALMS_ALLOW' "$PUB"; then
  echo "  public.rego đã có rule /realms — bỏ qua sửa file."
else
  cat >> "$PUB" <<'REGO'

# KEYCLOAK_REALMS_ALLOW — bề mặt OIDC công khai của Keycloak (token/auth/certs/
# .well-known/userinfo/logout…) phải mở ở tầng Kong/OPA để FE lấy được token.
# Keycloak tự enforce auth cho từng endpoint của nó.
allow if {
	startswith(input.path, "/realms/")
}
REGO
  echo "  đã thêm rule /realms vào public.rego."
fi
command -v opa >/dev/null 2>&1 && { echo "-- opa check --"; opa check "$DIR" && echo "  OPA syntax OK" || { echo "  opa check FAIL — DỪNG, không apply."; exit 1; }; }
echo "-- rebuild configmap từ $DIR (gồm cả recruiters/admin đã thêm trước) --"
kubectl create configmap $CM -n $NS --from-file="$DIR" --dry-run=client -o yaml | kubectl apply -f -
echo "  chờ opa-kube-mgmt reload ~10s..."; sleep 10

echo; echo "════════ VERIFY (sau khi áp) ════════"
gt(){ curl -s --max-time 20 -X POST "$KONG_URL/realms/job7189/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=web-frontend" -d "username=$1" -d password=dev1234 \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null; }
hb(){ curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H "Authorization: Bearer $2" "$KONG_URL$1"; }
for u in recruiter1 admin1 member1; do
  t="$(gt "$u")"; echo "--- $u (token_len=${#t}) ---"
  echo "  /api/recruiters/profile : $(hb /api/recruiters/profile "$t")"
  echo "  /api/admin/users        : $(hb /api/admin/users "$t")"
done
echo
echo ">> Mong đợi (sau refactor — OPA chỉ check public vs authenticated):"
echo "   token_len>0; mọi user pass OPA (200/4xx do Laravel quyết),"
echo "   member1 /recruiters/profile = 4xx do Laravel/Kong (không còn do OPA chặn role)."
echo ">> Nếu còn 403 toàn bộ + token_len=0 => /realms vẫn bị chặn, gửi mình output mục CHECK."
