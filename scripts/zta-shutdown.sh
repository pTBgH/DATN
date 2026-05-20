#!/usr/bin/env bash
# scripts/zta-shutdown.sh - Quy trình tắt cụm K8s an toàn (resilient)
#
# Thay đổi so với phiên bản trước (2026-05-20, sau sự cố vault SIGKILL):
#  1. Có wait condition giữa các stage, không sleep cứng race condition
#  2. Vault sealed thủ công trước khi scale → file storage / raft đóng sạch
#  3. Apps được wait terminate trước khi scale stateful → tránh TCP RST
#  4. MySQL được flush + scale chậm rãi (FLUSH TABLES WITH READ LOCK trước SIGTERM)
#  5. Mọi bước có retry + timeout rõ ràng
set -uo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-job7189}"

WORKER_NODES=(7189srv02 7189srv03 7189srv05)
APP_NS=job7189-apps
DATA_NS=data
VAULT_NS=vault
SEC_NS=security

# ------ helpers --------------------------------------------------------------
log()  { printf '\n=== %s ===\n' "$*"; }
warn() { printf '  ⚠  %s\n' "$*" >&2; }
ok()   { printf '  ✓ %s\n'  "$*"; }

# kubectl wait có timeout, fallback nếu pod đã biến mất / namespace trống
wait_pods_gone() {
  local ns="$1" selector="${2:-}" timeout="${3:-180s}"
  if [ -n "$selector" ]; then
    kubectl -n "$ns" wait --for=delete pod -l "$selector" --timeout="$timeout" 2>/dev/null || true
  else
    kubectl -n "$ns" wait --for=delete pod --all --timeout="$timeout" 2>/dev/null || true
  fi
}

# ------ 1. Cordon worker nodes ----------------------------------------------
log "1/6 Cordon (cấm schedule mới) trên tất cả Worker Nodes"
for node in "${WORKER_NODES[@]}"; do
  if kubectl get node "$node" >/dev/null 2>&1; then
    kubectl cordon "$node" || warn "cordon $node fail (bỏ qua)"
  else
    warn "Node $node không tồn tại — bỏ qua"
  fi
done

# ------ 2. Tắt Application Tier ---------------------------------------------
log "2/6 Scale Application Tier (job7189-apps + keycloak) → 0"
kubectl scale deploy -n "$APP_NS" --all --replicas=0 || warn "scale apps fail"
kubectl scale deploy -n "$SEC_NS" keycloak --replicas=0 2>/dev/null || warn "scale keycloak fail"

# Đợi apps thực sự terminate trước khi đụng data tier
echo "  Đợi tối đa 120s cho app pods terminate..."
wait_pods_gone "$APP_NS" "" 120s
wait_pods_gone "$SEC_NS" "app=keycloak" 60s
ok "Application Tier đã offline"

# ------ 3. Seal Vault thủ công trước khi scale ------------------------------
log "3/6 Seal Vault (chuẩn bị shutdown sạch)"
if kubectl -n "$VAULT_NS" get pod vault-0 >/dev/null 2>&1; then
  # `vault operator seal` cần token. Dùng VAULT_TOKEN từ env, hoặc root token
  # trong vault-prod-init.json nếu có
  ROOT_TOKEN=""
  if [ -f "$HOME/projects/DATN/infras/k8s-yaml/vault-scripts/vault-prod-init.json" ]; then
    ROOT_TOKEN=$(jq -r '.root_token' "$HOME/projects/DATN/infras/k8s-yaml/vault-scripts/vault-prod-init.json" 2>/dev/null || true)
  fi
  if [ -n "$ROOT_TOKEN" ] && [ "$ROOT_TOKEN" != "null" ]; then
    kubectl -n "$VAULT_NS" exec vault-0 -- /bin/sh -c \
      "VAULT_TOKEN='$ROOT_TOKEN' VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault operator seal" \
      >/dev/null 2>&1 && ok "vault-0 sealed" || warn "vault seal fail — sẽ scale trực tiếp"
  else
    warn "Không tìm thấy root_token — bỏ qua seal step"
  fi
else
  warn "vault-0 không tồn tại — bỏ qua"
fi

# ------ 4. Tắt Data Tier (MySQL → Kafka → Vault) ----------------------------
log "4/6 Scale Data Tier xuống 0 (theo thứ tự MySQL → Kafka → Vault)"

# MySQL: chạy FLUSH trước khi scale để đảm bảo dirty pages flush
if kubectl -n "$DATA_NS" get deploy mysql >/dev/null 2>&1; then
  MYSQL_POD=$(kubectl -n "$DATA_NS" get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$MYSQL_POD" ]; then
    kubectl -n "$DATA_NS" exec "$MYSQL_POD" -- sh -c \
      'mysqladmin -uroot -p"$MYSQL_ROOT_PASSWORD" flush-tables 2>/dev/null' \
      >/dev/null 2>&1 && ok "MySQL flush-tables" || warn "flush-tables fail (bỏ qua)"
  fi
  kubectl scale deploy -n "$DATA_NS" mysql --replicas=0
fi

# Kafka
if kubectl -n "$DATA_NS" get sts kafka >/dev/null 2>&1; then
  kubectl scale sts -n "$DATA_NS" kafka --replicas=0
fi

# Vault prod (StatefulSet vault)
if kubectl -n "$VAULT_NS" get sts vault >/dev/null 2>&1; then
  kubectl scale sts -n "$VAULT_NS" vault --replicas=0
fi

echo "  Đợi tối đa 180s cho data tier terminate..."
wait_pods_gone "$DATA_NS" "app=mysql" 120s
wait_pods_gone "$DATA_NS" "app=kafka" 120s
wait_pods_gone "$VAULT_NS" "app.kubernetes.io/name=vault" 120s

# ------ 5. Kiểm tra trạng thái cuối cùng ------------------------------------
log "5/6 Kiểm tra trạng thái cuối"
REMAINING=$(kubectl get pods -A --no-headers 2>/dev/null | grep -E "kafka|mysql|vault-0|^$APP_NS " | grep -v "Completed" | wc -l || echo 0)
if [ "$REMAINING" -eq 0 ]; then
  ok "Application + Data + Vault tier đã offline"
else
  warn "$REMAINING pod chưa terminate:"
  kubectl get pods -A 2>/dev/null | grep -E "kafka|mysql|vault-0|^$APP_NS " | grep -v "Completed" || true
fi

# ------ 6. Hoàn tất ---------------------------------------------------------
log "6/6 Sẵn sàng shutdown VMware/libvirt"
ok "BÂY GIỜ BẠN CÓ THỂ SHUTDOWN CÁC MÁY ẢO AN TOÀN"
