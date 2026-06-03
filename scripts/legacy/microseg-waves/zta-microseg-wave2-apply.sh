#!/usr/bin/env bash
# zta-microseg-wave2-apply.sh — Phase 2C wave 2
# Target ns (medium risk):
#   - cert-manager  (TLS issuance, validating webhook failurePolicy=Fail)
#   - spire         (workload SVID issuance, blocking = mTLS-wide outage)
#
# Apply: 17-cert-manager.yaml + 21-spire.yaml (đã refine theo flow baseline,
# có probe ingress 6080/9402/9403 (cert-manager) + 8080/8081/8083/9809 (spire)).
#
# Idempotent. Backup CNP cũ trong 2 ns.

set -uo pipefail
H(){ printf '\n========== %s ==========\n' "$*"; }

REPO=$HOME/projects/DATN
TS=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/zta-microseg-backups/$TS
LOG=/tmp/zta-microseg-wave2-$TS.log
exec > >(tee "$LOG") 2>&1
mkdir -p "$BACKUP"

CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
[ -z "$CILIUM" ] && { echo "FATAL: no cilium pod"; exit 1; }

# ----------------------------------------------------------------------------
H "0/6 Pre-check"

echo "  - Wave 1 ns CNP VALID:"
for ns in local-path-storage trivy-system; do
  kubectl -n $ns get cnp -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    | grep -v ' True' | grep -v "^NS " | sed 's/^/    /'
done
echo "    (empty = wave 1 vẫn OK)"

echo "  - cert-manager pod state:"
kubectl get pod -n cert-manager --no-headers 2>/dev/null | sed 's/^/    /'

echo "  - spire pod state:"
kubectl get pod -n spire --no-headers 2>/dev/null | sed 's/^/    /'

echo "  - Restart count trong cert-manager/spire 30 phút gần nhất (kỳ vọng: 0):"
for ns in cert-manager spire; do
  for p in $(kubectl -n $ns get pod -o jsonpath='{.items[*].metadata.name}'); do
    AGE=$(kubectl -n $ns get pod $p -o jsonpath='{.status.containerStatuses[*].lastState.terminated.finishedAt}')
    if [ -n "$AGE" ]; then echo "    $ns/$p lastTerm=$AGE"; fi
  done
done

echo "  - Drop trong cert-manager+spire 2 phút gần nhất (kỳ vọng: 0):"
for ns in cert-manager spire; do
  C=$(kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
      hubble observe --verdict DROPPED --since 2m --output compact -n $ns 2>/dev/null \
      | grep -v ICMPv6 | wc -l)
  echo "    $ns: $C non-ICMP drops"
done

echo
echo "  PRE-CHECK xong. Ctrl-C trong 5s nếu có gì bất thường."
sleep 5

# ----------------------------------------------------------------------------
H "1/6 Backup CNP hiện tại trong cert-manager + spire"
kubectl get cnp -n cert-manager -o yaml > "$BACKUP/cert-manager-cnp-before.yaml" 2>/dev/null || true
kubectl get cnp -n spire        -o yaml > "$BACKUP/spire-cnp-before.yaml"        2>/dev/null || true
echo "  Saved → $BACKUP/"

# ----------------------------------------------------------------------------
H "2/6 Apply 17-cert-manager.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/17-cert-manager.yaml"

H "3/6 Apply 21-spire.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/21-spire.yaml"

# ----------------------------------------------------------------------------
H "4/6 Verify CNP VALID=True"
sleep 5
for ns in cert-manager spire; do
  echo "  ns=$ns:"
  kubectl -n $ns get cnp -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    | sed 's/^/    /'
done

# ----------------------------------------------------------------------------
H "5/6 Watch Hubble drop 5 phút (kỳ vọng: chỉ IPv6 NDP)"

# Capture into temp files để có thể đếm sau
DROPS_CM=$BACKUP/drops-cert-manager.log
DROPS_SP=$BACKUP/drops-spire.log
: > "$DROPS_CM"; : > "$DROPS_SP"

timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n cert-manager 2>&1 \
    > "$DROPS_CM" &
PID1=$!

timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n spire 2>&1 \
    > "$DROPS_SP" &
PID2=$!

wait $PID1 $PID2 2>/dev/null || true

echo "  cert-manager drops (non-ICMP):"
grep -v ICMPv6 "$DROPS_CM" | head -30 | sed 's/^/    /'
echo "  spire drops (non-ICMP):"
grep -v ICMPv6 "$DROPS_SP" | head -30 | sed 's/^/    /'

CM_BAD=$(grep -v ICMPv6 "$DROPS_CM" | wc -l)
SP_BAD=$(grep -v ICMPv6 "$DROPS_SP" | wc -l)

# ----------------------------------------------------------------------------
H "6/6 Pod state + restart sau apply"
for ns in cert-manager spire; do
  echo "  ns=$ns:"
  kubectl get pod -n $ns --no-headers 2>/dev/null | sed 's/^/    /'
done

# ----------------------------------------------------------------------------
H "KẾT LUẬN"
echo "Log: $LOG"
echo "Backup: $BACKUP/"
echo "cert-manager non-ICMP drops in 5 min: $CM_BAD"
echo "spire        non-ICMP drops in 5 min: $SP_BAD"
echo
if [ "$CM_BAD" -eq 0 ] && [ "$SP_BAD" -eq 0 ]; then
  echo "✓ WAVE 2 OK — không có drop hợp pháp. Sẵn sàng wave 3 (gatekeeper + cosign)."
else
  echo "⚠️  Còn drop — gửi log cho mình review trước khi tiếp."
  echo
  echo "Rollback nếu cần:"
  echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/17-cert-manager.yaml"
  echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/21-spire.yaml"
fi
echo
echo "Test cert-manager admission (tùy chọn — sẽ verify webhook reachable):"
echo "  kubectl apply -f - <<EOF"
echo "  apiVersion: cert-manager.io/v1"
echo "  kind: Certificate"
echo "  metadata: { name: cnp-test, namespace: default }"
echo "  spec:"
echo "    secretName: cnp-test-tls"
echo "    issuerRef: { name: <issuer-name>, kind: Issuer }"
echo "    dnsNames: [test.local]"
echo "  EOF"
