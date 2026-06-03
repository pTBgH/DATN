#!/usr/bin/env bash
# zta-microseg-wave5-apply.sh — Phase 2C wave 5 (CUỐI)
# Target ns:
#   - kube-system  (CHỈ 3 allow rule cho CoreDNS — KHÔNG có default-deny)
#
# Apply: 23-kube-system.yaml
# An toàn cao: file này CỐ Ý không áp default-deny lên kube-system.
# Pod không match rule nào (cilium-agent hostNetwork, kube-proxy,
# kube-apiserver static pods) sẽ giữ default-allow Cilium native.

set -uo pipefail
H(){ printf '\n========== %s ==========\n' "$*"; }

REPO=$HOME/projects/DATN
TS=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/zta-microseg-backups/$TS
LOG=/tmp/zta-microseg-wave5-$TS.log
exec > >(tee "$LOG") 2>&1
mkdir -p "$BACKUP"

CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
[ -z "$CILIUM" ] && { echo "FATAL: no cilium pod"; exit 1; }

# ============================================================================
H "0/7 NETWORK SANITY"
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
H "1/7 Wave 1+2+3+4 ns vẫn OK?"
ALL_VALID=1
for ns in local-path-storage trivy-system cert-manager spire gatekeeper-system cosign-system ingress-nginx; do
  BAD=$(kubectl -n $ns get cnp -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    2>/dev/null | grep -v ' True' | grep -v "^NS " || true)
  [ -n "$BAD" ] && { echo "  $ns BAD:"; echo "$BAD" | sed 's/^/    /'; ALL_VALID=0; }
done
[ "$ALL_VALID" -eq 1 ] && echo "  ✓ Mọi CNP wave 1-4 VALID=True"

# ============================================================================
H "2/7 Sanity check trước apply"
echo "  CoreDNS pod state:"
kubectl -n kube-system get pod -l k8s-app=kube-dns --no-headers | sed 's/^/    /'

echo "  DNS resolve trong cluster (busybox in default):"
kubectl run zta-dns-test --image=busybox:1.37.0 --restart=Never --rm -i --command \
  --timeout=20s -- sh -c 'nslookup kubernetes.default.svc.cluster.local 2>&1 | head -8; echo; nslookup google.com 2>&1 | head -5' \
  2>&1 | grep -vE "^(pod default/zta-dns-test|Flag|If you don)" || true

echo "  DNS drops trong kube-system 2 phút gần nhất (kỳ vọng: 0):"
kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
  hubble observe --verdict DROPPED --since 2m --output compact -n kube-system 2>&1 \
  | grep -v ICMPv6 | head -10 | sed 's/^/    /'

echo
echo "  PRE-CHECK xong. Ctrl-C trong 5s nếu có gì bất thường."
sleep 5

# ============================================================================
H "3/7 Backup CNP hiện tại trong kube-system"
kubectl get cnp -n kube-system -o yaml > "$BACKUP/kube-system-cnp-before.yaml" 2>/dev/null || true
echo "  Saved → $BACKUP/"

# ============================================================================
H "4/7 Apply 23-kube-system.yaml"
echo "  Note: file này CỐ Ý KHÔNG có default-deny — chỉ 3 allow rule cho CoreDNS"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/23-kube-system.yaml"

# ============================================================================
H "5/7 Verify CNP VALID=True"
sleep 5
kubectl -n kube-system get cnp -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
  | sed 's/^/  /'

# ============================================================================
H "6/7 Watch Hubble drop 3 phút + DNS resolve test giữa watch"

DROPS_KS=$BACKUP/drops-kube-system.log
: > "$DROPS_KS"

timeout 180 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n kube-system 2>&1 \
    > "$DROPS_KS" &
PID1=$!

echo "  DNS test sau apply (3 lần cách 30s):"
for i in 1 2 3; do
  sleep 30
  echo "  --- vòng $i (t=+$((i*30))s) ---"
  out=$(kubectl run "zta-dns-test-$i" --image=busybox:1.37.0 --restart=Never --rm -i --command \
    --timeout=20s -- sh -c 'nslookup kubernetes.default.svc.cluster.local 2>&1 | grep -E "Server|Address" | head -4' \
    2>&1 | grep -vE "^(pod default/|Flag|If you don)" | head -8)
  echo "$out" | sed 's/^/    /'
done

# Watch tiếp ~60s
sleep 60
wait $PID1 2>/dev/null || true

echo
echo "  kube-system drops (non-ICMP, top 30):"
grep -v ICMPv6 "$DROPS_KS" | head -30 | sed 's/^/    /'
KS_BAD=$(grep -v ICMPv6 "$DROPS_KS" | wc -l)

# ============================================================================
H "7/7 Pod state — CoreDNS + critical kube-system"
kubectl -n kube-system get pod | grep -E "coredns|cilium|kube-apiserver|kube-controller|kube-scheduler|etcd|hubble" | sed 's/^/  /'

# ============================================================================
H "KẾT LUẬN"
echo "Log:    $LOG"
echo "Backup: $BACKUP/"
echo "kube-system non-ICMP drops in 3 min: $KS_BAD"
echo
if [ "$KS_BAD" -eq 0 ]; then
  echo "✓ WAVE 5 OK — không có drop, DNS resolve OK."
  echo "  Phase 2C HOÀN TẤT — 8 namespaces được microsegment + 1 ns được audit-only."
  echo
  echo "Next steps:"
  echo "  - 24h observation period — monitor Hubble drops + pod restart"
  echo "  - Audit kube-system flows from Hubble → craft per-workload allow rule"
  echo "  - Khi sẵn sàng: tạo 24-kube-system-default-deny.yaml (separate file)"
else
  echo "⚠️  Có drop trong kube-system — gửi log cho mình review NGAY (kube-system rất nhạy)."
fi
echo
echo "Rollback nếu cần:"
echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/23-kube-system.yaml"
