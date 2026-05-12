#!/usr/bin/env bash
# doc/migration/scripts/phases/cluster-services.sh
#
# Run with `kubectl` + `helm` configured for the multi-VM cluster.
# Idempotent. Installs:
#   1. Gateway API CRDs (v1.1.0)
#   2. cert-manager (v1.14.7)
#   3. ingress-nginx (NodePort 30001/30003)
#   4. metrics-server
#   5. local-path-provisioner (v0.0.30) + alias 'standard' default storageClass
#
# On error: ROLLBACK uninstalls each helm release in reverse order. CRDs
# from Gateway API are LEFT installed (cluster-wide; user can re-run).
#
# Usage (preferred — via the bootstrap orchestrator):
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=cluster-services
# Or directly:
#   bash doc/migration/scripts/phases/cluster-services.sh

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# After the refactor to phases/, lib/ + config.env live in the parent dir.
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/lib/common.sh"

load_config "${ROOT_DIR}/config.env"
migration_start "cluster-services"

# ===== Pre-flight =====
log_step "Pre-flight"
require_cmd helm kubectl || exit 1
kubectl cluster-info --request-timeout=10s >/dev/null || { log_err "no cluster"; exit 1; }

# Wait for Cilium / nodes Ready before continuing
ready_count="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)"
log_info "Ready nodes: ${ready_count}"
if [ "${ready_count}" -lt 1 ]; then
  log_err "No Ready nodes. Run 04-cilium-install.sh first."
  exit 1
fi

# ===== STEP 1: Gateway API CRDs =====
log_step "[1/5] Gateway API CRDs"
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  step "Apply Gateway API standard install" \
    kubectl apply --server-side --validate=false \
      -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
  # We don't register a rollback for CRDs — removing them would break dependent objects.
else
  log_info "  Gateway API CRDs already present"
fi

# ===== STEP 2: cert-manager =====
log_step "[2/5] cert-manager v1.14.7"
helm repo add jetstack https://charts.jetstack.io --force-update >/dev/null
helm repo update jetstack >/dev/null

if ! helm status -n cert-manager cert-manager >/dev/null 2>&1; then
  register_rollback "helm uninstall cert-manager -n cert-manager >/dev/null 2>&1 || true"
fi

step "helm upgrade --install cert-manager" helm upgrade --install cert-manager jetstack/cert-manager \
  --version v1.14.7 \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --set webhook.timeoutSeconds=30 \
  --wait --timeout 5m

# ===== STEP 3: ingress-nginx =====
log_step "[3/5] ingress-nginx (NodePort ${HTTP_NODEPORT}/${HTTPS_NODEPORT})"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update >/dev/null
helm repo update ingress-nginx >/dev/null

if ! helm status -n ingress-nginx ingress-nginx >/dev/null 2>&1; then
  register_rollback "helm uninstall ingress-nginx -n ingress-nginx >/dev/null 2>&1 || true"
fi

step "helm upgrade --install ingress-nginx" helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version 4.10.0 \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set "controller.service.nodePorts.http=${HTTP_NODEPORT}" \
  --set "controller.service.nodePorts.https=${HTTPS_NODEPORT}" \
  --set controller.metrics.enabled=true \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=90Mi \
  --set controller.resources.limits.cpu=500m \
  --set controller.resources.limits.memory=256Mi \
  --wait --timeout 5m

# ===== STEP 4: metrics-server =====
log_step "[4/5] metrics-server"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update >/dev/null
helm repo update metrics-server >/dev/null

if ! helm status -n kube-system metrics-server >/dev/null 2>&1; then
  register_rollback "helm uninstall metrics-server -n kube-system >/dev/null 2>&1 || true"
fi

step "helm upgrade --install metrics-server" helm upgrade --install metrics-server metrics-server/metrics-server \
  --version 3.12.1 \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --set 'args[1]=--kubelet-preferred-address-types=InternalIP\,Hostname' \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=50Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=100Mi \
  --wait --timeout 5m

# ===== STEP 5: local-path-provisioner + 'standard' alias =====
log_step "[5/5] local-path-provisioner v0.0.30 + 'standard' StorageClass alias"

if ! kubectl get ns local-path-storage >/dev/null 2>&1; then
  step "Apply local-path-provisioner manifest" \
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
  register_rollback "kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml --ignore-not-found"
else
  log_info "  local-path-storage namespace already present"
fi

# Standard alias storage class (default)
SC_FILE="${ZTA_STATE_DIR}/standard-storageclass.yaml"
cat > "${SC_FILE}" <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
register_rollback "kubectl delete -f ${SC_FILE} --ignore-not-found"
step "Apply 'standard' StorageClass alias" kubectl apply -f "${SC_FILE}"

# Demote local-path's default if it set one
if kubectl get sc local-path -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null | grep -q true; then
  step "Demote local-path from default" kubectl patch sc local-path \
    -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
fi

# ===== Verify =====
log_step "Verify"
sleep 10
log_info "  Storage classes:"
kubectl get sc 2>&1 | sed 's/^/    /'
log_info "  Cluster top:"
kubectl top nodes 2>&1 | sed 's/^/    /' || log_warn "  metrics-server not ready yet (give it ~30s)"

migration_end
log_ok "Cluster services up. Cluster is now ready for ZTA deploy phase."
log_info "Next: see 'bash scripts/zta-rebuild.sh --external-cluster --yes' (use repo root)"
