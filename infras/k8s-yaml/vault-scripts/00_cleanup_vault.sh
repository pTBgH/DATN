#!/bin/bash
# ==========================================
# Script dọn sạch Vault — reset hoàn toàn
# Dùng khi muốn cài lại từ đầu
# ==========================================

set -e

echo "╔══════════════════════════════════════╗"
echo "║        VAULT CLEANUP SCRIPT          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "⚠️  Script này sẽ XÓA TOÀN BỘ:"
echo "   - vault-0 pod + PVC (mất hết data)"
echo "   - vault-dev deployment"
echo "   - certificates + secrets TLS"
echo "   - vault-agent Helm release (Injector)"
echo "   - file vault-prod-init.json"
echo ""
read -p "Bạn chắc chắn muốn xóa? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Hủy bỏ."
  exit 0
fi

echo ""
echo "==> [1/8] Xóa vault StatefulSet và Deployment..."
kubectl delete statefulset vault -n vault --ignore-not-found=true
kubectl delete deployment vault-dev -n vault --ignore-not-found=true

echo "==> [2/8] Xóa Services..."
kubectl delete service vault -n vault --ignore-not-found=true
kubectl delete service vault-dev -n vault --ignore-not-found=true

echo "==> [3/8] Xóa ConfigMap..."
kubectl delete configmap vault-config -n vault --ignore-not-found=true

echo "==> [4/8] Xóa ServiceAccounts + RBAC..."
kubectl delete serviceaccount vault -n vault --ignore-not-found=true
kubectl delete serviceaccount vault-dev -n vault --ignore-not-found=true
kubectl delete clusterrolebinding vault-server-binding --ignore-not-found=true

echo "==> [5/8] Xóa PVC (data vault-prod)..."
kubectl delete pvc vault-data -n vault --ignore-not-found=true

echo "==> [6/8] Xóa TLS certificates và secrets..."
kubectl delete certificate vault-ca -n vault --ignore-not-found=true
kubectl delete certificate vault-server-tls -n vault --ignore-not-found=true
kubectl delete secret vault-tls -n vault --ignore-not-found=true
kubectl delete secret vault-ca-secret -n vault --ignore-not-found=true

echo "==> [7/8] Xóa cert-manager Issuers..."
kubectl delete issuer vault-ca-issuer -n vault --ignore-not-found=true
kubectl delete clusterissuer selfsigned-issuer --ignore-not-found=true

echo "==> [8/8] Xóa Helm release vault-agent (Injector)..."
# Uninstall helm release nếu có
helm uninstall vault-agent -n vault 2>/dev/null && echo "    vault-agent helm release deleted" || echo "    vault-agent chưa cài"
# Xóa MutatingWebhookConfiguration còn sót
kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg \
  --ignore-not-found=true && echo "    MutatingWebhookConfiguration deleted" || true

echo ""
echo "==> Xóa file local nếu có..."
rm -f vault-prod-init.json && echo "    vault-prod-init.json đã xóa" || echo "    vault-prod-init.json không tồn tại"

echo ""
echo "==> Chờ pods terminate hoàn toàn..."
kubectl wait --for=delete pod -l app=vault -n vault --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app=vault-dev -n vault --timeout=60s 2>/dev/null || true

echo ""
echo "==> Kiểm tra namespace vault còn gì không..."
kubectl get all -n vault 2>/dev/null || echo "    Namespace vault trống"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║         DỌN SẠCH HOÀN TẤT            ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Để cài lại từ đầu, chạy theo thứ tự:"
echo "  cd .."
echo "  kubectl apply -f 10-cert-manager-issuer.yaml"
echo "  kubectl apply -f 11-vault.yaml"
echo "  cd vault-scripts"
echo "  bash 01_setup_vault_dev.sh"
echo "  bash 02_init_vault_prod.sh"
echo "  bash 03_setup_vault_prod.sh"
echo "  bash 04_push_static_secrets.sh"
echo "  bash 05_setup_dynamic_db.sh"
echo "  bash 06_setup_policies.sh"
echo "  bash 07_install_injector.sh"
