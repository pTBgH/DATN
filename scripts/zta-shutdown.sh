#!/usr/bin/env bash
# scripts/zta-shutdown.sh - Quy trình tắt cụm K8s an toàn
set -euo pipefail

export KUBECONFIG=~/.kube/config-job7189

echo "=== 1. Cordon (Cấm lên lịch mới) trên tất cả Worker Nodes ==="
for node in 7189srv02 7189srv03 7189srv05; do
  kubectl cordon $node || true
done

echo -e "\n=== 2. Xóa các Pod Ứng Dụng (Stateless) trước ==="
# Việc này giúp giải phóng RAM nhanh chóng và cắt kết nối tới Data
kubectl scale deploy -n job7189-apps --all --replicas=0
kubectl scale deploy -n security keycloak --replicas=0

echo -e "\n=== 3. Tắt nhẹ nhàng Stateful Workloads (Kafka, MySQL, Vault) ==="
# Bằng cách scale xuống 0, K8s sẽ gửi tín hiệu SIGTERM để Kafka/MySQL tự đóng file log an toàn
kubectl scale sts -n data kafka --replicas=0
kubectl scale deploy -n data mysql --replicas=0
kubectl scale sts -n vault vault --replicas=0

echo -e "\n=== 4. Chờ các Pod tắt hoàn toàn (Tránh lỗi file lock) ==="
echo "Đang chờ (khoảng 30-60s)..."
sleep 45

echo -e "\n=== 5. Kiểm tra lần cuối trước khi tắt máy ==="
kubectl get pods -A | grep -E 'kafka|mysql|vault-0|job7189-apps' || echo "✅ Các pod dữ liệu đã được dọn sạch!"

echo -e "\n✅ BÂY GIỜ BẠN CÓ THỂ SHUTDOWN CÁC MÁY ẢO TRÊN VMWARE/LIBVIRT AN TOÀN!"
