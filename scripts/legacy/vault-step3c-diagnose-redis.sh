#!/bin/bash
# =========================================================================
# Vault Cấp Cứu — STEP 3C: Diagnose Redis connectivity (root cause #2)
# =========================================================================
# Tất cả pod app đều fail readiness vì laravel-queue worker không connect được
# Redis (timeout/refused). Khi vault chết, không ai để ý Redis cũng có vấn đề.
# Đây là root cause RIÊNG biệt với Vault. KHÔNG fix bằng cách touch Vault.
#
# Hypothesis cần verify:
#   1. Cilium CNP nào block egress đến :6379?
#   2. allow-internal-redis CNP có label selector ĐÚNG cho redis pods không?
#   3. default-deny-all VALID=False → có thật sự allow-all không?
#   4. Service redis có endpoint không? Port mapping đúng không?
#   5. Tetragon kill /usr/bin/redis-cli khi laravel-queue runs?
# =========================================================================
set -u

echo "===== A. Service + endpoint của các Redis ====="
kubectl get svc -n job7189-apps -l 'app.kubernetes.io/name=redis' 2>/dev/null
kubectl get svc -n job7189-apps | grep -i redis
echo ---
for s in candidate communication hiring storage workspace identity job; do
  SVC="${s}-service-redis"
  echo "--- $SVC ---"
  kubectl get svc -n job7189-apps "$SVC" -o jsonpath='{.spec.selector}{"\tport="}{.spec.ports[0].port}{"\ttargetPort="}{.spec.ports[0].targetPort}{"\n"}' 2>/dev/null || echo "  KHÔNG có service $SVC"
  kubectl get endpoints -n job7189-apps "$SVC" -o jsonpath='{range .subsets[*]}{range .addresses[*]}{.ip}{","}{end}{":"}{range .ports[*]}{.port}{","}{end}{"\n"}{end}' 2>/dev/null
done

echo
echo "===== B. Labels của redis pod xem có match service selector không ====="
kubectl get pod -n job7189-apps -l 'app=candidate-service-redis' --show-labels 2>/dev/null | head -5
kubectl get pod -n job7189-apps -l 'app.kubernetes.io/name=redis' --show-labels 2>/dev/null | head -5
echo "--- tất cả pod redis (label dù gì) ---"
kubectl get pod -n job7189-apps | grep -i redis
echo "--- chi tiết labels của 1 pod redis bất kỳ ---"
REDIS_POD=$(kubectl get pod -n job7189-apps -o jsonpath='{.items[?(@.metadata.labels.app=="candidate-service-redis")].metadata.name}' 2>/dev/null | awk '{print $1}')
[ -z "$REDIS_POD" ] && REDIS_POD=$(kubectl get pod -n job7189-apps | grep candidate.*redis | head -1 | awk '{print $1}')
echo "REDIS_POD=$REDIS_POD"
kubectl get pod -n job7189-apps "$REDIS_POD" --show-labels 2>/dev/null | head -3
kubectl get pod -n job7189-apps "$REDIS_POD" -o jsonpath='{range .spec.containers[*]}{.name}{"  image="}{.image}{"  port="}{range .ports[*]}{.containerPort}{","}{end}{"\n"}{end}' 2>/dev/null

echo
echo "===== C. Cilium NetworkPolicy trong ns job7189-apps ====="
kubectl get cnp -n job7189-apps
kubectl get networkpolicy -n job7189-apps 2>/dev/null
echo
echo "--- allow-internal-redis (full spec) ---"
kubectl get cnp -n job7189-apps allow-internal-redis -o yaml 2>/dev/null | sed -n '/^spec:/,/^status:/p' | head -50
echo
echo "--- default-deny-all (validity) ---"
kubectl get cnp -n job7189-apps default-deny-all -o jsonpath='{.status.conditions}{"\n"}' 2>/dev/null
echo
echo "--- L7 vault-api allowlist ---"
kubectl get cnp -n job7189-apps l7-vault-api-allowlist -o yaml 2>/dev/null | sed -n '/^spec:/,/^status:/p' | head -40

echo
echo "===== D. .env file trong pod chưa-ready: REDIS_HOST/PORT/PASSWORD ====="
APP_POD=$(kubectl get pod -n job7189-apps -l app=candidate-service --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | awk '{print $1}')
[ -z "$APP_POD" ] && APP_POD=$(kubectl get pod -n job7189-apps | grep candidate-service- | grep Running | head -1 | awk '{print $1}')
echo "APP_POD=$APP_POD"
if [ -n "$APP_POD" ]; then
  echo "--- /app-secrets/.env (chỉ in REDIS + DB + APP_KEY) ---"
  kubectl exec -n job7189-apps "$APP_POD" -c env-loader -- sh -c 'cat /app-secrets/.env 2>/dev/null | grep -iE "^(REDIS_|DB_|APP_KEY|APP_ENV|CACHE_|QUEUE_)" | sed -E "s/(PASSWORD|TOKEN|SECRET)=.*/\\1=***REDACTED***/g"' 2>&1 || echo "(không exec được)"
fi

echo
echo "===== E. Thử connect Redis từ pod app (TCP+ping) ====="
if [ -n "$APP_POD" ]; then
  echo "--- nc -zv candidate-service-redis 6379 ---"
  kubectl exec -n job7189-apps "$APP_POD" -c app -- sh -c 'nc -zv candidate-service-redis 6379 2>&1; echo exit=$?' 2>&1 | tail -5 || echo "(no nc trong app)"
  echo "--- timeout 5 redis-cli -h candidate-service-redis ping ---"
  kubectl exec -n job7189-apps "$APP_POD" -c app -- sh -c 'redis-cli -h candidate-service-redis -p 6379 ping 2>&1; echo exit=$?' 2>&1 | tail -5 || echo "(no redis-cli)"
  echo "--- /etc/resolv.conf ---"
  kubectl exec -n job7189-apps "$APP_POD" -c app -- cat /etc/resolv.conf 2>&1 | head -5
  echo "--- nslookup candidate-service-redis.job7189-apps.svc ---"
  kubectl exec -n job7189-apps "$APP_POD" -c app -- sh -c 'getent hosts candidate-service-redis 2>&1; getent hosts candidate-service-redis.job7189-apps.svc.cluster.local 2>&1' 2>&1 | head -5
fi

echo
echo "===== F. Tetragon policy có ăn redis-cli/php-fpm exec không? ====="
kubectl get tracingpolicynamespaced -n job7189-apps
kubectl get tracingpolicynamespaced -n job7189-apps -o yaml 2>/dev/null | grep -B 2 -A 6 'values:' | head -40

echo
echo "===== G. Direct test từ debug pod tới redis svc IP ====="
REDIS_SVC_IP=$(kubectl get svc -n job7189-apps candidate-service-redis -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
echo "REDIS_SVC_IP=$REDIS_SVC_IP"
if [ -n "$REDIS_SVC_IP" ]; then
  kubectl run -n job7189-apps redis-probe --rm -i --restart=Never --image=busybox:1.36 --timeout=20s \
    --overrides='{"spec":{"tolerations":[{"operator":"Exists"}]}}' \
    -- sh -c "echo --- ping; ping -c 2 -W 2 $REDIS_SVC_IP 2>&1; echo --- nc; nc -zv $REDIS_SVC_IP 6379 2>&1; echo exit=\$?" 2>&1 | tail -15
fi

echo
echo "===== H. ReplicaSet drift hiện tại (n RS active, replicas) ====="
kubectl get rs -n job7189-apps -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,AGE:.metadata.creationTimestamp 2>/dev/null | head -30

echo
echo "===== DONE ====="
