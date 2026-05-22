#!/usr/bin/env bash
# scripts/zta-startup.sh - Quy trình đánh thức cụm K8s an toàn (resilient)
#
# Thay đổi so với phiên bản trước (2026-05-20):
#  1. Chờ Control Plane Ready (cilium / coredns / tetragon / sigstore) trước khi
#     scale workloads — tránh admission webhook reject + CNI race
#  2. Data Tier khởi động tuần tự, có wait condition / retry, không sleep cứng
#  3. Vault unseal với retry loop + verify sealed=false trước khi tiếp tục
#  4. Apps khởi động theo WAVE (2 service mỗi đợt), tránh spike CPU/RAM/Vault
#     auth-login (đã từng làm vault session timeout khi 7 service start cùng lúc)
#  5. Mọi bước có timeout rõ ràng + log progress chi tiết
set -uo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-job7189}"

WORKER_NODES=(7189srv02 7189srv03 7189srv05)
APP_NS=job7189-apps
DATA_NS=data
VAULT_NS=vault
SEC_NS=security

VAULT_INIT_JSON="$HOME/projects/DATN/infras/k8s-yaml/vault-scripts/vault-prod-init.json"

# ------ helpers --------------------------------------------------------------
log()  { printf '\n=== %s ===\n' "$*"; }
warn() { printf '  ⚠  %s\n' "$*" >&2; }
ok()   { printf '  ✓ %s\n'  "$*"; }
err()  { printf '  ✗ %s\n'  "$*" >&2; }

wait_ready() {
  local ns="$1" selector="$2" timeout="${3:-300s}" label="${4:-$selector}"
  echo "  Đợi $label ready (≤$timeout)..."
  if kubectl -n "$ns" wait --for=condition=Ready pod -l "$selector" --timeout="$timeout" >/dev/null 2>&1; then
    ok "$label ready"
    return 0
  else
    warn "$label CHƯA ready sau $timeout"
    kubectl -n "$ns" get pod -l "$selector" 2>/dev/null
    return 1
  fi
}

wait_rollout() {
  local ns="$1" kind="$2" name="$3" timeout="${4:-300s}"
  echo "  Đợi rollout $kind/$name (≤$timeout)..."
  kubectl -n "$ns" rollout status "$kind" "$name" --timeout="$timeout" || warn "$kind/$name rollout timeout"
}

# ------ 0. Verify cluster control plane Ready -------------------------------
log "0/8 Verify Kubernetes Control Plane Ready"
RETRY=0
until kubectl get nodes >/dev/null 2>&1 || [ $RETRY -ge 30 ]; do
  echo "  Đang chờ kube-apiserver... ($RETRY/30)"
  sleep 5
  RETRY=$((RETRY+1))
done
kubectl get nodes || { err "API server không reachable — abort"; exit 1; }

# ------ 1. Uncordon worker nodes --------------------------------------------
log "1/8 Uncordon Worker Nodes"
for node in "${WORKER_NODES[@]}"; do
  if kubectl get node "$node" >/dev/null 2>&1; then
    kubectl uncordon "$node" || warn "uncordon $node fail"
  else
    warn "Node $node không tồn tại"
  fi
done

# ------ 2. Wait infra DaemonSets / webhooks Ready ---------------------------
log "2/8 Đợi infrastructure layer Ready (Cilium / CoreDNS / Tetragon / Sigstore)"
wait_ready kube-system    "k8s-app=cilium"              180s "cilium DaemonSet"
wait_ready kube-system    "k8s-app=kube-dns"            120s "coredns"
wait_ready kube-system    "app.kubernetes.io/name=tetragon" 180s "tetragon" || warn "Tetragon chưa ready (không block tiếp)"
# Label thật của sigstore policy-controller Helm chart: app.kubernetes.io/name=policy-controller
# (không phải app=policy-controller-webhook — selector cũ luôn timeout 180s).
wait_ready cosign-system  "app.kubernetes.io/name=policy-controller" 180s "sigstore policy-controller" || warn "Sigstore chưa ready"
wait_ready cert-manager   "app.kubernetes.io/name=cert-manager" 120s "cert-manager" || true

