#!/bin/bash
# ==========================================
# Script 2: Initialize vault-prod
# Chỉ chạy 1 lần duy nhất khi mới deploy
# ==========================================

set -e

echo "==> Chờ vault-0 pod ở trạng thái Running (không cần ready)..."
until kubectl get pod vault-0 -n vault 2>/dev/null | grep -q "Running"; do
  echo "    vault-0 chưa Running, đợi 3s..."
  sleep 3
done
echo "    vault-0 đang Running!"

echo "==> Đợi thêm 10s để vault-0 kết nối vault-dev..."
sleep 10

echo "==> Kiểm tra vault-0 đã init chưa..."
INIT_STATUS=$(kubectl exec -n vault vault-0 -- \
  sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
  vault status -format=json 2>/dev/null" || echo "{}")

if echo "$INIT_STATUS" | grep -q '"initialized":true'; then
  echo "    vault-prod đã được init rồi, bỏ qua."
  exit 0
fi

echo "==> Khởi tạo vault-prod..."
INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- \
  sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
  vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json")

echo "$INIT_OUTPUT" > vault-prod-init.json

ROOT_TOKEN=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['root_token'])")

echo ""
echo "==> Init hoàn tất!"
echo "    Root token đã lưu vào: vault-prod-init.json"
echo "    QUAN TRỌNG: Giữ file này an toàn!"
echo ""
echo "==> Chờ vault-0 tự unseal và ready..."
sleep 5
kubectl get pod -n vault
