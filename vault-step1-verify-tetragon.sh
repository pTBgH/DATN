#!/usr/bin/env bash
# Vault Cấp Cứu — STEP 1: verify Tetragon là root cause (read-only + 1 backup + 1 delete CRD tạm)
# Sau khi chạy xong, nếu vault-dev exec OK → confirmed → mình sẽ gửi tiếp script STEP 2 (rebuild)
# Nếu vẫn fail → root cause khác, mình điều tra tiếp.
 
set -u
BACKUP_DIR="${HOME}/vault-recovery-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
 
echo "===== [1/5] Backup TracingPolicyNamespaced trong ns vault ====="
kubectl get tracingpolicynamespaced block-suspicious-exec -n vault -o yaml \
  > "$BACKUP_DIR/tetragon-vault-block-suspicious-exec.yaml"
ls -la "$BACKUP_DIR/tetragon-vault-block-suspicious-exec.yaml"
echo "Backup OK -> $BACKUP_DIR"
 
echo
echo "===== [2/5] Trước khi xoá: exec test (kỳ vọng exit 137) ====="
echo "--- vault-0: vault status (10s timeout)"
timeout 10s kubectl exec -n vault vault-0 -c vault -- \
  sh -c 'VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json' \
  2>&1 || echo "exit=$?"
echo "--- vault-dev: vault status (5s timeout)"
timeout 5s kubectl exec -n vault deploy/vault-dev -- \
  sh -c 'VAULT_ADDR=http://127.0.0.1:8300 vault status -format=json' \
  2>&1 || echo "exit=$?"
 
echo
echo "===== [3/5] Xoá TracingPolicyNamespaced (TẠM, sẽ apply lại ở STEP 2) ====="
kubectl delete tracingpolicynamespaced block-suspicious-exec -n vault
echo "Đợi 15s cho Tetragon detach kprobe..."
sleep 15
 
echo
echo "===== [4/5] Sau khi xoá: exec test (kỳ vọng OK, KHÔNG còn SIGKILL) ====="
echo "--- vault-0: vault status (10s timeout)"
timeout 10s kubectl exec -n vault vault-0 -c vault -- \
  sh -c 'VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json' \
  2>&1 || echo "exit=$?"
echo "--- vault-dev: vault status (5s timeout)"
timeout 5s kubectl exec -n vault deploy/vault-dev -- \
  sh -c 'VAULT_ADDR=http://127.0.0.1:8300 vault status -format=json' \
  2>&1 || echo "exit=$?"
echo "--- vault-dev: vault secrets list (cần token)"
DEVTOK=$(kubectl get secret vault-dev-token -n vault -o jsonpath='{.data.token}' | base64 -d)
timeout 5s kubectl exec -n vault deploy/vault-dev -- \
  sh -c "VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN='$DEVTOK' vault secrets list" \
  2>&1 || echo "exit=$?"
 
echo
echo "===== [5/5] vault-0 pod readiness (đợi 30s xem kubelet probe có chạy được không) ====="
# vault-0 vẫn 0/1 vì chưa init+unseal (kỳ vọng) nhưng probe phải EXECUTE được, không SIGKILL
sleep 30
kubectl get pod vault-0 -n vault
echo "--- mô tả Conditions + Events 60s gần nhất"
kubectl get pod vault-0 -n vault -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
kubectl get events -n vault --sort-by=.lastTimestamp 2>/dev/null | tail -15
 
echo
echo "===== DONE. Gửi output về cho Devin để chuyển sang STEP 2 (init + unseal + bootstrap + reinstall injector) ====="
echo "Backup tại: $BACKUP_DIR/tetragon-vault-block-suspicious-exec.yaml"
echo "Sau khi recovery hoàn tất, mình sẽ apply lại policy này (kèm exception cho kubelet probe) trong STEP 2."