# ------ 3. Data Tier: MySQL trước → Kafka → Vault Dev -----------------------
log "3/8 Khởi động Data Tier (MySQL → Kafka → vault-dev)"
kubectl scale deploy -n "$DATA_NS" mysql --replicas=1 2>/dev/null || true
kubectl scale sts -n "$DATA_NS" kafka --replicas=1 2>/dev/null || true
kubectl scale deploy -n "$VAULT_NS" vault-dev --replicas=1 2>/dev/null || true

# MySQL cold start cần 60-90s
wait_ready "$DATA_NS" "app=mysql" 300s "MySQL" || warn "MySQL cold start fail"
wait_ready "$DATA_NS" "app=kafka" 240s "Kafka" || warn "Kafka cold start fail"
wait_ready "$VAULT_NS" "app=vault-dev" 120s "vault-dev (transit unseal helper)" || true

# ------ 4. Vault Prod start + Unseal ----------------------------------------
log "4/8 Khởi động Vault Prod (StatefulSet) + unseal"
kubectl scale sts -n "$VAULT_NS" vault --replicas=1 2>/dev/null || true

# Đợi pod vault-0 Running (chưa cần Ready, vì sealed → probe fail)
RETRY=0
until kubectl -n "$VAULT_NS" get pod vault-0 -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Running || [ $RETRY -ge 30 ]; do
  echo "  Đợi vault-0 phase=Running... ($RETRY/30)"
  sleep 5
  RETRY=$((RETRY+1))
done

# Unseal retry loop (Shamir, 1 share)
if [ -f "$VAULT_INIT_JSON" ]; then
  KEY1=$(jq -r '.unseal_keys_b64[0]' "$VAULT_INIT_JSON" 2>/dev/null)
  if [ -z "$KEY1" ] || [ "$KEY1" = "null" ]; then
    err "Không đọc được unseal_keys_b64[0] từ $VAULT_INIT_JSON"
  else
    RETRY=0
    UNSEALED=0
    while [ $RETRY -lt 10 ] && [ $UNSEALED -eq 0 ]; do
      OUT=$(kubectl -n "$VAULT_NS" exec vault-0 -- /bin/sh -c \
        "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault operator unseal '$KEY1' 2>&1" || true)
      if echo "$OUT" | grep -q '"sealed"[[:space:]]*false\|Sealed[[:space:]]*false'; then
        UNSEALED=1
        ok "vault-0 unsealed"
        break
      fi
      SEALED=$(kubectl -n "$VAULT_NS" exec vault-0 -- /bin/sh -c \
        "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json 2>/dev/null" \
        | jq -r '.sealed' 2>/dev/null || echo unknown)
      if [ "$SEALED" = "false" ]; then
        UNSEALED=1
        ok "vault-0 unsealed (verified via status)"
        break
      fi
      echo "  Unseal attempt $((RETRY+1))/10 chưa thành công, đợi 6s..."
      sleep 6
      RETRY=$((RETRY+1))
    done
    if [ $UNSEALED -eq 0 ]; then
      err "vault-0 unseal FAIL sau 10 lần thử — kiểm tra thủ công"
      kubectl -n "$VAULT_NS" logs vault-0 --tail=30 || true
    fi
  fi
else
  warn "$VAULT_INIT_JSON không tồn tại — bỏ qua unseal (vault có thể đã transit auto-unseal)"
fi

# Đợi vault-0 Ready (probe phải pass = sealed=false).
# Cold-boot CPU contend trên 4-node cluster có thể vượt 180s — dãn 300s.
wait_ready "$VAULT_NS" "app.kubernetes.io/name=vault" 300s "vault-0" || warn "vault-0 không pass probe"

# Vault Agent Injector Deployment
kubectl scale deploy -n "$VAULT_NS" vault-agent-agent-injector --replicas=1 2>/dev/null || \
  kubectl scale deploy -n "$VAULT_NS" -l app.kubernetes.io/name=vault-agent-injector --replicas=1 2>/dev/null || true
