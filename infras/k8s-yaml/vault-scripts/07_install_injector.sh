#!/bin/bash
# ==========================================
# Script 7: Cài Vault Agent Injector
# Fix: dùng --force-conflicts khi upgrade để tránh caBundle conflict
# ==========================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=scripts/utils/zta-common.sh
source "$REPO_ROOT/scripts/utils/zta-common.sh"

VAULT_NAMESPACE="vault"
RELEASE_NAME="vault-agent"

echo "==> [1/4] Thêm HashiCorp Helm repo..."
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
wait_for_dns helm.releases.hashicorp.com
helm_repo_update_retry hashicorp
echo "    ✔ Helm repo OK"

echo "==> [2/4] Kiểm tra đã cài chưa..."
if helm status "$RELEASE_NAME" -n "$VAULT_NAMESPACE" &>/dev/null; then
  echo "    Đã cài rồi, upgrade..."

  # Fix conflict: patch MutatingWebhookConfiguration về managed-fields trước
  kubectl annotate mutatingwebhookconfiguration vault-agent-injector-cfg \
    meta.helm.sh/release-name="$RELEASE_NAME" \
    meta.helm.sh/release-namespace="$VAULT_NAMESPACE" \
    --overwrite 2>/dev/null || true

  kubectl label mutatingwebhookconfiguration vault-agent-injector-cfg \
    app.kubernetes.io/managed-by=Helm \
    --overwrite 2>/dev/null || true

  helm upgrade "$RELEASE_NAME" hashicorp/vault \
    --namespace "$VAULT_NAMESPACE" \
    --values vault-injector-values.yaml \
    --force \
    --cleanup-on-fail
else
  echo "    Chưa cài, cài mới..."
  helm install "$RELEASE_NAME" hashicorp/vault \
    --namespace "$VAULT_NAMESPACE" \
    --values vault-injector-values.yaml
fi
echo "    ✔ Helm install/upgrade OK"

echo "==> [3/4] Chờ Injector pod sẵn sàng..."
kubectl wait \
  --for=condition=ready \
  pod \
  -l "app.kubernetes.io/name=vault-agent-injector" \
  -n "$VAULT_NAMESPACE" \
  --timeout=120s
echo "    ✔ Injector pod ready"

echo "==> [4/4] Kiểm tra MutatingWebhookConfiguration..."
kubectl get mutatingwebhookconfiguration vault-agent-injector-cfg &>/dev/null \
  && echo "    ✔ Webhook registered" \
  || echo "    ⚠ Webhook chưa thấy, đợi thêm vài giây..."

echo ""
echo "==> Vault Agent Injector đã cài xong!"
echo ""
kubectl get pod -n "$VAULT_NAMESPACE"
