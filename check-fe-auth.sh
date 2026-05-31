#!/usr/bin/env bash
# check-fe-auth.sh — kiểm tra luồng auth FE (password-grant) trên bản đang chạy.
# Set KONG_URL (tunnel hiện tại) và FE_ORIGIN (domain Cloudflare Pages của bạn) trước khi chạy:
#   KONG_URL=https://...trycloudflare.com FE_ORIGIN=https://atd-xxx.pages.dev bash check-fe-auth.sh
set -uo pipefail
KONG_URL="${KONG_URL:-https://hear-revelation-jewellery-subscribe.trycloudflare.com}"; KONG_URL="${KONG_URL%/}"
FE_ORIGIN="${FE_ORIGIN:-}"
REALM="${REALM:-job7189}"
PASS="${PASS:-dev1234}"

echo "KONG_URL=$KONG_URL"
echo "FE_ORIGIN=${FE_ORIGIN:-(chưa set — bỏ qua kiểm tra CORS theo origin)}"

tokfull(){ curl -s -X POST "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' ${FE_ORIGIN:+-H "Origin: $FE_ORIGIN"} \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASS"; }
at(){ printf '%s' "$1" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))'; }
azpof(){ python3 -c 'import sys,base64,json;t=sys.argv[1];p=(t.split(".")[1] if t.count(".")>=2 else "");p+="="*(-len(p)%4);print(json.loads(base64.urlsafe_b64decode(p)).get("azp") if p else "")' "$1"; }
hb(){ curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $2" "$KONG_URL$1"; }

echo; echo "== 1) TOKEN endpoint + header CORS (browser cần access-control-allow-origin) =="
for pair in "candidate-app-dev:member1" "recruiter-app-dev:recruiter1"; do
  c="${pair%%:*}"; u="${pair##*:}"
  H=$(curl -s -D - -o /dev/null -X POST "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' ${FE_ORIGIN:+-H "Origin: $FE_ORIGIN"} \
    -d grant_type=password -d "client_id=$c" -d "username=$u" -d "password=$PASS")
  code=$(printf '%s' "$H" | head -1 | tr -d '\r')
  aco=$(printf '%s' "$H" | grep -i '^access-control-allow-origin:' | tr -d '\r')
  echo "  $c/$u -> $code | ${aco:-ACAO: (KHÔNG có -> browser CHẶN; cần webOrigins trên client)}"
done

echo; echo "== 2) Token hợp lệ + azp + gọi route protected =="
Tm="$(at "$(tokfull candidate-app-dev member1)")"
Tr="$(at "$(tokfull recruiter-app-dev recruiter1)")"
echo "  member1    len=${#Tm} azp=$(azpof "$Tm") | /api/candidates/profile = $(hb /api/candidates/profile "$Tm")"
echo "  recruiter1 len=${#Tr} azp=$(azpof "$Tr") | /api/recruiters/profile = $(hb /api/recruiters/profile "$Tr")"

echo; echo "== 3) Preflight OPTIONS /api/* (Kong/OPA có chặn không) =="
for r in /api/candidates/profile /api/recruiters/profile; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$KONG_URL$r" \
    ${FE_ORIGIN:+-H "Origin: $FE_ORIGIN"} -H 'Access-Control-Request-Method: GET' -H 'Access-Control-Request-Headers: authorization')
  echo "  OPTIONS $r -> $code  (200/204 = OK; 401/403 = chặn preflight -> phải mở OPTIONS ở Kong/OPA)"
done

echo
echo ">> Đọc: mục 1 phải có ACAO (nếu trống -> chạy lại lệnh webOrigins). mục 2 azp đúng client + route 200."
echo "   mục 3 nếu 401/403 -> đó là việc tiếp theo (mở OPTIONS preflight ở gateway)."
