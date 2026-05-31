#!/usr/bin/env bash
# apply-kong-cors.sh — áp kong.yml mới (đã có OPTIONS-skip), reload Kong, retest preflight.
# Chạy SAU khi đã pull/merge nhánh kong-cors-preflight (để infras/kong/kong.yml là bản mới).
#   REPO=$HOME/projects/DATN KONG_URL=https://...trycloudflare.com FE_ORIGIN=https://job7189-atd.pages.dev bash apply-kong-cors.sh
set -uo pipefail
REPO="${REPO:-$HOME/projects/DATN}"
KONG_NS="${KONG_NS:-gateway}"
KONG_URL="${KONG_URL:-https://hear-revelation-jewellery-subscribe.trycloudflare.com}"; KONG_URL="${KONG_URL%/}"
FE_ORIGIN="${FE_ORIGIN:-https://job7189-atd.pages.dev}"

echo "REPO=$REPO  KONG_NS=$KONG_NS"
echo "KONG_URL=$KONG_URL  FE_ORIGIN=$FE_ORIGIN"

# Đảm bảo bản kong.yml đang dùng đã có OPTIONS-skip
if ! grep -q 'get_method() == "OPTIONS"' "$REPO/infras/kong/kong.yml"; then
  echo "!! kong.yml CHƯA có OPTIONS-skip — bạn chưa pull/merge nhánh fix. Dừng."; exit 1
fi

echo; echo "== 1) cập nhật configmap kong-declarative-config từ kong.yml =="
kubectl create configmap kong-declarative-config \
  --from-file="$REPO/infras/kong/kong.yml" -n "$KONG_NS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo; echo "== 2) reload Kong (rollout restart cho chắc) =="
kubectl -n "$KONG_NS" rollout restart deploy/kong-gateway
kubectl -n "$KONG_NS" rollout status deploy/kong-gateway --timeout=120s

echo; echo "== 3) retest preflight OPTIONS (mong 200/204) =="
for r in /api/candidates/profile /api/recruiters/profile; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$KONG_URL$r" \
    -H "Origin: $FE_ORIGIN" -H 'Access-Control-Request-Method: GET' -H 'Access-Control-Request-Headers: authorization')
  echo "  OPTIONS $r -> $code"
done

echo; echo "== 4) sanity: token + GET có Authorization vẫn 200 =="
gt(){ curl -s -X POST "$KONG_URL/realms/job7189/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d password=dev1234 \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))'; }
Tm="$(gt candidate-app-dev member1)"; Tr="$(gt recruiter-app-dev recruiter1)"
echo "  member1    /api/candidates/profile : $(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $Tm" "$KONG_URL/api/candidates/profile")"
echo "  recruiter1 /api/recruiters/profile : $(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $Tr" "$KONG_URL/api/recruiters/profile")"

echo; echo ">> Mong: mục 3 = 200/204 (preflight thông) ; mục 4 = 200 (request thật vẫn qua OPA+jwt)."
