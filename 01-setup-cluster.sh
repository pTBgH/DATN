#!/bin/bash
# Part 1: Setup Kubernetes Cluster & Core Components
#
# KIND-ONLY: this script creates a single-host Kind cluster and is kept
# behind --kind / ZTA_CLUSTER_MODE=kind so the legacy local-dev workflow
# still works. Default mode is VM (4-node kubeadm cluster) — in that mode
# this script refuses to run and points to doc/migration/scripts/bootstrap.sh.
# See scripts/utils/zta-cluster-mode.sh for the full mode contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"
# shellcheck source=scripts/utils/zta-cluster-mode.sh
source "$SCRIPT_DIR/scripts/utils/zta-cluster-mode.sh"

# Parse --kind / --vm flag; remaining args (none expected by this script)
# are preserved into $@.
zta_parse_mode_flag "$@"
eval "$(zta_apply_parsed_args_cmd)"
zta_mode_banner "01-setup-cluster.sh"

# Refuse to run in VM mode — destructive (would `kind delete cluster`).
zta_require_kind "01-setup-cluster.sh" "doc/migration/scripts/bootstrap.sh"

# ==================== TIMING FUNCTIONS ====================
SCRIPT_START_TIME=$(date +%s)
STEP_START_TIME=$SCRIPT_START_TIME
declare -A STEP_TIMES

log_time() {
  local step_name=$1
  local current_time=$(date +%s)
  local elapsed=$((current_time - STEP_START_TIME))
  STEP_TIMES["$step_name"]=$elapsed
  echo "?  [$step_name] Duration: ${elapsed}s"
  STEP_START_TIME=$current_time
}

print_summary() {
  local total_time=$(($(date +%s) - SCRIPT_START_TIME))
  echo ""
  echo "????????????????????????????????????????????????"
  echo "? PART 1: CLUSTER SETUP - TIMING SUMMARY"
  echo "????????????????????????????????????????????????"
  for step in "${!STEP_TIMES[@]}"; do
    printf "  %-45s %3ds\n" "$step" "${STEP_TIMES[$step]}"
  done | sort
  echo "------------------------------------------------"
  printf "  %-45s %3ds\n" "TOTAL" "$total_time"
  echo "????????????????????????????????????????????????"
}

trap print_summary EXIT

# ==================== CONFIGURATION ====================
CLUSTER_NAME="job7189"
CILIUM_VERSION="1.19.1"
CERT_MANAGER_VERSION="v1.14.7"

# ==================== SCRIPT START ====================
echo ""
echo "????????????????????????????????????????????????????????????"
echo "?  PART 1: CLUSTER SETUP & CORE COMPONENTS                 ?"
echo "?  Status: Setting up Kind cluster, Cilium, cert-manager   ?"
echo "????????????????????????????????????????????????????????????"
echo ""

# read -p "? Continue with cluster setup? (yes/no): " answer
# [[ "$answer" == "yes" ]] || exit 1

# ========================
# Step 1: Cleanup
# ========================
echo "? [1/10] Cleaning up old cluster..."
kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
log_time "1. Cleanup old cluster"

# ========================
# Step 2: Create Kind Cluster
# ========================
echo "? [2/10] Creating Kind cluster..."
kind create cluster \
  --config infras/kind/kind-config.yaml \
  --name $CLUSTER_NAME
log_time "2. Create Kind cluster"

# ========================
# Step 3: Add Helm Repos
# ========================
echo "? [3/10] Adding Helm repositories..."
helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
wait_for_dns helm.cilium.io helm.releases.hashicorp.com kubernetes.github.io
helm_repo_update_retry cilium hashicorp ingress-nginx
log_time "3. Add Helm repos"

