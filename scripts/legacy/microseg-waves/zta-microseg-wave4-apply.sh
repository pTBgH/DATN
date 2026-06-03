#!/usr/bin/env bash
# zta-microseg-wave4-apply.sh — Phase 2C wave 4 (NORTH-SOUTH risk)
# Target ns:
#   - ingress-nginx (controller, terminates external HTTP/HTTPS — chặn = mọi
#                    user thật mất truy cập app)
#
# Apply: 20-ingress-nginx.yaml
# Đặc biệt:
#   - Pre-check upstream labels (gateway/security/management/monitoring) có khớp
#     với selector trong YAML không. Nếu mismatch → ingress proxy 502 → ABORT.
#   - Smoke test bằng curl Host: theo các vhost trong 99-ingress.yaml trước & sau.

set -uo pipefail
H(){ printf '\n========== %s ==========\n' "$*"; }

REPO=$HOME/projects/DATN
TS=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/zta-microseg-backups/$TS
LOG=/tmp/zta-microseg-wave4-$TS.log
exec > >(tee "$LOG") 2>&1
mkdir -p "$BACKUP"

CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
[ -z "$CILIUM" ] && { echo "FATAL: no cilium pod"; exit 1; }

# ============================================================================
H "0/8 NETWORK SANITY"
NET_OK=1
for cmd in "ping -c 3 -W 3 8.8.8.8" "getent hosts google.com" \
           "curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://www.google.com" \
           "kubectl get --raw=/healthz"; do
  if ! timeout 7 sh -c "$cmd" >/dev/null 2>&1; then
    echo "  FAIL: $cmd"; NET_OK=0
  else
    echo "  OK:   $cmd"
  fi
done
[ "$NET_OK" -eq 0 ] && { echo; echo "✗ NETWORK chập chờn — ABORT"; exit 2; }

# ============================================================================
H "1/8 Wave 1+2+3 ns vẫn OK?"
ALL_VALID=1
for ns in local-path-storage trivy-system cert-manager spire gatekeeper-system cosign-system; do
  BAD=$(kubectl -n $ns get cnp -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    2>/dev/null | grep -v ' True' | grep -v "^NS " || true)
  [ -n "$BAD" ] && { echo "  $ns BAD:"; echo "$BAD" | sed 's/^/    /'; ALL_VALID=0; }
done
[ "$ALL_VALID" -eq 1 ] && echo "  ✓ Mọi CNP wave 1+2+3 VALID=True"

# ============================================================================
H "2/8 Cross-check upstream selector vs pod label thật"
declare -A UPSTREAMS=(
  [gateway]="any"
  [security:keycloak]="app=keycloak"
  [security:oauth2-proxy]="app=oauth2-proxy"
  [management:phpmyadmin]="app=phpmyadmin"
  [monitoring:kibana]="app=kibana"
  [monitoring:grafana]="app=grafana"
  [monitoring:elasticsearch]="app=elasticsearch"
)
UPSTREAM_OK=1
for key in "${!UPSTREAMS[@]}"; do
  ns="${key%:*}"; selapp="${UPSTREAMS[$key]}"
  if [ "$selapp" = "any" ]; then
    cnt=$(kubectl -n "$ns" get pod --no-headers 2>/dev/null | grep -c Running || true)
    echo "  $ns: $cnt Running pods (any label) — selector match expected"
    continue
  fi
  cnt=$(kubectl -n "$ns" get pod -l "$selapp" --no-headers 2>/dev/null | grep -c Running || true)
  if [ "$cnt" -eq 0 ]; then
    echo "  ✗ $ns ($selapp): 0 pod match — upstream sẽ KHÔNG nhận traffic"
    UPSTREAM_OK=0
  else
    echo "  ✓ $ns ($selapp): $cnt Running pod match"
  fi
done

if [ "$UPSTREAM_OK" -eq 0 ]; then
  echo
  echo "⚠️  Có upstream KHÔNG có pod match label \`app=…\` trong selector."
  echo "    Nếu apply, traffic ingress → upstream đó sẽ bị default-deny chặn."
  echo "    ABORT — sửa selector trong 20-ingress-nginx.yaml trước."
  exit 3
fi

# ============================================================================
H "3/8 Smoke test ingress TRƯỚC apply (curl --resolve nội bộ qua node)"
NODEIP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
HOSTS=$(kubectl get ingress -A -o jsonpath='{range .items[*]}{.spec.rules[*].host}{"\n"}{end}' | sort -u | grep -v '^$' | head -10)
echo "  NodeIP=$NODEIP"
echo "  Ingress hosts test (top 10):"
for host in $HOSTS; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    --resolve "${host}:80:${NODEIP}" "http://${host}/" 2>&1 || echo "ERR")
  printf "    %-40s HTTP %s\n" "$host" "$code"
done

# ============================================================================
H "4/8 Backup CNP hiện tại trong ingress-nginx"
kubectl get cnp -n ingress-nginx -o yaml > "$BACKUP/ingress-nginx-cnp-before.yaml" 2>/dev/null || true
echo "  Saved → $BACKUP/"

echo
echo "  PRE-CHECK xong. Ctrl-C trong 10s nếu có gì bất thường."
sleep 10

# ============================================================================
H "5/8 Apply 20-ingress-nginx.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/20-ingress-nginx.yaml"

# ============================================================================
H "6/8 Verify CNP VALID=True"
sleep 5
kubectl -n ingress-nginx get cnp -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
  | sed 's/^/  /'

# ============================================================================
H "7/8 Watch Hubble drop 5 phút + smoke test ingress giữa watch"

DROPS_IN=$BACKUP/drops-ingress-nginx.log
: > "$DROPS_IN"

timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n ingress-nginx 2>&1 \
    > "$DROPS_IN" &
PID1=$!

echo "  Smoke test ingress SAU apply (mỗi 30s, 3 lần):"
for i in 1 2 3; do
  sleep 30
  echo "  --- vòng $i (t=+$((i*30))s) ---"
  for host in $HOSTS; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
      --resolve "${host}:80:${NODEIP}" "http://${host}/" 2>&1 || echo "ERR")
    printf "    %-40s HTTP %s\n" "$host" "$code"
  done
done

# Watch tiếp ~210s nữa
sleep 210
wait $PID1 2>/dev/null || true

echo
echo "  ingress-nginx drops (non-ICMP, top 30):"
grep -v ICMPv6 "$DROPS_IN" | head -30 | sed 's/^/    /'
IN_BAD=$(grep -v ICMPv6 "$DROPS_IN" | wc -l)

# ============================================================================
H "8/8 Pod state + restart sau apply"
for ns in ingress-nginx gateway security management monitoring; do
  echo "  ns=$ns:"
  kubectl get pod -n $ns --no-headers 2>/dev/null | head -10 | sed 's/^/    /'
done

# ============================================================================
H "KẾT LUẬN"
echo "Log:    $LOG"
echo "Backup: $BACKUP/"
echo "ingress-nginx non-ICMP drops in 5 min: $IN_BAD"
echo
if [ "$IN_BAD" -eq 0 ]; then
  echo "✓ WAVE 4 OK — không có drop hợp pháp."
  echo "  Kiểm tra smoke test ở mục 7/8 — mọi vhost vẫn HTTP 200/302/401 (auth) là OK."
  echo "  Nếu HTTP 5xx hoặc connection refused → có vấn đề upstream."
  echo "  Sẵn sàng wave 5 (kube-system DNS only, an toàn)."
else
  echo "⚠️  Còn drop — gửi log cho mình review."
fi
echo
echo "Rollback nếu cần:"
echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/20-ingress-nginx.yaml"
