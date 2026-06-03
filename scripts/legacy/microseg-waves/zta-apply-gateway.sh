#!/usr/bin/env bash
# =============================================================================
# zta-apply-gateway.sh — NẠP kong.yml (PR#1/#2) vào cluster + SYNC issuer
# Keycloak tunnel hiện tại vào jwt_secrets của Kong + reload, rồi nạp lại OPA
# configmap, sau đó VERIFY.  CHẠY TRÊN baosrc.
#
# !!! Script này CÓ SỬA cluster: cập nhật configmap kong-declarative-config,
#     rollout restart deploy/kong-gateway, cập nhật configmap opa-policies.
#     (dev, 1 replica → Kong gián đoạn vài giây). An toàn chạy lại.
#
#   bash zta-apply-gateway.sh
#   KONG_URL=https://xxx.trycloudflare.com bash zta-apply-gateway.sh
# =============================================================================
set -uo pipefail

REPO="${REPO:-$HOME/projects/DATN}"
KONG_YML="${KONG_YML:-$REPO/infras/kong/kong.yml}"
POLDIR="${POLDIR:-$REPO/infras/k8s-yaml/opa/policies}"
GW_NS="${GW_NS:-gateway}"
SEC_NS="${SEC_NS:-security}"
APP_NS="${APP_NS:-job7189-apps}"
REALM="${REALM:-job7189}"
PASSWORD="${PASSWORD:-dev1234}"
CAND_CLIENT="${CAND_CLIENT:-candidate-app-dev}"
REC_CLIENT="${REC_CLIENT:-recruiter-app-dev}"

line(){ printf '%.0s─' {1..78}; echo; }
hdr(){ echo; line; echo "  $1"; line; }
[ -f "$KONG_YML" ] || { echo "ERR: không thấy $KONG_YML (set REPO=…)"; exit 1; }
[ -d "$POLDIR" ]   || { echo "ERR: không thấy $POLDIR"; exit 1; }

# ---------------------------------------------------------------------------
hdr "0) KONG_URL + issuer thật"
KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"
[ -z "$KONG_URL" ] && { echo "ERR: không tìm thấy KONG_URL (truyền KONG_URL=…)"; exit 1; }
echo "KONG_URL = $KONG_URL"

TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
TOK_CAND="$(curl -s --max-time 20 -X POST "$TOKEN_EP" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$CAND_CLIENT" \
  -d username=member1 -d "password=$PASSWORD" -d scope=openid \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')"
[ -z "$TOK_CAND" ] && { echo "ERR: không lấy được token (member1/$CAND_CLIENT) — check Keycloak"; exit 1; }

ISS="$(echo "$TOK_CAND" | python3 -c '
import sys,json,base64
t=sys.stdin.read().strip(); p=t.split(".")[1]; p+="="*(-len(p)%4)
print(json.loads(base64.urlsafe_b64decode(p))["iss"])')"
echo "ISS (iss thật trong token) = $ISS"

# Realm RSA public key (live) → PEM; fallback: lấy PEM có sẵn trong repo kong.yml
PEM="$(curl -s --max-time 20 "$KONG_URL/realms/$REALM" \
  | python3 -c '
import sys,json,textwrap
try: k=json.load(sys.stdin)["public_key"]
except: sys.exit(1)
print("-----BEGIN PUBLIC KEY-----")
print("\n".join(textwrap.wrap(k,64)))
print("-----END PUBLIC KEY-----")' 2>/dev/null)"
if [ -z "$PEM" ]; then
  echo "  (fallback) dùng PEM trong repo kong.yml"
  PEM="$(awk '/-----BEGIN PUBLIC KEY-----/{f=1} f{print} /-----END PUBLIC KEY-----/{if(f)exit}' "$KONG_YML" | sed 's/^ *//')"
fi
echo "PEM (rút gọn): $(echo "$PEM" | sed -n '2p' | cut -c1-40)…"

