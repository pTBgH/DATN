#!/bin/bash
# =========================================================================
# Vault Cấp Cứu — STEP 3B: Force-delete pod stuck + diagnose Pending + CIP
# =========================================================================
# - Force-delete 5 pod cũ Init:0/3 (cứng đầu không terminate vì vault-agent-init
#   loop từ trước khi Vault sống lại). KHÔNG đụng deployment, controller sẽ
#   tự tạo lại pod mới đã được injector mutate.
# - Đọc thông tin cần thiết cho STEP 4: pod Pending bị gì? CIP zta-job7189-apps-signed
#   spec có khắt khe digest không?
# =========================================================================
set -u

OLD_PODS=(
  candidate-service-67b47b8568-pkv7c
  communication-service-985bfd575-msgd4
  hiring-service-7d98f85445-l6l5r
  storage-service-7766d9c786-6bk9s
  workspace-service-5bb465566-fn8dz
)

echo "===== A. Force-delete 5 pod Init:0/3 (cứng đầu) ====="
for p in "${OLD_PODS[@]}"; do
  kubectl delete pod -n job7189-apps "$p" --force --grace-period=0 --ignore-not-found=true
done

echo
echo "===== B. Đợi 45s cho deployment controller schedule pod mới ====="
sleep 45
kubectl get pod -n job7189-apps -o wide

echo
echo "===== C. Describe các pod Pending (xem reason) ====="
PENDING_PODS=$(kubectl get pod -n job7189-apps --no-headers --field-selector=status.phase=Pending -o custom-columns=:.metadata.name 2>/dev/null)
if [ -z "$PENDING_PODS" ]; then
  echo "(Không còn pod Pending)"
else
  for p in $PENDING_PODS; do
    echo "--- pod=$p ---"
    kubectl describe pod -n job7189-apps "$p" 2>/dev/null | sed -n '/Events:/,$p' | head -25
    echo "  Resources:"
    kubectl get pod -n job7189-apps "$p" -o jsonpath='{range .spec.containers[*]}{.name}{"\trequest="}{.resources.requests}{"\tlimit="}{.resources.limits}{"\n"}{end}'
  done
fi

echo
echo "===== D. Node resource pressure (xem srv05 còn slot không) ====="
kubectl top node 2>/dev/null || echo "(metrics-server không có, skip top node)"
kubectl describe node | grep -A 5 "Allocated resources" | head -40

echo
echo "===== E. Container không Ready trong pod mới — log vault-agent + app ====="
NEW_RUNNING=$(kubectl get pod -n job7189-apps --no-headers \
  --field-selector=status.phase=Running -o custom-columns=:.metadata.name 2>/dev/null \
  | grep -vE 'redis|identity-service|job-service' | head -7)
for p in $NEW_RUNNING; do
  echo "--- pod=$p ---"
  kubectl get pod -n job7189-apps "$p" -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\tready="}{.ready}{"\trestartCount="}{.restartCount}{"\tstate="}{.state}{"\n"}{end}'
  for c in vault-agent app env-loader env-watcher; do
    READY=$(kubectl get pod -n job7189-apps "$p" -o jsonpath="{.status.containerStatuses[?(@.name=='$c')].ready}" 2>/dev/null)
    if [ "$READY" != "true" ]; then
      echo "  --- log $c (last 30) ---"
      kubectl logs -n job7189-apps "$p" -c "$c" --tail=30 2>&1 | tail -30
    fi
  done
done

echo
echo "===== F. ClusterImagePolicy zta-job7189-apps-signed (xem để bypass helmfile) ====="
kubectl get clusterimagepolicy zta-job7189-apps-signed -o yaml 2>/dev/null | head -100

echo
echo "===== G. Helmfile values của identity-service (image format) ====="
grep -A 2 'identity-service' "${HOME}/projects/DATN/k8s-management/helmfile.yaml" | head -8
ls -la "${HOME}/projects/DATN/k8s-management/values/identity-values.yaml" 2>/dev/null
grep -iE 'image|tag|digest|sha256' "${HOME}/projects/DATN/k8s-management/values/identity-values.yaml" 2>/dev/null | head -10
echo ---
grep -iE 'image|tag|digest|sha256' "${HOME}/projects/DATN/k8s-management/values/laravel-common-values.yaml" 2>/dev/null | head -20

echo
echo "===== DONE ====="
