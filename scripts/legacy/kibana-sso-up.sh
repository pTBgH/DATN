#!/usr/bin/env bash
# kibana-sso-up.sh — bật Đường 3: truy cập Kibana qua nginx ingress + oauth2-proxy + Keycloak.
#
# Chain:
#   browser → http://kibana.job7189.local/
#          → nginx ingress (ns=monitoring, host=kibana.job7189.local)
#          → annotation auth-url -> oauth2-proxy.security
#          → Keycloak realm 7189_internal  (login + role internal-tools-access)
#          → oauth2-proxy validate -> nginx pass qua svc/kibana
#
# Script này:
#   1. Verify ingress-nginx controller running
#   2. Ensure oauth2-proxy deployment up trong ns=security
#   3. Verify Keycloak realm 7189_internal có thể reach từ oauth2-proxy pod
#   4. Verify nginx Ingress `ingress-kibana` exist (host kibana.job7189.local)
#   5. (tuỳ chọn) tạo user `kibana-admin / dev1234` trong realm 7189_internal có role internal-tools-access
#   6. In ra dòng /etc/hosts cần thêm trên máy bạn
#
# Usage:
#   bash kibana-sso-up.sh                  # bật + show
#   bash kibana-sso-up.sh --create-user    # bật + tạo user mới (nếu chưa có)
#   bash kibana-sso-up.sh --status         # chỉ show không sửa gì

set -uo pipefail

ACTION="${1:-up}"
KC_NS="${KC_NS:-security}"
OAUTH_NS="${OAUTH_NS:-security}"
INGRESS_NS_CANDIDATES=("ingress-nginx" "kube-system" "nginx-ingress")
REALM="${REALM:-7189_internal}"
ROLE="${ROLE:-internal-tools-access}"
NEW_USER="${NEW_USER:-kibana-admin}"
NEW_PASS="${NEW_PASS:-dev1234}"
KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"
KC_ADMIN_PASS="${KC_ADMIN_PASS:-admin}"
HOSTS=(kibana.job7189.local auth.job7189.local grafana.job7189.local db.job7189.local hubble.job7189.local)

bar() { echo; echo "──────────────────────────────────────────────────────────────────"; }
say() { echo "  · $*"; }
ok()  { echo "  ✓ $*"; }
warn(){ echo "  ⚠ $*"; }
err() { echo "  ✗ $*"; }

bar; echo "  1) Tìm ingress-nginx controller"; bar
INGRESS_NS=""
for ns in "${INGRESS_NS_CANDIDATES[@]}"; do
  if kubectl -n "$ns" get pod -l 'app.kubernetes.io/name=ingress-nginx' --no-headers 2>/dev/null | grep -q Running; then
    INGRESS_NS="$ns"; break
  fi
done
if [[ -z "$INGRESS_NS" ]]; then
  # fallback: grep
  INGRESS_NS="$(kubectl get pod -A | awk '/ingress-nginx-controller/ {print $1; exit}')"
fi
[[ -n "$INGRESS_NS" ]] && ok "ingress-nginx ns=$INGRESS_NS" || { err "không tìm thấy ingress-nginx controller pod"; exit 1; }

INGRESS_NODES="$(kubectl -n "$INGRESS_NS" get pod -l 'app.kubernetes.io/name=ingress-nginx' \
                  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort -u)"
echo "$INGRESS_NODES" | while read -r N; do
  [[ -z "$N" ]] && continue
  IP="$(kubectl get node "$N" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
  echo "    ingress controller on node $N  ip=$IP"
done

NODE_IP="$(kubectl -n "$INGRESS_NS" get pod -l 'app.kubernetes.io/name=ingress-nginx' \
            -o jsonpath='{.items[0].status.hostIP}' 2>/dev/null)"
[[ -z "$NODE_IP" ]] && NODE_IP="$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
ok "node IP để chỉ /etc/hosts: $NODE_IP"

