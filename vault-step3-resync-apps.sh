#!/bin/bash
# =========================================================================
# Vault Cấp Cứu — STEP 3: Helmfile sync drift + rollout restart 5 pod stuck
# =========================================================================
# Pre-conditions (đã confirm từ STEP 2):
#   - vault-0 1/1 Running, initialized=true, sealed=false
#   - vault-agent-agent-injector pod 1/1 Running
#   - MutatingWebhookConfiguration vault-agent-injector-cfg đã register
#
# Script này:
#   1. Verify webhook đã register (nếu chưa → đợi)
#   2. Helmfile sync 2 deploy bị Agent edit drift (identity-service + job-service)
#      → revert init container 'create-dummy-env' về initContainers chuẩn
#      → bật lại annotation vault.hashicorp.com/agent-inject=true
#   3. Rollout restart 5 deployment stuck Init:0/3
#      (candidate, communication, hiring, storage, workspace) → injector mutate lại
#   4. Wait + verify tất cả 7 pod có đúng 4 container Running
# =========================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
HELMFILE_DIR="${REPO_ROOT}/k8s-management"

# Apps có drift cần helmfile sync (chart override sẽ revert kubectl edit của Agent trước)
DRIFTED_APPS=(identity-service job-service)

# Apps stuck Init:0/3 cần rollout restart (pod tạo trước khi injector chết → kéo theo old spec)
STUCK_APPS=(candidate-service communication-service hiring-service storage-service workspace-service)

ALL_APPS=(identity-service workspace-service job-service hiring-service candidate-service communication-service storage-service)

echo "╔═════════════════════════════════════════════════╗"
echo "║   🚀 VAULT STEP 3: RESYNC APPS + RESTART        ║"
echo "╚═════════════════════════════════════════════════╝"

# ----- [1/4] Verify webhook -----
# Helm release `vault-agent` tạo MWC tên `vault-agent-agent-injector-cfg`
# (theo template <release>-agent-injector-cfg).
WEBHOOK_NAME="vault-agent-agent-injector-cfg"
echo -e "\n==> [1/4] Verify MutatingWebhookConfiguration $WEBHOOK_NAME..."
for i in $(seq 1 20); do
  if kubectl get mutatingwebhookconfiguration "$WEBHOOK_NAME" >/dev/null 2>&1; then
    echo "    ✔ Webhook $WEBHOOK_NAME registered"
    kubectl get mutatingwebhookconfiguration "$WEBHOOK_NAME" \
      -o jsonpath='{range .webhooks[*]}{.name}{"  service="}{.clientConfig.service.namespace}{"/"}{.clientConfig.service.name}{":"}{.clientConfig.service.port}{"  failurePolicy="}{.failurePolicy}{"\n"}{end}'
    echo
    break
  fi
  echo "    đợi webhook... ($i/20)"
  sleep 3
  [ $i -eq 20 ] && { echo "ERROR: webhook không xuất hiện sau 60s"; exit 1; }
done

# ----- [2/4] Helmfile sync 2 deploy drift -----
echo -e "\n==> [2/4] Helmfile sync ${DRIFTED_APPS[*]} (revert Agent's kubectl edit)..."
cd "$HELMFILE_DIR"

if ! command -v helmfile >/dev/null 2>&1; then
  echo "ERROR: helmfile không có trong PATH. Cài: https://github.com/helmfile/helmfile/releases"
  exit 1
fi

for app in "${DRIFTED_APPS[@]}"; do
  echo "--- helmfile sync $app ---"
  helmfile -l name="$app" sync 2>&1 | tail -25
done

# ----- [3/4] Rollout restart 5 stuck deployments -----
echo -e "\n==> [3/4] Rollout restart ${STUCK_APPS[*]} (để injector mutate lại)..."
kubectl rollout restart deployment -n job7189-apps "${STUCK_APPS[@]}"

# ----- [4/4] Wait + verify -----
echo -e "\n==> [4/4] Đợi tất cả 7 pod READY 4/4..."
echo "    (timeout 5 phút mỗi deployment)"

for app in "${ALL_APPS[@]}"; do
  echo "--- waiting $app ---"
  kubectl rollout status deployment "$app" -n job7189-apps --timeout=300s || echo "    ⚠ $app chưa ready trong 5 phút"
done

echo
echo "==> Tổng kết:"
kubectl get pod -n job7189-apps
echo
echo "==> Container count mỗi deployment:"
for app in "${ALL_APPS[@]}"; do
  POD=$(kubectl get pod -n job7189-apps -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$POD" ]; then
    echo "$app: KHÔNG có pod"
    continue
  fi
  INIT_CT=$(kubectl get pod -n job7189-apps "$POD" -o jsonpath='{range .spec.initContainers[*]}{.name},{end}')
  MAIN_CT=$(kubectl get pod -n job7189-apps "$POD" -o jsonpath='{range .spec.containers[*]}{.name},{end}')
  INJECT=$(kubectl get deploy "$app" -n job7189-apps -o jsonpath='{.spec.template.metadata.annotations.vault\.hashicorp\.com/agent-inject}')
  READY=$(kubectl get pod -n job7189-apps "$POD" -o jsonpath='{.status.containerStatuses[?(@.ready==true)].name}' | tr ' ' ',')
  echo "$app: inject=$INJECT | INIT=$INIT_CT | MAIN=$MAIN_CT | READY=$READY"
done

echo
echo "╔═════════════════════════════════════════════════╗"
echo "║   ✔ STEP 3 DONE                                 ║"
echo "╚═════════════════════════════════════════════════╝"
echo "Kỳ vọng mỗi pod: INIT=vault-agent-init,wait-for-vault-secrets,fix-perms, MAIN=env-loader,env-watcher,app,vault-agent (4 container)"
echo "Bước tiếp: STEP 4 — apply lại Tetragon policy với exception cho kubelet probe + clean issue phụ"