# ========================
# Pre-Step 4: Wait for cluster API readiness
# ========================
# The Kind cluster API server can take extra time to complete TLS setup after
# `kind create cluster` returns. If kubectl tries to validate manifests (OpenAPI
# schema download) before the API server is fully up, it hits a TLS handshake
# timeout. This loop waits until the API server is reachable before proceeding.
echo "? [Pre-4] Waiting for Kubernetes API server to be ready..."
_cluster_wait_max=120
_cluster_wait_interval=5
_cluster_wait_elapsed=0
until kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; do
  if [ "$_cluster_wait_elapsed" -ge "$_cluster_wait_max" ]; then
    echo "    ! WARNING: cluster API not ready after ${_cluster_wait_max}s, proceeding anyway"
    break
  fi
  echo "    ... API not ready yet (${_cluster_wait_elapsed}s elapsed), retrying in ${_cluster_wait_interval}s"
  sleep "$_cluster_wait_interval"
  _cluster_wait_elapsed=$((_cluster_wait_elapsed + _cluster_wait_interval))
done
echo "    ? Cluster API is ready (${_cluster_wait_elapsed}s waited)"

# ========================
# Step 4: Install Gateway API CRDs
# ========================
echo "? [4/10] Installing Gateway API CRDs..."
wait_for_dns github.com
# --validate=false skips client-side OpenAPI schema validation, avoiding a
# second TLS handshake to the API server that can time out on slow starts.
# Server-side apply (--server-side) still enforces correctness on the server.
kubectl apply --server-side --validate=false -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
log_time "4. Install Gateway API v1.1.0"

# ========================
# Step 5: Install Cilium CNI
# ========================
echo "? [5/10] Installing Cilium CNI (stability baseline: Plain HTTP, no WireGuard)..."
echo "    Stability-first mode: encryption.enabled=false, authentication.enabled=false"

# Use Helm upgrade/install (atomic) to ensure reproducible config
helm upgrade --install cilium cilium/cilium \
  --version $CILIUM_VERSION \
  --namespace kube-system \
  -f k8s-management/cilium/cilium-values.yaml \
  --set image.pullPolicy=IfNotPresent \
  --set encryption.enabled=false \
  --set authentication.enabled=false \
  --reuse-values \
  --wait --timeout 10m
log_time "5a. Install Cilium"

echo "    Waiting for Cilium operator to be ready (up to 5m) and then Cilium agents..."

echo "    Current pod status:"
kubectl get pod -n kube-system -l k8s-app=cilium -o wide 2>/dev/null || echo "    (pods not created yet)"

echo "    Checking cilium-operator rollout status (fast check follows shortly)"

# Ensure the Cilium DaemonSet rollout completes (single clean check)
echo "    Waiting for cilium DaemonSet rollout status (up to 180s)"
if kubectl -n kube-system rollout status ds/cilium --timeout=180s; then
  echo "    ? cilium DaemonSet rollout succeeded"
else
  echo "    ! WARNING: cilium DaemonSet rollout did not complete within 180s"
  kubectl -n kube-system get daemonset cilium -o wide || true
  kubectl -n kube-system get pods -l k8s-app=cilium -o wide || true
  kubectl -n kube-system get events --sort-by='.lastTimestamp' | tail -n 10 || true
fi

# Verify BPF mounting on at least one running cilium agent pod
echo "    Verifying BPF mount on cilium agent pods"
POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -n1 || true)
if [ -n "$POD" ]; then
  if kubectl -n kube-system exec $POD -c cilium-agent -- test -d /sys/fs/bpf/cilium >/dev/null 2>&1; then
    echo "    ? /sys/fs/bpf/cilium is mounted inside $POD"
  else
    echo "    ! /sys/fs/bpf/cilium not present inside $POD — dumping mount info"
    kubectl -n kube-system exec $POD -c cilium-agent -- mount | sed -n '1,200p' || true
  fi
fi

# Fast-Mode: targeted waits for Cilium operator and agent pods (short, non-blocking)
echo "    Fast-Mode: waiting up to 180s for Cilium operator and agent pods to become Ready; warnings printed on timeout."

# 1) Wait for cilium-operator rollout (3 minutes)
if kubectl -n kube-system rollout status deployment/cilium-operator --timeout=180s; then
  echo "    ? cilium-operator rollout succeeded"
else
  echo "    ! WARNING: cilium-operator rollout did not succeed within 180s"
  echo "    Recent kube-system events (last 10):"
  kubectl get events -n kube-system --sort-by='.lastTimestamp' | tail -n 10 || true
fi

# 2) Wait for cilium agent pods to become Ready (3 minutes)
if kubectl wait --for=condition=Ready=True pod -l k8s-app=cilium -n kube-system --timeout=180s 2>/dev/null; then
  echo "    ? cilium agent pods are Ready"