bar; echo "  2) Ensure oauth2-proxy deployment (ns=$OAUTH_NS)"; bar
if ! kubectl -n "$OAUTH_NS" get deploy oauth2-proxy >/dev/null 2>&1; then
  warn "oauth2-proxy chưa được apply. Apply lại từ infras/k8s-yaml/ingress/04_oauth2_proxy.yaml"
  say "Bạn chạy: bash infras/k8s-yaml/ingress/00_setup_oauth2_proxy.sh"
  say "(00_setup tự patch hostAliases với IP Keycloak service hiện tại)"
  exit 2
fi

REPL="$(kubectl -n "$OAUTH_NS" get deploy oauth2-proxy -o jsonpath='{.spec.replicas}')"
if [[ "$REPL" == "0" ]]; then
  say "oauth2-proxy scaled=0 → scale lên 1"
  kubectl -n "$OAUTH_NS" scale deploy/oauth2-proxy --replicas=1
fi

# patch hostAliases với IP service Keycloak hiện tại (vì IP có thể đổi qua restart)
KC_SVC_IP="$(kubectl -n "$KC_NS" get svc keycloak -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)"
if [[ -n "$KC_SVC_IP" ]]; then
  CURRENT_ALIAS_IP="$(kubectl -n "$OAUTH_NS" get deploy oauth2-proxy \
    -o jsonpath='{.spec.template.spec.hostAliases[?(@.hostnames[0]=="auth.job7189.local")].ip}' 2>/dev/null)"
  if [[ "$CURRENT_ALIAS_IP" != "$KC_SVC_IP" ]]; then
    say "hostAliases auth.job7189.local: $CURRENT_ALIAS_IP → $KC_SVC_IP (patch)"
    kubectl -n "$OAUTH_NS" patch deploy oauth2-proxy --type=merge -p \
      "{\"spec\":{\"template\":{\"spec\":{\"hostAliases\":[{\"ip\":\"$KC_SVC_IP\",\"hostnames\":[\"auth.job7189.local\"]}]}}}}" >/dev/null
  else
    ok "hostAliases trùng KC svc IP ($KC_SVC_IP)"
  fi
fi

say "Đợi oauth2-proxy Ready (≤180s)..."
if kubectl -n "$OAUTH_NS" wait pod -l app=oauth2-proxy --for=condition=Ready --timeout=180s 2>/dev/null; then
  ok "oauth2-proxy Ready"
else
  err "oauth2-proxy chưa Ready — describe:"
  kubectl -n "$OAUTH_NS" describe pod -l app=oauth2-proxy | tail -25
  exit 3
fi

bar; echo "  3) Verify Keycloak realm $REALM"; bar
KC_POD="$(kubectl -n "$KC_NS" get pod -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [[ -z "$KC_POD" ]]; then err "Keycloak pod không thấy trong ns=$KC_NS"; exit 4; fi

REALM_CHECK="$(kubectl -n "$KC_NS" exec "$KC_POD" -- sh -c \
  "curl -sS -o /dev/null -w '%{http_code}' http://localhost:8080/realms/$REALM/.well-known/openid-configuration" 2>/dev/null)"
if [[ "$REALM_CHECK" == "200" ]]; then
  ok "realm $REALM reachable từ Keycloak pod (HTTP 200)"
else
  err "realm $REALM unreachable (HTTP=$REALM_CHECK)"
  warn "Import realm: kubectl -n $KC_NS exec $KC_POD -- /opt/keycloak/bin/kc.sh import --file /tmp/realm-infra.json"
  warn "Hoặc dùng ConfigMap: kubectl -n $KC_NS create cm keycloak-realm-config --from-file=realm-infra.json=infras/keycloak/realm-infra.json"
  exit 5
fi

bar; echo "  4) Verify ingress-kibana"; bar
if kubectl -n monitoring get ingress ingress-kibana >/dev/null 2>&1; then
  ok "ingress-kibana exists trong ns=monitoring"
else
  warn "Apply: kubectl apply -f infras/k8s-yaml/ingress/03_ingress_internal.yaml"
fi
if kubectl -n security get ingress ingress-oauth2-kibana >/dev/null 2>&1; then
  ok "ingress-oauth2-kibana exists (callback) trong ns=security"
