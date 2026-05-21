#!/bin/bash
# =========================================================================
# STEP 3D: Fix 2 root cause độc lập
#   1) Tetragon block-suspicious-exec ns job7189-apps vẫn SIGKILL /bin/sh
#      → backup + delete (sẽ reapply ở STEP 4 với exception)
#   2) CNP allow-internal-redis egress matchLabels "app.kubernetes.io/name=redis"
#      KHÔNG khớp với label thật của redis pod (`app=<svc>-redis`, `zta.job7189/role=cache`)
#      → patch dùng `zta.job7189/role=cache` (đã có sẵn trên mọi redis pod)
#   3) Scale 5 deployment đang có 2 ReplicaSet (drift) xuống 0 rồi lên 1 để clean
# =========================================================================
set -u
 
BACKUP_DIR="${HOME}/vault-recovery-backups/$(date +%Y%m%d-%H%M%S)-step3d"
mkdir -p "$BACKUP_DIR"
echo "Backup dir: $BACKUP_DIR"
 
echo
echo "===== [1/4] Backup + delete Tetragon block-suspicious-exec ns job7189-apps ====="
kubectl get tracingpolicynamespaced block-suspicious-exec -n job7189-apps -o yaml > "$BACKUP_DIR/tetragon-job7189-apps.yaml"
ls -la "$BACKUP_DIR/tetragon-job7189-apps.yaml"
kubectl delete tracingpolicynamespaced block-suspicious-exec -n job7189-apps
echo "Đợi 10s cho Tetragon detach kprobe..."
sleep 10
 
echo
echo "===== [2/4] Backup + patch CNP allow-internal-redis (label selector đúng) ====="
kubectl get cnp -n job7189-apps allow-internal-redis -o yaml > "$BACKUP_DIR/cnp-allow-internal-redis.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-internal-redis
  namespace: job7189-apps
spec:
  endpointSelector:
    matchLabels: {}
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: job7189-apps
        zta.job7189/role: cache
    toPorts:
    - ports:
      - port: "6379"
        protocol: TCP
  ingress:
  - fromEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: job7189-apps
    toPorts:
    - ports:
      - port: "6379"
        protocol: TCP
EOF
echo "Đợi 5s Cilium reload policy..."
sleep 5
kubectl get cnp -n job7189-apps allow-internal-redis
 
echo
echo "===== [3/4] Scale 5 deployment drift xuống 0 rồi lên 1 (clean RS) ====="
APPS=(candidate-service communication-service hiring-service storage-service workspace-service)
for a in "${APPS[@]}"; do
  kubectl scale deployment -n job7189-apps "$a" --replicas=0
done
echo "Đợi 20s cho mọi pod terminate..."
sleep 20
kubectl get pod -n job7189-apps | grep -E "^(candidate|communication|hiring|storage|workspace)-service-" | grep -v redis
 
echo "Scale lại lên 1..."
for a in "${APPS[@]}"; do
  kubectl scale deployment -n job7189-apps "$a" --replicas=1
done
 
echo
echo "===== [4/4] Wait + verify ====="
sleep 30
for a in "${APPS[@]}"; do
  echo "--- $a ---"
  kubectl rollout status deployment "$a" -n job7189-apps --timeout=180s &
done
wait
 
echo
echo "===== Tổng kết ====="
kubectl get pod -n job7189-apps -o wide
echo
echo "Container ready/state mỗi pod (chỉ in container chưa Ready):"
for p in $(kubectl get pod -n job7189-apps --no-headers -o custom-columns=:.metadata.name | grep -v redis); do
  NOT_READY=$(kubectl get pod -n job7189-apps "$p" -o jsonpath='{range .status.containerStatuses[?(@.ready==false)]}{.name}{","}{end}' 2>/dev/null)
  PHASE=$(kubectl get pod -n job7189-apps "$p" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ -n "$NOT_READY" ] || [ "$PHASE" != "Running" ]; then
    echo "  $p: phase=$PHASE notReady=$NOT_READY"
  fi
done
 
echo
echo "===== Backup tại: $BACKUP_DIR ====="
ls -la "$BACKUP_DIR"
echo "===== DONE ====="
