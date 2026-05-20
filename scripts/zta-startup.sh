#!/usr/bin/env bash
# scripts/zta-startup.sh - Quy trình đánh thức cụm K8s
set -euo pipefail

export KUBECONFIG=~/.kube/config-job7189

echo "=== 1. Uncordon (Cho phép lên lịch) tất cả Worker Nodes ==="
for node in 7189srv02 7189srv03 7189srv05; do
  kubectl uncordon $node || true
done

echo -e "\n=== 2. Đánh thức Data Tier (MySQL, Kafka, Vault) ==="
kubectl scale deploy -n data mysql --replicas=1
kubectl scale sts -n data kafka --replicas=1
kubectl scale sts -n vault vault --replicas=1

echo "Chờ 30s cho Pod được tạo..."
sleep 30

echo -e "\n=== 3. MỞ KHÓA VAULT (BẮT BUỘC) ==="
cd ~/projects/DATN
KEY1=$(jq -r '.unseal_keys_b64[0]' infras/k8s-yaml/vault-scripts/vault-prod-init.json)
kubectl exec -n vault vault-0 -- vault operator unseal "$KEY1" >/dev/null 2>&1
kubectl exec -n vault vault-0 -- vault status | grep -E "Sealed|Initialized"

echo -e "\n=== 4. Đánh thức Ứng Dụng (Laravel, Keycloak) ==="
kubectl scale deploy -n job7189-apps --all --replicas=1
kubectl scale deploy -n security keycloak --replicas=1

echo -e "\n=== 5. Dọn dẹp Zombie (Nếu có do mạng lag) ==="
kubectl get pod -A | grep -E 'Unknown|NodeLost' | awk '{print "kubectl delete pod " $2 " -n " $1 " --grace-period=0 --force"}' | sh 2>/dev/null || true

echo -e "\n✅ HỆ THỐNG ĐÃ SẴN SÀNG! Dùng 'kubectl get pods -A -w' để theo dõi."