# ---------------------------------------------------------------------------
hdr "1) Sinh kong.gen.yml = kong.yml + jwt_secret cho issuer hiện tại"
GEN=/tmp/kong.gen.yml
ISS="$ISS" PEM="$PEM" python3 - "$KONG_YML" "$GEN" <<'PY'
import os,sys
src,dst=sys.argv[1],sys.argv[2]
iss=os.environ["ISS"]; pem=os.environ["PEM"].strip("\n")
txt=open(src).read()
marker="    jwt_secrets:\n"
i=txt.index(marker)+len(marker)
pem_indented="\n".join("          "+l for l in pem.splitlines())
block=(f'      - algorithm: RS256\n'
       f'        key: "{iss}"\n'
       f'        # BEGIN TUNNEL ISSUER (auto-synced)\n'
       f'        rsa_public_key: |\n{pem_indented}\n'
       f'        # END TUNNEL ISSUER\n')
open(dst,"w").write(txt[:i]+block+txt[i:])
print("  wrote",dst)
PY
grep -n "$ISS" "$GEN" >/dev/null && echo "  ✓ issuer đã chèn vào $GEN" || { echo "  ✗ chèn thất bại"; exit 1; }

# ---------------------------------------------------------------------------
hdr "2) Apply Kong configmap + rollout restart"
kubectl create configmap kong-declarative-config --from-file=kong.yml="$GEN" \
  -n "$GW_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$GW_NS" rollout restart deploy/kong-gateway
kubectl -n "$GW_NS" rollout status deploy/kong-gateway --timeout=90s

# ---------------------------------------------------------------------------
hdr "3) Nạp lại OPA configmap từ $POLDIR"
ARGS=(); for f in "$POLDIR"/*.rego; do ARGS+=(--from-file="$(basename "$f")=$f"); done
kubectl create configmap opa-policies -n "$SEC_NS" "${ARGS[@]}" --dry-run=client -o yaml \
  | kubectl label --local -f - openpolicyagent.org/policy=rego --dry-run=client -o yaml \
  | kubectl apply -f -
echo "  chờ OPA reload…"; sleep 8

# ---------------------------------------------------------------------------
hdr "4) VERIFY end-to-end"
sleep 3
gettok(){ curl -s --max-time 20 -X POST "$TOKEN_EP" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$1" -d "username=$2" -d "password=$PASSWORD" -d scope=openid \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))'; }
call(){ local out code body; out="$(curl -s --max-time 20 -w '\n%{http_code}' -H "Authorization: Bearer $1" "$KONG_URL$2")"
  code="$(echo "$out"|tail -1)"; body="$(echo "$out"|sed '$d'|tr -d '\n'|cut -c1-160)"; echo "HTTP $code  $body"; }

TC="$(gettok "$CAND_CLIENT" member1)"
TR="$(gettok "$REC_CLIENT" recruiter1)"
TA="$(gettok "$REC_CLIENT" admin1)"
echo "  candidate → /api/candidates/profile : $(call "$TC" /api/candidates/profile)"
echo "  candidate → /api/my-applications    : $(call "$TC" /api/my-applications)"
echo "  recruiter → /api/recruiters/profile : $(call "$TR" /api/recruiters/profile)"
echo "  recruiter → /api/my-workspaces      : $(call "$TR" /api/my-workspaces)"
echo "  admin     → /api/admin/users        : $(call "$TA" /api/admin/users)"

# ---------------------------------------------------------------------------
hdr "5) identity-service logs (chẩn đoán nếu profile vẫn 401/500)"
ID_DEPLOY="$(kubectl -n "$APP_NS" get deploy -o name 2>/dev/null | grep -i identity | head -1)"
if [ -n "$ID_DEPLOY" ]; then
  kubectl -n "$APP_NS" logs "$ID_DEPLOY" --tail=25 2>/dev/null | grep -iE 'auth failed|exception|sql|mysql|denied|unauthorized|error' | tail -15 \
    || echo "  (không có dòng lỗi rõ ràng trong 25 dòng cuối)"
else
  echo "  không thấy deploy identity trong ns $APP_NS"
fi

hdr "XONG — copy toàn bộ output gửi lại."