else
  warn "Apply: kubectl apply -f infras/k8s-yaml/ingress/02_ingress_oauth2_callback.yaml"
fi

if [[ "$ACTION" == "--create-user" ]]; then
  bar; echo "  5) Tạo user $NEW_USER / $NEW_PASS với role $ROLE trong $REALM"; bar
  KCADM="/opt/keycloak/bin/kcadm.sh"
  EXEC="kubectl -n $KC_NS exec $KC_POD -- $KCADM"

  $EXEC config credentials --server http://localhost:8080 --realm master \
    --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASS" >/dev/null 2>&1 \
    && ok "kcadm login OK" || { err "kcadm login fail — env KC_ADMIN_USER/KC_ADMIN_PASS đúng chưa?"; exit 6; }

  # Tạo (idempotent) user
  if $EXEC get users -r "$REALM" -q username="$NEW_USER" 2>/dev/null | grep -q '"username"'; then
    ok "user $NEW_USER đã tồn tại"
  else
    $EXEC create users -r "$REALM" -s username="$NEW_USER" -s enabled=true -s emailVerified=true 2>/dev/null \
      && ok "Đã tạo user $NEW_USER"
  fi

  USER_ID="$($EXEC get users -r "$REALM" -q username="$NEW_USER" --fields id 2>/dev/null \
              | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d[0]["id"])' 2>/dev/null)"
  [[ -z "$USER_ID" ]] && { err "không lấy được user id"; exit 7; }
  say "user id: $USER_ID"

  $EXEC set-password -r "$REALM" --userid "$USER_ID" --new-password "$NEW_PASS" 2>/dev/null \
    && ok "đặt password $NEW_PASS"

  $EXEC add-roles -r "$REALM" --uusername "$NEW_USER" --rolename "$ROLE" 2>/dev/null \
    && ok "gán role $ROLE" || warn "(có thể đã có role)"
fi

bar; echo "  6) /etc/hosts cần có trên máy của bạn"; bar
echo "      Add dòng sau vào /etc/hosts (Linux/macOS) hoặc C:\\Windows\\System32\\drivers\\etc\\hosts (Windows):"
echo
for h in "${HOSTS[@]}"; do
  printf "      %s    %s\n" "$NODE_IP" "$h"
done
echo
echo "      Hoặc 1 dòng gộp:"
printf "      %s    %s\n" "$NODE_IP" "${HOSTS[*]}"

bar; echo "  7) Smoke test ingress chain"; bar
say "curl ingress controller -> /oauth2/start (phải 302 -> KC)"
CODE="$(curl -sS -o /dev/null -w '%{http_code}' --resolve kibana.job7189.local:80:"$NODE_IP" \
  http://kibana.job7189.local/oauth2/start 2>/dev/null)"
echo "    HTTP=$CODE  (302/303 = OK)"

say "curl Kibana qua ingress (chưa login) (phải 302 -> /oauth2/start)"
CODE="$(curl -sS -o /dev/null -w '%{http_code}' --resolve kibana.job7189.local:80:"$NODE_IP" \
  http://kibana.job7189.local/ 2>/dev/null)"
echo "    HTTP=$CODE  (302 = OK, redirect tới oauth2-proxy)"

bar; echo "  8) NEXT"; bar
cat <<EOF
  · Sau khi /etc/hosts đã đúng:
       open http://kibana.job7189.local/   (Chrome/Firefox)
  · Sẽ redirect đến KC realm $REALM:
       login bằng user có role $ROLE (mặc định: kibana-admin / dev1234 nếu vừa --create-user)
  · Vào Discover → Index Pattern → tạo: filebeat-*  (Time field: @timestamp)
  · Query mẫu (KQL):
       kubernetes.namespace : "job7189-apps" and message : "Application error"
       kubernetes.namespace : "job7189-apps" and (message : "401" or message : "exception")
       kubernetes.labels.app : "identity-service" and message : *SQL*
  · Nếu redirect không vòng đúng — kiểm tra:
       kubectl -n $OAUTH_NS logs -l app=oauth2-proxy --tail=50
       kubectl -n monitoring describe ingress ingress-kibana
EOF
