#!/usr/bin/env bash
# zta-microseg-wave3-apply.sh — Phase 2C wave 3 (HIGH RISK — admission webhooks)
# Target ns:
#   - gatekeeper-system     (Constraint admission, validating webhook)
#   - cosign-system         (Image signature admission, blocks unsigned pods,
#                            cần internet egress :443 cho Sigstore TUF)
#
# Apply: 19-gatekeeper-system.yaml + 18-cosign-system.yaml
# Pre-check thêm:
#   - Network sanity (ping, DNS, HTTPS, apiserver) — phát hiện mạng chập chờn
#   - failurePolicy của ValidatingWebhookConfiguration của 2 component
#   - Wave 1+2 ns vẫn OK
#   - Pod state hiện tại
# Auto KHÔNG rollback (để bạn quyết định) — nhưng sẽ in kết luận rõ ràng + lệnh rollback.

set -uo pipefail
H(){ printf '\n========== %s ==========\n' "$*"; }

REPO=$HOME/projects/DATN
TS=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/zta-microseg-backups/$TS
LOG=/tmp/zta-microseg-wave3-$TS.log
exec > >(tee "$LOG") 2>&1
mkdir -p "$BACKUP"

CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
[ -z "$CILIUM" ] && { echo "FATAL: no cilium pod"; exit 1; }

# ============================================================================
H "0/7 NETWORK SANITY (bạn yêu cầu — phát hiện mạng chập chờn)"
NET_OK=1
echo "  - ping 8.8.8.8 (3 pkts, 3s):"
if ! ping -c 3 -W 3 8.8.8.8 >/dev/null 2>&1; then
  echo "    FAIL"; NET_OK=0
else
  ping -c 3 -W 3 8.8.8.8 | tail -1 | sed 's/^/    /'
fi
echo "  - DNS google.com:"
if ! timeout 5 getent hosts google.com >/dev/null 2>&1; then
  echo "    FAIL"; NET_OK=0
else
  echo "    OK"
fi
echo "  - HTTPS google.com:"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://www.google.com 2>/dev/null || echo "ERR")
if [ "$HTTP" != "200" ] && [ "$HTTP" != "301" ] && [ "$HTTP" != "302" ]; then
  echo "    FAIL ($HTTP)"; NET_OK=0
else
  echo "    OK ($HTTP)"
fi
echo "  - apiserver healthz (kubectl --raw):"
if ! timeout 5 kubectl get --raw=/healthz >/dev/null 2>&1; then
  echo "    FAIL"; NET_OK=0
else
  echo "    OK"
fi

if [ "$NET_OK" -eq 0 ]; then
  echo
  echo "✗ NETWORK chập chờn — ABORT wave 3 (apply lúc này không an toàn)."
  echo "  Đợi network ổn rồi rerun script."
  exit 2
fi
echo "  ✓ Network OK"

# ============================================================================
H "1/7 Wave 1+2 ns vẫn OK?"
ALL_VALID=1
for ns in local-path-storage trivy-system cert-manager spire; do
  BAD=$(kubectl -n $ns get cnp -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    2>/dev/null | grep -v ' True' | grep -v "^NS " || true)
  if [ -n "$BAD" ]; then
    echo "  $ns BAD:"; echo "$BAD" | sed 's/^/    /'
    ALL_VALID=0
  fi
done
[ "$ALL_VALID" -eq 1 ] && echo "  ✓ Mọi CNP của wave 1+2 VALID=True"

echo "  Pod state cert-manager + spire + 2 ns target:"
for ns in cert-manager spire gatekeeper-system cosign-system; do
  echo "    --- $ns ---"
  kubectl get pod -n $ns --no-headers 2>/dev/null | sed 's/^/      /'
done

# ============================================================================
H "2/7 failurePolicy của ValidatingWebhookConfiguration (gatekeeper + cosign)"
echo "  Gatekeeper:"
kubectl get validatingwebhookconfiguration -o json 2>/dev/null \
  | jq -r '.items[] | select(.metadata.name | test("gatekeeper|constraint")) | "    \(.metadata.name)  failurePolicy=\(.webhooks[0].failurePolicy // "n/a")"' \
  || echo "    (không tìm thấy)"