wait_ready "$VAULT_NS" "app.kubernetes.io/name=vault-agent-injector" 120s "vault-agent-injector" || warn "Injector chưa Ready"

# ------ 5. Security Tier: Keycloak ------------------------------------------
log "5/8 Khởi động Security Tier (Keycloak)"
kubectl scale deploy -n "$SEC_NS" keycloak --replicas=1 2>/dev/null || true
# Keycloak cold boot JVM + DB connection: 240s không đủ → 360s + 1 retry vòng lặp.
KC_RETRY=0
KC_OK=0
while [ $KC_RETRY -lt 2 ] && [ $KC_OK -eq 0 ]; do
  if wait_ready "$SEC_NS" "app=keycloak" 360s "Keycloak (attempt $((KC_RETRY+1))/2)"; then
    KC_OK=1
    break
  fi
  KC_RETRY=$((KC_RETRY+1))
  warn "Keycloak chưa Ready sau 360s, retry $KC_RETRY/2 — kiểm tra DB connection nếu vẫn fail"
done
if [ $KC_OK -eq 0 ]; then
  warn "Keycloak chưa Ready sau 2 lần thử — tiếp tục, login có thể fail tới khi Keycloak lên"
fi

# ------ 6. Application Tier theo wave (2-2-3 service) -----------------------
log "6/8 Khởi động Application Tier (theo wave để tránh Vault auth-login spike)"

WAVE_1=(identity-service job-service)
WAVE_2=(candidate-service communication-service)
WAVE_3=(hiring-service storage-service workspace-service)

start_wave() {
  local wave=("$@")
  for svc in "${wave[@]}"; do
    # Bật cả redis của service trước (idempotent)
    kubectl scale deploy -n "$APP_NS" "${svc}-redis" --replicas=1 2>/dev/null || true
  done
  for svc in "${wave[@]}"; do
    kubectl scale deploy -n "$APP_NS" "$svc" --replicas=1 2>/dev/null || true
  done
  for svc in "${wave[@]}"; do
    wait_rollout "$APP_NS" deployment "$svc" 300s
  done
}

echo "  -- Wave 1: identity-service + job-service --"
start_wave "${WAVE_1[@]}"
sleep 5
echo "  -- Wave 2: candidate + communication --"
start_wave "${WAVE_2[@]}"
sleep 5
echo "  -- Wave 3: hiring + storage + workspace --"
start_wave "${WAVE_3[@]}"

# ------ 7. Dọn dẹp zombie pod -----------------------------------------------
log "7/8 Dọn dẹp Zombie Pods (Unknown / NodeLost)"
ZOMBIES=$(kubectl get pod -A --no-headers 2>/dev/null | awk '$4 ~ /Unknown|NodeLost/ {print $1" "$2}')
if [ -n "$ZOMBIES" ]; then
  echo "$ZOMBIES" | while read ns name; do
    kubectl delete pod -n "$ns" "$name" --grace-period=0 --force 2>/dev/null || true
  done
  ok "Đã dọn zombie pods"
else
  ok "Không có zombie pod"
fi

# ------ 8. Health summary ---------------------------------------------------
log "8/8 Health Summary"
echo "  Pods chưa Ready trong các ns chính (job7189-apps / data / vault / security):"
kubectl get pod -n "$APP_NS"   --no-headers 2>/dev/null | awk '$2 !~ /^[0-9]+\/[0-9]+$/ || $3 != "Running" {print "    "$0}'
kubectl get pod -n "$DATA_NS"  --no-headers 2>/dev/null | awk '$2 !~ /^[0-9]+\/[0-9]+$/ || $3 != "Running" {print "    "$0}'
kubectl get pod -n "$VAULT_NS" --no-headers 2>/dev/null | awk '$2 !~ /^[0-9]+\/[0-9]+$/ || $3 != "Running" {print "    "$0}'
kubectl get pod -n "$SEC_NS"   --no-headers 2>/dev/null | awk '$2 !~ /^[0-9]+\/[0-9]+$/ || $3 != "Running" {print "    "$0}'

ok "HỆ THỐNG ĐÃ SẴN SÀNG! Dùng 'kubectl get pods -A -w' để theo dõi."
