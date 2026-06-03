#!/usr/bin/env bash
# zta-prefix-apply.sh — apply 2 fix tồn đọng TRƯỚC khi mở wave 1.
#
# 1. 00-default-deny.yaml (job7189-apps default-deny-all VALID=False)
# 2. 10-data.yaml (allow-apps-egress-kafka — 5 service Laravel đang DROP Kafka)
#
# An toàn: backup state hiện tại → apply → verify VALID=True → watch 2 phút.
# Idempotent, KHÔNG xoá CNP.

set -uo pipefail
H(){ printf '\n========== %s ==========\n' "$*"; }

REPO=$HOME/projects/DATN
TS=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/zta-prefix-backups/$TS
LOG=/tmp/zta-prefix-$TS.log
exec > >(tee "$LOG") 2>&1

mkdir -p "$BACKUP"
H "Backup CNP hiện tại → $BACKUP"
kubectl get cnp -A -o yaml > "$BACKUP/cnp-before.yaml"
kubectl get cnp -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' > "$BACKUP/cnp-status-before.txt"
echo "  Saved cnp-before.yaml + cnp-status-before.txt"

H "TRƯỚC fix — VALID=False CNP"
grep -v ' True' "$BACKUP/cnp-status-before.txt" | grep -v "^NS " || echo "(none)"

H "Apply 1/2 — 00-default-deny.yaml (fix VALID=False)"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/00-default-deny.yaml"

H "Apply 2/2 — 10-data.yaml (kafka egress allow + mysql + redis ingress)"
kubectl apply -f "$REPO/infras/k8s-yaml/cilium-policies/namespaces/10-data.yaml"

H "Đợi 5s rồi verify CNP VALID"
sleep 5
kubectl get cnp -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' > "$BACKUP/cnp-status-after.txt"

H "SAU fix — VALID=False CNP (kỳ vọng: empty)"
grep -v ' True' "$BACKUP/cnp-status-after.txt" | grep -v "^NS " || echo "(none) — TẤT CẢ VALID=True"

H "Kiểm tra allow-apps-egress-kafka đã tồn tại"
kubectl -n job7189-apps get cnp allow-apps-egress-kafka -o jsonpath='{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Valid")].status}{"\n"}' 2>/dev/null || echo "(NOT FOUND — apply failed)"

H "Watch Hubble drop trong job7189-apps 2 phút (kỳ vọng: kafka drop ngừng)"
CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
timeout 120 kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 5s --follow --output compact -n job7189-apps 2>&1 \
    | head -40 || true

H "Pod state sau apply"
kubectl get pod -n job7189-apps -n data --no-headers 2>/dev/null \
  | awk '$4!="Running" && $4!="Completed" {print}' || echo "(all healthy)"

H "Kafka SYN drop trong 30s gần nhất (kỳ vọng: 0)"
kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 30s --output compact 2>&1 \
    | grep -c "kafka-0:9092" || true

H "KẾT LUẬN"
echo "Log: $LOG"
echo "Backup: $BACKUP/cnp-status-before.txt + cnp-status-after.txt"
echo
echo "Nếu:"
echo "  ✓ Mọi CNP VALID=True"
echo "  ✓ allow-apps-egress-kafka tồn tại + VALID=True"
echo "  ✓ Hubble không còn drop kafka-0:9092"
echo "→ OK, mình gửi script wave-1 (22-local-path + 24-trivy)."
echo
echo "Nếu vẫn còn drop kafka → có thể app cần restart pod để refresh DNS/conntrack:"
echo "  kubectl -n job7189-apps rollout restart deploy"