else
  echo "    ! WARNING: cilium agent pods did not become Ready within 180s"
  kubectl -n kube-system get pods -l k8s-app=cilium -o wide || true
  kubectl get events -n kube-system --sort-by='.lastTimestamp' | tail -n 10 || true
fi

# ========================
# Step 5c: Stability-first policy posture
# ========================
echo "? [5c] Stability-first: skipping strict app policies during baseline"
echo "    Security policies will be applied after all pods are 1/1 Ready"

# Post-upgrade: keep Cilium L7 proxy enabled but WireGuard and mesh-auth disabled.
echo "    Ensuring cilium-config keys: enable-wireguard=false, enable-l7-proxy=true, mesh-auth-enabled=false"
kubectl -n kube-system patch configmap cilium-config --type merge -p '{"data":{"enable-wireguard":"false","enable-l7-proxy":"true","mesh-auth-enabled":"false"}}' || true


# ========================
# Verification (end of Step 5)
# ========================
echo "? Verifying Cilium Encryption and Mesh Auth status"
kubectl -n kube-system get pods -l k8s-app=cilium -o wide || true
POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -n1)
if [ -n "$POD" ]; then
  kubectl -n kube-system exec $POD -c cilium-agent -- /usr/bin/cilium status || true
  kubectl -n kube-system exec $POD -c cilium-agent -- /usr/bin/cilium config | grep -i mesh-auth -n -C 2 || true
fi

# ========================
# Step 5d: Post-check Hubble components
# ========================
echo "🔍 [5d] Checking Hubble relay and UI..."
if kubectl -n kube-system get deploy hubble-relay >/dev/null 2>&1; then
  if kubectl -n kube-system rollout status deploy/hubble-relay --timeout=120s 2>/dev/null; then
    echo "    ✓ Hubble Relay is Ready"
  else
    echo "    ⚠ Hubble Relay not ready (non-blocking)"
  fi
else
  echo "    ⚠ Hubble Relay deployment not found"
fi

if kubectl -n kube-system get deploy hubble-ui >/dev/null 2>&1; then
  if kubectl -n kube-system rollout status deploy/hubble-ui --timeout=120s 2>/dev/null; then
    echo "    ✓ Hubble UI is Ready"
  else
    echo "    ⚠ Hubble UI not ready (non-blocking)"
  fi
else
  echo "    ⚠ Hubble UI deployment not found"
fi
log_time "5d. Hubble post-check"

# ========================
# Step 6: Create Namespaces
# ========================
echo "? [6/10] Creating namespaces..."
for ns in gateway security management data job7189-apps monitoring vault; do
  kubectl create namespace $ns 2>/dev/null || echo "    $ns already exists"
done
log_time "6. Create namespaces"

# ========================
# Step 7: Install cert-manager
# ========================
echo "? [7/10] Installing cert-manager..."
wait_for_dns github.com
kubectl apply -f \
  "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
log_time "7a. Install cert-manager"
echo "    Waiting for cert-manager CRDs and core components to become healthy"
kubectl wait --for=condition=Established crd/certificates.cert-manager.io --timeout=180s >/dev/null 2>&1 || true
kubectl wait --for=condition=Established crd/issuers.cert-manager.io --timeout=180s >/dev/null 2>&1 || true
kubectl wait --for=condition=Established crd/clusterissuers.cert-manager.io --timeout=180s >/dev/null 2>&1 || true

if kubectl -n cert-manager rollout status deploy/cert-manager --timeout=240s \
  && kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=240s \
  && kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=240s; then
  echo "    ? cert-manager controller, cainjector, webhook are Ready"
else
  echo "    ! WARNING: cert-manager is not fully healthy yet"
  kubectl -n cert-manager get pods -o wide || true
  kubectl get events -n cert-manager --sort-by='.lastTimestamp' | tail -n 10 || true
fi
log_time "7b. Cert-manager quick-check"

