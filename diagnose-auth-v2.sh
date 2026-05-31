#!/usr/bin/env bash
# =============================================================================
# diagnose-auth.sh  —  Chẩn đoán end-to-end luồng auth FE -> Kong -> OPA -> svc
# =============================================================================
# Chạy TRÊN baosrc (nơi có kubectl, cloudflared-kong, ~/.config/cloudflare).
#
#   bash diagnose-auth.sh                 # tự tìm KONG_URL từ journal/CF Pages
#   bash diagnose-auth.sh https://xxx.trycloudflare.com   # ép KONG_URL
#
# Script CHỈ ĐỌC, không sửa gì. In ra report + ghi ra /tmp/diag-auth-*.txt.
# Gửi lại nguyên file /tmp/diag-auth-*.txt cho mình.
# =============================================================================
set -uo pipefail

# ---- config có thể override bằng env ----
REALM="${REALM:-job7189}"
CLIENT_ID="${CLIENT_ID:-web-frontend}"
PASSWORD="${PASSWORD:-dev1234}"
USERS="${USERS:-member1 recruiter1 admin1}"
CF_DIR="${CF_DIR:-$HOME/.config/cloudflare}"
[ -f "$CF_DIR/token" ] || CF_DIR="/home/ptb/.config/cloudflare"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-98601df846b714b6b64c29d2f199a854}"
CF_PROJECTS="${CF_PROJECTS:-job7189-atd job7189-rct}"
CF_API="https://api.cloudflare.com/client/v4"

OUT="/tmp/diag-auth-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$OUT") 2>&1

