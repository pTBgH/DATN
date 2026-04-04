#!/bin/bash
# Script tự động Rebuild Cluster cho đồ án job7189-zta-lab (Bản chuẩn)

set -e 

CLUSTER_NAME="job7189-zta-lab"
CILIUM_VERSION="1.19.1"

echo "🚀 [1/6] Đang dọn dẹp Cluster cũ (nếu còn)..."
kind delete cluster --name $CLUSTER_NAME || true

echo "🚀 [2/6] Khởi tạo Kind Cluster mới..."
kind create cluster --config infras/kind/kind-config.yaml --name $CLUSTER_NAME

echo "🚀 [3/6] Cài đặt Kubernetes Gateway API CRDs (Bắt buộc cho Kong)..."
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

echo "🚀 [4/6] Tải và Load Cilium Image vào các Node để cài đặt nhanh hơn..."
docker pull quay.io/cilium/cilium:v$CILIUM_VERSION
for node in ${CLUSTER_NAME}-control-plane ${CLUSTER_NAME}-worker ${CLUSTER_NAME}-worker2 ${CLUSTER_NAME}-worker3; do
  echo "   📦 Loading image vào node: $node"
  kind load docker-image quay.io/cilium/cilium:v$CILIUM_VERSION --name $CLUSTER_NAME --nodes $node
done

echo "🚀 [5/6] Triển khai Cilium CNI (Sử dụng cấu hình chuẩn của bạn)..."
# Lệnh Helm bây giờ cực kỳ gọn gàng, phó thác hoàn toàn cho file cilium-values.yaml siêu xịn của bạn
helm upgrade --install cilium cilium/cilium --version $CILIUM_VERSION \
  --namespace kube-system \
  -f k8s-management/cilium/cilium-values.yaml \
  --set image.pullPolicy=IfNotPresent

echo "🚀 [6/6] Đang khởi tạo bộ khung Namespaces & Secret Core..."
for ns in gateway security management data job7189-app monitoring job7189-infra; do
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $ns
EOF
done

# Cài đặt Cert-Manager (Cần thiết cho hệ thống)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Cấp Secret tĩnh cho OAuth2 Proxy
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-secret=8iAntNwXzjJUSbw1m1tHpM3JigJUTeAE \
  -n management || echo "Secret đã tồn tại"

echo "🎉 HOÀN TẤT! Nền móng mạng Cilium đã chạy thành công mà không sợ rớt SSH."