# ========================
# Step 8: Install Nginx Ingress Controller
# ========================
echo "? [8/10] Installing Nginx Ingress Controller..."
wait_for_dns raw.githubusercontent.com
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.0/deploy/static/provider/kind/deploy.yaml
log_time "8a. Install Nginx Ingress"
echo "    Waiting up to 180s for ingress-nginx controller pods to become Ready"
if kubectl wait --for=condition=Ready=True pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=180s 2>/dev/null; then
  echo "    ? ingress-nginx controller ready"
else
  echo "    ! WARNING: ingress-nginx controller did not become Ready within 180s"
  kubectl -n ingress-nginx get pods -o wide || true
  kubectl get events -n ingress-nginx --sort-by='.lastTimestamp' | tail -n 10 || true
fi
log_time "8b. Ingress quick-check"

# ========================
# Step 9: Install metrics-server (kubelet-insecure-tls vì Kind dùng self-signed)
# ========================
# Diag tháng 4/2026 phát hiện metrics-server không có sẵn → `kubectl top` fail
# → bundle troubleshoot không có dữ liệu CPU/RAM thật. Cài luôn ở Phase 1 để
# 09-verify-zta.sh và mọi diag script sau này có metrics.
echo "🔧 [9/10] Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm_repo_update_retry metrics-server || helm repo update metrics-server 2>/dev/null || true
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args={--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\,Hostname\,ExternalIP}' \
  --set replicas=1 \
  --set 'resources.requests.cpu=20m' \
  --set 'resources.requests.memory=64Mi' \
  --set 'resources.limits.cpu=200m' \
  --set 'resources.limits.memory=200Mi' \
  --wait --timeout=300s || echo "    ! WARNING: metrics-server install failed (non-blocking)"

# After helm install --wait returns, the metrics-server pod is Ready but its
# scrape loop hasn't populated samples yet. zta-deploy-*.sh pre-flight checks
# call `kubectl top node` early in the next phase and silently fall back to
# "kubectl top node unavailable" → masks a working cluster as unverifiable.
# Poll until we get at least one row, up to 120s.
echo "    waiting for metrics-server to populate samples..."
metrics_ready=0
for i in $(seq 1 24); do
  if kubectl top node --no-headers 2>/dev/null | grep -q .; then
    echo "    ✓ kubectl top nodes returns data (after $((i*5))s)"
    metrics_ready=1
    break
  fi
  sleep 5
done
if [ "$metrics_ready" -eq 0 ]; then
  echo "    ! WARNING: kubectl top nodes still empty after 120s"
  echo "    Diagnose: kubectl -n kube-system logs deploy/metrics-server --tail=40"
  kubectl -n kube-system get pod -l app.kubernetes.io/name=metrics-server -o wide 2>/dev/null || true
fi
log_time "9. Install metrics-server"

# ========================
# Step 10: Pre-pull external images vào Kind nodes
# ========================
# Diag tháng 4/2026: oauth2-proxy bị 27 lần CrashLoopBackOff vì
# `quay.io/oauth2-proxy/oauth2-proxy:latest` TLS handshake timeout trên VMware
# NAT. Pre-pull về host rồi `kind load` đảm bảo node có cache → imagePullPolicy
# IfNotPresent không cần internet.
echo "📦 [10/10] Pre-loading external images into kind nodes..."
EXTERNAL_IMAGES=(
  "quay.io/oauth2-proxy/oauth2-proxy:v7.6.0"
)
for img in "${EXTERNAL_IMAGES[@]}"; do
  echo "    pulling ${img}..."
  if docker pull "${img}" >/dev/null 2>&1; then
    if kind load docker-image "${img}" --name "${CLUSTER_NAME}" >/dev/null 2>&1; then
      echo "    ✓ ${img} loaded into all kind nodes"
    else
      echo "    ! WARNING: kind load failed for ${img} (image will be pulled at runtime)"
    fi
  else
    echo "    ! WARNING: docker pull failed for ${img} (will retry at runtime)"
  fi
done
log_time "10. Pre-load external images"

# ========================
# COMPLETED
# ========================
echo ""
echo "? PART 1 COMPLETED: Cluster is ready for infrastructure deployment"
echo ""
echo "Next steps:"
echo "  1. Run: bash 02-deploy-infrastructure.sh"
echo "  2. Wait for services to stabilize"
echo "  3. Run: bash 03-deploy-microservices.sh"
echo ""
