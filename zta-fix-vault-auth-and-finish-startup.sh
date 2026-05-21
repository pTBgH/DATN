#!/usr/bin/env bash
# =============================================================================
# zta-fix-vault-auth-and-finish-startup.sh
#
# Phase 1 sau fresh boot:
#   1) Tạo Secret-backed SA token PERSISTENT cho vault (không expire)
#   2) Rewrite auth/kubernetes/config với token mới
#   3) Verify login bằng SA token của identity-service
#   4) Force-delete pod stuck (skip backoff 4-5 phút của vault-agent)
#   5) Wave 1 finish → Wave 2 (candidate+communication) → Wave 3 (hiring+storage+workspace)
#   6) Verify 7/7 Ready
#
# KHÔNG đụng default-deny / tetragon ở phase này (sẽ là phase 2).
# =============================================================================
set -uo pipefail

cd ~/projects/DATN

H(){ printf '\n========== %s ==========\n' "$*"; }

# --------------------------------------------------------------------------
H "1. Tạo Secret-backed SA token PERSISTENT cho vault"
kubectl -n vault apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: vault-token-reviewer
  namespace: vault
  annotations:
    kubernetes.io/service-account.name: vault
type: kubernetes.io/service-account-token
EOF

echo "Đợi 10s K8s populate token..."
sleep 10

TOKEN=$(kubectl -n vault get secret vault-token-reviewer -o jsonpath='{.data.token}' | base64 -d)
if [ -z "$TOKEN" ]; then
  echo "FAIL: secret chưa có token sau 10s. Tăng wait time hoặc kiểm tra SA 'vault' có tồn tại."
  kubectl -n vault get sa vault
  exit 1
fi
echo "  Token length: ${#TOKEN}"

kubectl -n vault get cm kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > /tmp/k8s-ca.crt
[ -s /tmp/k8s-ca.crt ] || { echo "FAIL: không lấy được CA"; exit 1; }
echo "  CA cert: $(wc -c < /tmp/k8s-ca.crt) bytes"

# --------------------------------------------------------------------------
H "2. Rewrite auth/kubernetes/config trong vault-0"
ROOT_TOKEN=$(jq -r '.root_token' infras/k8s-yaml/vault-scripts/vault-prod-init.json 2>/dev/null)
if [ -z "$ROOT_TOKEN" ] || [ "$ROOT_TOKEN" = "null" ]; then
  echo "FAIL: không đọc được root_token tại infras/k8s-yaml/vault-scripts/vault-prod-init.json"
  exit 1
fi

TOKEN_B64=$(printf '%s' "$TOKEN" | base64 -w 0)
CA_B64=$(base64 -w 0 /tmp/k8s-ca.crt)

echo "  ----- config TRƯỚC fix -----"
kubectl exec -n vault vault-0 -c vault -- sh -c "
  VAULT_TOKEN='$ROOT_TOKEN' VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
    vault read auth/kubernetes/config 2>&1 | head -10
" || true

echo "  ----- ghi config mới -----"
kubectl exec -n vault vault-0 -c vault -- sh -c "
  echo '$TOKEN_B64' | base64 -d > /tmp/vault-tr-token
  echo '$CA_B64'    | base64 -d > /tmp/k8s-ca.crt
  VAULT_TOKEN='$ROOT_TOKEN' VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
    vault write auth/kubernetes/config \
      token_reviewer_jwt=@/tmp/vault-tr-token \
      kubernetes_host='https://kubernetes.default.svc:443' \
      kubernetes_ca_cert=@/tmp/k8s-ca.crt \
      disable_iss_validation=true 2>&1
"

echo "  ----- config SAU fix -----"
kubectl exec -n vault vault-0 -c vault -- sh -c "
  VAULT_TOKEN='$ROOT_TOKEN' VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
    vault read auth/kubernetes/config 2>&1 | head -10
"

# --------------------------------------------------------------------------
H "3. Verify login bằng SA token thực của identity-service"
SVC_POD=$(kubectl -n job7189-apps get pod -l app=identity-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SVC_POD" ]; then
  SA_TOKEN=$(kubectl -n job7189-apps exec "$SVC_POD" -c vault-agent-init -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
  if [ -n "$SA_TOKEN" ]; then
    echo "  SA token len: ${#SA_TOKEN}"
    kubectl exec -n vault vault-0 -c vault -- sh -c "
      VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 \
        vault write auth/kubernetes/login role=identity-service jwt='$SA_TOKEN' 2>&1 | head -15
    "
  else
    echo "  ⚠ Không đọc được SA token từ pod (init container có thể đã exit)"
  fi
fi

# --------------------------------------------------------------------------
H "4. Force-delete stuck pods (skip backoff)"
kubectl -n job7189-apps delete pod -l app=identity-service --grace-period=0 --force 2>/dev/null || true
kubectl -n job7189-apps delete pod -l app=job-service     --grace-period=0 --force 2>/dev/null || true
sleep 5

# --------------------------------------------------------------------------
H "5. Đợi rollout identity + job"
kubectl -n job7189-apps rollout status deploy/identity-service --timeout=300s &
PID1=$!
kubectl -n job7189-apps rollout status deploy/job-service --timeout=300s &
PID2=$!
wait $PID1 || echo "  ⚠ identity-service rollout timeout"
wait $PID2 || echo "  ⚠ job-service rollout timeout"

kubectl get pod -n job7189-apps -l 'app in (identity-service, job-service)'

# --------------------------------------------------------------------------
H "6. Wave 2: candidate + communication"
kubectl -n job7189-apps scale deploy candidate-service-redis communication-service-redis --replicas=1 2>/dev/null || true
sleep 10
kubectl -n job7189-apps scale deploy candidate-service communication-service --replicas=1
sleep 5
kubectl -n job7189-apps rollout status deploy/candidate-service --timeout=300s &
P1=$!
kubectl -n job7189-apps rollout status deploy/communication-service --timeout=300s &
P2=$!
wait $P1 || echo "  ⚠ candidate-service rollout timeout"
wait $P2 || echo "  ⚠ communication-service rollout timeout"

# --------------------------------------------------------------------------
H "7. Wave 3: hiring + storage + workspace"
kubectl -n job7189-apps scale deploy hiring-service-redis storage-service-redis workspace-service-redis --replicas=1 2>/dev/null || true
sleep 10
kubectl -n job7189-apps scale deploy hiring-service storage-service workspace-service --replicas=1
sleep 5
kubectl -n job7189-apps rollout status deploy/hiring-service --timeout=300s &
P3=$!
kubectl -n job7189-apps rollout status deploy/storage-service --timeout=300s &
P4=$!
kubectl -n job7189-apps rollout status deploy/workspace-service --timeout=300s &
P5=$!
wait $P3 || echo "  ⚠ hiring-service rollout timeout"
wait $P4 || echo "  ⚠ storage-service rollout timeout"
wait $P5 || echo "  ⚠ workspace-service rollout timeout"

# --------------------------------------------------------------------------
H "8. Final state"
kubectl get pod -A | grep -v Completed
echo
echo "Tổng kết job7189-apps service:"
kubectl get pod -n job7189-apps -l 'app in (identity-service,job-service,candidate-service,communication-service,hiring-service,storage-service,workspace-service)' \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase'

echo
echo "===== DONE ====="
echo "Nếu 7/7 service Ready → tiếp theo chạy:"
echo "  bash zta-microseg-step1-flow-capture.sh   (capture flow 10 phút)"
echo "  bash zta-audit-cluster-state.sh           (audit state vs doc/)"