sec()  { printf '\n══════════════════════════════════════════════════════════════\n  %s\n══════════════════════════════════════════════════════════════\n' "$*"; }
sub()  { printf '\n----- %s -----\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# python3 helper: đọc 1 key (dotted) từ JSON trên stdin
pyget() { python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception as e: print(""); sys.exit(0)
for k in sys.argv[1].split("."):
    if isinstance(d,list):
        try: d=d[int(k)]
        except: d=""; break
    else: d=d.get(k,"") if isinstance(d,dict) else ""
print(d if d is not None else "")' "$1" 2>/dev/null; }

# decode JWT payload -> json (stdin = token)
jwtdecode() { python3 -c 'import sys,base64,json
t=sys.stdin.read().strip()
try:
    p=t.split(".")[1]; p+="="*(-len(p)%4)
    print(json.dumps(json.loads(base64.urlsafe_b64decode(p))))
except Exception as e: print("{}")' 2>/dev/null; }

sec "0. MÔI TRƯỜNG"
echo "host       : $(hostname)"
echo "date       : $(date -u +'%F %T UTC')"
echo "CF_DIR     : $CF_DIR  (token $( [ -f "$CF_DIR/token" ] && echo present || echo MISSING ))"
for t in curl python3 kubectl jq cloudflared; do
  printf '%-11s: %s\n' "$t" "$(have "$t" && command -v "$t" || echo 'NOT FOUND')"
done

# =============================================================================
sec "1. KONG_URL (tunnel hiện tại)"
KONG_URL="${1:-}"
SRC=""
if [ -z "$KONG_URL" ] && have journalctl; then
  KONG_URL="$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)"
  [ -n "$KONG_URL" ] && SRC="journal(cloudflared-kong)"
fi
if [ -z "$KONG_URL" ] && [ -f "$CF_DIR/token" ]; then
  KONG_URL="$(curl -s -H "Authorization: Bearer $(cat "$CF_DIR/token")" \
    "$CF_API/accounts/$CF_ACCOUNT_ID/pages/projects/job7189-atd" \
    | pyget result.deployment_configs.production.env_vars.NEXT_PUBLIC_API_BASE_URL.value)"
  [ -n "$KONG_URL" ] && SRC="cloudflare-pages-env(atd)"
fi
KONG_URL="${KONG_URL%/}"
if [ -z "$KONG_URL" ]; then
  echo "!! KHÔNG tìm được KONG_URL. Truyền tay: bash $0 https://xxx.trycloudflare.com"
  echo "   (các phần sau cần KONG_URL sẽ bị bỏ qua)"
else
  echo "KONG_URL = $KONG_URL   [nguồn: $SRC]"
fi

if [ -n "$KONG_URL" ]; then
  sub "Kong reachability"
  for p in /api/health /api/public/jobs; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$KONG_URL$p")"
    echo "GET $p -> HTTP $code"
  done
fi

# =============================================================================
sec "2. KEYCLOAK — password grant qua API (client public: $CLIENT_ID)"
declare -A TOK
if [ -n "$KONG_URL" ]; then
  TOKEN_EP="$KONG_URL/realms/$REALM/protocol/openid-connect/token"
  echo "token endpoint: $TOKEN_EP"
  echo "well-known    : $KONG_URL/realms/$REALM/.well-known/openid-configuration"
  ISS_WK="$(curl -s --max-time 12 "$KONG_URL/realms/$REALM/.well-known/openid-configuration" | pyget issuer)"
  echo "issuer(realm) : ${ISS_WK:-<không lấy được>}"

  for u in $USERS; do
    sub "user=$u"
    RESP="$(curl -s --max-time 15 -X POST "$TOKEN_EP" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      -d 'grant_type=password' -d "client_id=$CLIENT_ID" \
      -d "username=$u" -d "password=$PASSWORD")"
    AT="$(printf '%s' "$RESP" | pyget access_token)"
    if [ -n "$AT" ]; then
      TOK[$u]="$AT"
      CL="$(printf '%s' "$AT" | jwtdecode)"
      echo "grant         : OK (token len=${#AT})"
      echo "preferred_user: $(printf '%s' "$CL" | pyget preferred_username)"
      echo "iss (token)   : $(printf '%s' "$CL" | pyget iss)"
      echo "realm roles   : $(printf '%s' "$CL" | python3 -c 'import sys,json;print(",".join(json.load(sys.stdin).get("realm_access",{}).get("roles",[])))' 2>/dev/null)"
      echo "exp           : $(printf '%s' "$CL" | pyget exp)"
    else
      echo "grant         : FAIL"
      echo "response      : $(printf '%s' "$RESP" | head -c 300)"
    fi
  done
else
  echo "(bỏ qua — thiếu KONG_URL)"
fi

# =============================================================================
sec "3. KONG issuer keys vs token issuer (so khớp)"
echo "Issuer keys cấu hình trong kong.yml (jwt consumer):"
echo "  - http://auth.job7189.local/realms/$REALM"
echo "  - http://auth.job7189.local:8080/realms/$REALM"
echo "  - http://localhost:8080/realms/$REALM"
echo "  - http://keycloak.security.svc.cluster.local:8080/realms/$REALM"
echo
echo ">> Nếu 'iss (token)' ở mục 2 KHÔNG nằm trong danh sách trên thì Kong jwt"
echo "   plugin sẽ trả 401 (no matching key). Khi đó cần thêm issuer key vào kong.yml"
echo "   HOẶC đặt KC_HOSTNAME/issuer của Keycloak khớp 1 trong các key trên."

# =============================================================================
sec "4. MA TRẬN API (anon vs từng role)  [định dạng: HTTP code | body-snippet]"
# route|method
ROUTES="
/api/health|GET
/api/public/jobs|GET
/api/jobs|GET
/api/candidates/profile|GET
/api/recruiters/profile|GET
/api/admin/users|GET
/api/workspaces|GET
/api/applications|GET
/api/interviews|GET
"
hit() { # $1=path $2=method $3=token(optional) $4=label
  local path="$1" m="$2" tk="${3:-}" as="${4:-anon}"
  local args=(-s --max-time 15 -X "$m" -w $'\n%{http_code}')
  [ -n "$tk" ] && args+=(-H "Authorization: Bearer $tk")
  local raw code body
  raw="$(curl "${args[@]}" "$KONG_URL$path" 2>/dev/null)"
  code="$(printf '%s' "$raw" | tail -n1)"
  body="$(printf '%s' "$raw" | sed '$d' | tr -d '\n' | head -c 160)"
  printf '  %-28s %-6s %-9s %3s | %s\n' "$path" "$m" "$as" "$code" "$body"
}
if [ -n "$KONG_URL" ]; then
  printf '  %-28s %-6s %-9s %3s | %s\n' "PATH" "M" "AS" "HTTP" "BODY"
  while IFS='|' read -r path method; do
    [ -z "$path" ] && continue
    hit "$path" "$method" "" "anon"
    for u in $USERS; do
      [ -n "${TOK[$u]:-}" ] && hit "$path" "$method" "${TOK[$u]}" "$u"
    done
    echo
  done <<< "$ROUTES"
else
  echo "(bỏ qua — thiếu KONG_URL)"
fi

# =============================================================================
sec "5. KUBERNETES state"
if have kubectl; then
  sub "pods job7189-apps"
  kubectl -n job7189-apps get pods -o wide 2>&1 | head -40
  sub "pods gateway (kong) + security (opa/keycloak)"
  kubectl -n gateway get pods 2>&1 | head
  kubectl -n security get pods 2>&1 | head -20

  sub "OPA policies đã nạp (configmap security/opa-policies)"
  kubectl -n security get configmap opa-policies -o json 2>/dev/null \
    | python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except: print("  (không đọc được configmap)"); sys.exit(0)
for k in sorted(d.get("data",{}).keys()): print("   -",k)' 2>/dev/null \
    || echo "  (configmap opa-policies không tồn tại?)"
  echo "  >> THIẾU recruiters.rego / admin.rego => /api/recruiters/profile & /api/admin/users luôn 403."

  sub "Kong live config — route /api/candidates/profile có jwt plugin?"
  kubectl -n gateway get configmap kong-declarative-config -o jsonpath='{.data}' 2>/dev/null \
    | python3 -c 'import sys,json,re
raw=sys.stdin.read()
m=re.search(r"candidates/profile.{0,200}", raw)
print("  match:", (m.group(0)[:180] if m else "<không thấy route trong cm>"))
print("  >> nếu KHÔNG có chữ jwt ngay sau path => route candidate THIẾU plugin jwt (bug)")' 2>/dev/null \
    || echo "  (không đọc được kong-declarative-config)"

  sub "OPA pod logs (20 dòng cuối — xem decision allow/deny)"
  OPAP="$(kubectl -n security get pods -l app=opa -o name 2>/dev/null | head -1)"
  [ -z "$OPAP" ] && OPAP="$(kubectl -n security get pods 2>/dev/null | grep -i opa | awk '{print $1}' | head -1)"
  [ -n "$OPAP" ] && kubectl -n security logs "$OPAP" --tail=20 2>&1 | head -25 || echo "  (không tìm thấy pod OPA)"
else
  echo "kubectl NOT FOUND — bỏ qua phần K8s."
fi

# =============================================================================
sec "6. CLOUDFLARE PAGES (env vars + deployment + URL công khai)"
if [ -f "$CF_DIR/token" ]; then
  CFT="$(cat "$CF_DIR/token")"
  for P in $CF_PROJECTS; do
    sub "project $P"
    J="$(curl -s -H "Authorization: Bearer $CFT" "$CF_API/accounts/$CF_ACCOUNT_ID/pages/projects/$P")"
    OK="$(printf '%s' "$J" | pyget success)"
    if [ "$OK" != "True" ]; then
      echo "  API error: $(printf '%s' "$J" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("errors"))' 2>/dev/null | head -c 200)"
      continue
    fi
    SUB="$(printf '%s' "$J" | pyget result.subdomain)"
    echo "  public URL : https://$SUB"
    for V in NEXT_PUBLIC_USE_MOCK NEXT_PUBLIC_API_BASE_URL NEXT_PUBLIC_KEYCLOAK_URL NEXT_PUBLIC_KEYCLOAK_CLIENT_ID; do
      VAL="$(printf '%s' "$J" | pyget "result.deployment_configs.production.env_vars.$V.value")"
      [ -z "$VAL" ] && VAL="<secret/redacted hoặc chưa set>"
      printf '  env %-30s = %s\n' "$V" "$VAL"
    done
    # latest deployment status
    D="$(curl -s -H "Authorization: Bearer $CFT" "$CF_API/accounts/$CF_ACCOUNT_ID/pages/projects/$P/deployments?per_page=1")"
    echo "  last deploy: stage=$(printf '%s' "$D" | pyget result.0.latest_stage.name) status=$(printf '%s' "$D" | pyget result.0.latest_stage.status) at=$(printf '%s' "$D" | pyget result.0.latest_stage.ended_on)"
    [ -n "$SUB" ] && echo "  homepage   : HTTP $(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$SUB")"
  done
else
  echo "Không thấy $CF_DIR/token — bỏ qua phần Cloudflare Pages."
fi

# =============================================================================
sec "7. JOB-SERVICE 500 (vì /api/public/jobs trả 500)"
if have kubectl; then
  sub "pods job-service"
  kubectl -n job7189-apps get pods -l app=job-service -o wide 2>&1 | head
  JP="$(kubectl -n job7189-apps get pods -l app=job-service -o name 2>/dev/null | head -1)"
  [ -z "$JP" ] && JP="$(kubectl -n job7189-apps get pods 2>/dev/null | grep -i job-service | awk '{print $1}' | head -1)"
  if [ -n "$JP" ]; then
    sub "logs job-service (50 dòng cuối — tìm traceback/500)"
    kubectl -n job7189-apps logs "$JP" --tail=50 2>&1 | tail -50
  else
    echo "  (không tìm thấy pod job-service)"
  fi
else
  echo "(kubectl NOT FOUND)"
fi

# =============================================================================
sec "8. KEYCLOAK hostname & cloudflared tunnels (vì iss != Kong URL)"
if have kubectl; then
  sub "keycloak env hostname (KC_HOSTNAME*/frontendUrl)"
  KCP="$(kubectl -n security get pods -l app=keycloak -o name 2>/dev/null | head -1)"
  [ -z "$KCP" ] && KCP="$(kubectl -n security get pods 2>/dev/null | grep -i keycloak | awk '{print $1}' | head -1)"
  if [ -n "$KCP" ]; then
    kubectl -n security get "${KCP%%/*}" "${KCP##*/}" -o jsonpath='{range .spec.containers[*].env[*]}{.name}={.value}{"\n"}{end}' 2>/dev/null \
      | grep -iE 'KC_HOSTNAME|FRONTEND|PROXY|KC_HTTP' || echo "  (không thấy biến KC_HOSTNAME — có thể set qua args/CLI)"
    echo "  --- args ---"
    kubectl -n security get "${KCP%%/*}" "${KCP##*/}" -o jsonpath='{range .spec.containers[*]}{.args}{"\n"}{end}' 2>/dev/null | tr ',' '\n' | grep -iE 'hostname|frontend|proxy' || true
  else
    echo "  (không tìm thấy pod keycloak)"
  fi
fi
sub "các service cloudflared (systemd) + URL mỗi tunnel"
if have systemctl; then
  systemctl list-units --type=service --all 2>/dev/null | grep -i cloudflared || echo "  (không thấy unit cloudflared)"
  for U in $(systemctl list-units --type=service --all --plain --no-legend 2>/dev/null | awk '{print $1}' | grep -i cloudflared); do
    URL="$(journalctl -u "$U" --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)"
    echo "  $U -> ${URL:-<no url in journal>}"
  done
else
  echo "  (systemctl NOT FOUND)"
fi

# =============================================================================
sec "9. KONG live jwt issuer keys (configmap đang chạy)"
if have kubectl; then
  kubectl -n gateway get configmap kong-declarative-config -o jsonpath='{.data}' 2>/dev/null \
    | grep -oE 'realms/[a-zA-Z0-9_-]+' >/dev/null 2>&1
  kubectl -n gateway get configmap kong-declarative-config -o jsonpath='{.data.kong\.yml}' 2>/dev/null \
    | grep -nE 'key:\s*"http' | sed 's/^/  /' || \
  kubectl -n gateway get configmap kong-declarative-config -o yaml 2>/dev/null \
    | grep -nE 'key:\s*"?http' | sed 's/^/  /' || echo "  (không đọc được key issuer trong configmap)"
  echo "  >> So các key này với iss token (mục 2). Trùng thì Kong 403(OPA); lệch thì Kong 401."
else
  echo "(kubectl NOT FOUND)"
fi

sec "XONG — gửi lại nguyên file: $OUT"
