#!/usr/bin/env bash
# zta-microseg-wave1-apply.sh — Phase 2C wave 1
# Target ns (rủi ro thấp nhất, ít flow):
#   - local-path-storage   (1 src pod, chỉ egress :6443 apiserver)
#   - trivy-system         (không có flow trong baseline)
#
# Apply: 22-local-path-storage.yaml + 24-trivy-system.yaml
# Sau apply → watch Hubble 5 phút, in drop nếu có.
#
# Idempotent. KHÔNG xoá CNP cũ (chỉ apply, không delete).
 
set -uo pipefail
H(){ printf '\n========== %s ==========\n' "$*"; }
 
REPO=$HOME/projects/DATN
TS=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/zta-microseg-backups/$TS
LOG=/tmp/zta-microseg-wave1-$TS.log
exec > >(tee "$LOG") 2>&1
mkdir -p "$BACKUP"
 
CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
[ -z "$CILIUM" ] && { echo "FATAL: no cilium pod"; exit 1; }
 
# ----------------------------------------------------------------------------
H "0/5 Pre-check"
 
echo "  - default-deny-all VALID:"
kubectl -n job7189-apps get cnp default-deny-all \
  -o jsonpath='{.status.conditions[?(@.type=="Valid")].status}{"\n"}'
 
echo "  - Pod NotReady toàn cluster (top 10):"
kubectl get pod -A --no-headers 2>/dev/null \
  | awk '$4!="Running" && $4!="Completed" {print}' | head -10
echo "    (empty = OK)"
 
echo "  - Kafka drop trong 1 phút (kỳ vọng: 0):"
KAFKA_DROP=$(kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 1m --output compact 2>/dev/null \
    | grep -c "kafka-0:9092" || true)
echo "    $KAFKA_DROP"
if [ "$KAFKA_DROP" -gt 0 ]; then
  echo "  ⚠️  Còn kafka drop — ABORT. Restart pod để refresh conntrack:"
  echo "     kubectl -n job7189-apps rollout restart deploy"
  exit 2
fi
 
echo "  - Drop trong job7189-apps 2 phút gần nhất (kỳ vọng: 0 hoặc chỉ IPv6 NDP):"
kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 2m --output compact -n job7189-apps 2>/dev/null \
    | head -10
echo "    (nếu có drop khác kafka/ICMPv6 → ABORT bằng Ctrl-C trong 5s)"
sleep 5
 
# ----------------------------------------------------------------------------
H "1/5 Backup CNP hiện tại trong 2 ns"
kubectl get cnp -n local-path-storage -o yaml > "$BACKUP/local-path-storage-cnp-before.yaml" 2>/dev/null || true
kubectl get cnp -n trivy-system -o yaml > "$BACKUP/trivy-system-cnp-before.yaml" 2>/dev/null || true
echo "  Saved → $BACKUP/"
 
# ----------------------------------------------------------------------------
H "2/5 Apply 22-local-path-storage.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/22-local-path-storage.yaml"
 
H "3/5 Apply 24-trivy-system.yaml"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/24-trivy-system.yaml"
 
# ----------------------------------------------------------------------------
H "4/5 Verify CNP VALID=True"
sleep 5
for ns in local-path-storage trivy-system; do
  echo "  ns=$ns:"
  kubectl -n $ns get cnp -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
    | sed 's/^/    /'
done
 
# ----------------------------------------------------------------------------
H "5/5 Watch Hubble 5 phút (kỳ vọng: chỉ drop IPv6 NDP, không drop traffic hợp pháp)"
echo "  Drop trong local-path-storage:"
timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n local-path-storage 2>&1 \
    | head -30 &
PID1=$!
 
echo "  Drop trong trivy-system:"
timeout 300 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n trivy-system 2>&1 \
    | head -30 &
PID2=$!
 
wait $PID1 $PID2 2>/dev/null || true
 
# ----------------------------------------------------------------------------
H "Pod state sau apply"
for ns in local-path-storage trivy-system; do
  echo "  ns=$ns:"
  kubectl get pod -n $ns --no-headers 2>/dev/null | sed 's/^/    /' || echo "    (no pods)"
done
 
H "KẾT LUẬN"
echo "Log: $LOG"
echo "Backup: $BACKUP/"
echo
echo "Nếu:"
echo "  ✓ Mọi CNP mới VALID=True"
echo "  ✓ Pod 2 ns vẫn Running"
echo "  ✓ Không có drop của flow hợp pháp"
echo "→ OK, mình gửi script wave-2 (17-cert-manager + 21-spire)."
echo
echo "Nếu có drop bất thường (vd pod liveness probe fail) → ROLLBACK:"
echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/22-local-path-storage.yaml"
echo "  kubectl delete -f $REPO/infras/k8s-yaml/cilium-policies/namespaces/24-trivy-system.yaml"