echo "  Cosign / policy-controller:"
kubectl get validatingwebhookconfiguration -o json 2>/dev/null \
  | jq -r '.items[] | select(.metadata.name | test("policy-controller|cosign")) | "    \(.metadata.name)  failurePolicy=\(.webhooks[0].failurePolicy // "n/a")"' \
  || echo "    (không tìm thấy)"
echo
echo "  ⚠️  failurePolicy=Fail → nếu CNP block webhook callback, MỌI pod create/update bị reject."

echo
echo "  PRE-CHECK xong. Ctrl-C trong 7s nếu có gì bất thường."
sleep 7

# ============================================================================
H "3/7 Backup CNP hiện tại trong gatekeeper-system + cosign-system"
kubectl get cnp -n gatekeeper-system -o yaml > "$BACKUP/gatekeeper-cnp-before.yaml" 2>/dev/null || true
kubectl get cnp -n cosign-system     -o yaml > "$BACKUP/cosign-cnp-before.yaml"     2>/dev/null || true
echo "  Saved → $BACKUP/"

# ============================================================================
H "4/7 Apply 19-gatekeeper-system.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/19-gatekeeper-system.yaml"

H "4b/7 Apply 18-cosign-system.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/18-cosign-system.yaml"

# ============================================================================
H "5/7 Verify CNP VALID=True"
sleep 5
for ns in gatekeeper-system cosign-system; do
  echo "  ns=$ns:"
  kubectl -n $ns get cnp -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    | sed 's/^/    /'
done

# ============================================================================
H "6/7 Watch Hubble drop 5 phút (gồm cả test thử trigger webhook)"

DROPS_GK=$BACKUP/drops-gatekeeper.log
DROPS_CS=$BACKUP/drops-cosign.log
: > "$DROPS_GK"; : > "$DROPS_CS"

timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n gatekeeper-system 2>&1 \
    > "$DROPS_GK" &
PID1=$!

timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n cosign-system 2>&1 \
    > "$DROPS_CS" &
PID2=$!

# Trigger admission để chắc chắn webhook được gọi (tạo + xoá pod tạm)
echo "  Trigger admission webhook bằng pod tạm (sau 30s):"
sleep 30
kubectl run zta-wave3-trigger --image=busybox:1.37.0 --restart=Never --rm -i --command \
  --timeout=20s -- sh -c 'echo ok' >/dev/null 2>&1 \
  && echo "    ✓ pod create+delete thành công (webhook KHÔNG block)" \
  || echo "    ⚠️  pod create FAIL — có thể webhook đang block hoặc image kéo lâu"

wait $PID1 $PID2 2>/dev/null || true

echo "  gatekeeper-system drops (non-ICMP):"
grep -v ICMPv6 "$DROPS_GK" | head -30 | sed 's/^/    /'
echo "  cosign-system drops (non-ICMP):"
grep -v ICMPv6 "$DROPS_CS" | head -30 | sed 's/^/    /'

GK_BAD=$(grep -v ICMPv6 "$DROPS_GK" | wc -l)
CS_BAD=$(grep -v ICMPv6 "$DROPS_CS" | wc -l)

# ============================================================================
H "7/7 Pod state + restart sau apply"
for ns in gatekeeper-system cosign-system cert-manager spire; do
  echo "  ns=$ns:"
  kubectl get pod -n $ns --no-headers 2>/dev/null | sed 's/^/    /'
done

# ============================================================================
H "KẾT LUẬN"
echo "Log:    $LOG"
echo "Backup: $BACKUP/"
echo "gatekeeper-system non-ICMP drops in 5 min: $GK_BAD"
echo "cosign-system     non-ICMP drops in 5 min: $CS_BAD"
echo
if [ "$GK_BAD" -eq 0 ] && [ "$CS_BAD" -eq 0 ]; then
  echo "✓ WAVE 3 OK — không có drop hợp pháp. Sẵn sàng wave 4 (ingress-nginx)."
else
  echo "⚠️  Còn drop — gửi log cho mình review trước khi tiếp."
fi
echo
echo "Rollback nếu cần:"
echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/19-gatekeeper-system.yaml"
echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/18-cosign-system.yaml"
