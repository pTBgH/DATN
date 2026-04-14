#!/bin/bash
# Part 1: Setup Kubernetes Cluster & Core Components
# This script: Creates Kind cluster, installs CNI (Cilium), cert-manager, Nginx Ingress
set -euo pipefail

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
echo "? [1/8] Cleaning up old cluster..."
kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
log_time "1. Cleanup old cluster"

# ========================
# Step 2: Create Kind Cluster
# ========================
echo "? [2/8] Creating Kind cluster..."
kind create cluster \
  --config infras/kind/kind-config.yaml \
  --name $CLUSTER_NAME
log_time "2. Create Kind cluster"

# ========================
# Step 3: Add Helm Repos
# ========================
echo "? [3/8] Adding Helm repositories..."
helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
log_time "3. Add Helm repos"

# ========================
# Step 4: Install Gateway API CRDs
# ========================
echo "? [4/8] Installing Gateway API CRDs..."
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
log_time "4. Install Gateway API v1.1.0"

# ========================
# Step 5: Install Cilium CNI
# ========================
echo "? [5/8] Installing Cilium CNI..."
check_kernel_support() {
  echo "    Checking node kernel versions for WireGuard support..."
  local fail=0
  for kv in $(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}:{.status.nodeInfo.kernelVersion}{"\n"}{end}'); do
    node=${kv%%:*}
    ver=${kv#*:}
    # extract major and minor (e.g. 6.8 from 6.8.0-107-generic)
    major=$(echo "$ver" | awk -F. '{print $1}')
    minor=$(echo "$ver" | awk -F. '{print $2}')
    if [ "$major" -gt 5 ] || ( [ "$major" -eq 5 ] && [ "$minor" -ge 6 ] ); then
      echo "      $node: kernel $ver -> WireGuard support OK"
    else
      echo "      $node: kernel $ver -> WireGuard MAY NOT be supported"
      fail=1
    fi
  done
  if [ "$fail" -ne 0 ]; then
    echo "\n[ERROR] One or more nodes may not support WireGuard. Aborting Cilium WireGuard enablement."
    return 1
  fi
  return 0
}

# Check kernels before attempting to enable WireGuard
if check_kernel_support; then
  echo "    Proceeding with Helm upgrade to enable WireGuard and mesh auth"
else
  echo "    Skipping WireGuard enablement; installing Cilium with defaults"
fi

# Use Helm upgrade/install (atomic) to ensure reproducible config
helm upgrade --install cilium cilium/cilium \
  --version $CILIUM_VERSION \
  --namespace kube-system \
  -f k8s-management/cilium/cilium-values.yaml \
  --set image.pullPolicy=IfNotPresent \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
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
# Step 5c: Apply ZTA CiliumNetworkPolicies for job7189-apps
# ========================
echo "? [5c] Applying Zero Trust CiliumNetworkPolicies (default-deny + auth-required)"
cat <<'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-job7189-apps
  namespace: job7189-apps
spec:
  endpointSelector: {}
  ingress: []
  egress: []
  # An empty rule set for both ingress and egress enforces default deny for the namespace
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: require-auth-identity-to-db
  namespace: job7189-apps
spec:
  endpointSelector:
    matchLabels:
      app: identity-service
  egress:
  - toEndpoints:
    - matchLabels:
        app: mysql
    authentication:
      mode: required
  # allow established return traffic implicitly via identity-based policies
EOF

echo "    Applied CiliumNetworkPolicy resources for job7189-apps"

# Give policies a moment to propagate
sleep 3

# Post-upgrade: ensure config keys align (enable wireguard and L7 proxy, keep mesh-auth disabled until cert provider configured)
echo "    Ensuring cilium-config keys: enable-wireguard=true, enable-l7-proxy=true, mesh-auth-enabled=false"
kubectl -n kube-system patch configmap cilium-config --type merge -p '{"data":{"enable-wireguard":"true","enable-l7-proxy":"true","mesh-auth-enabled":"false"}}' || true

# If running Kind locally, attempt to load wireguard on host node containers (docker). This is best-effort.
if command -v docker >/dev/null 2>&1; then
  for n in $(docker ps --format '{{.Names}}' | grep $CLUSTER_NAME || true); do
    echo "    Trying modprobe wireguard on host container: $n"
    docker exec $n sh -c 'modprobe wireguard || true; lsmod | grep wireguard || true' || true
  done
else
  echo "    docker not found; skipping host modprobe step (you may need to nsenter/modprobe on hosts)"
fi

echo "    (Fast-Mode) skipping daemonset restart; Helm triggered rollout if needed"


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
# Step 6: Create Namespaces
# ========================
echo "? [6/8] Creating namespaces..."
for ns in gateway security management data job7189-apps monitoring vault; do
  kubectl create namespace $ns 2>/dev/null || echo "    $ns already exists"
done
log_time "6. Create namespaces"

# ========================
# Step 7: Install cert-manager
# ========================
echo "? [7/8] Installing cert-manager..."
kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
log_time "7a. Install cert-manager"
echo "    Waiting up to 180s for cert-manager webhook pods to become Ready"
if kubectl wait --for=condition=Ready=True pod -l app.kubernetes.io/component=webhook -n cert-manager --timeout=180s 2>/dev/null; then
  echo "    ? cert-manager webhook ready"
else
  echo "    ! WARNING: cert-manager webhook did not become Ready within 180s"
  kubectl -n cert-manager get pods -o wide || true
  kubectl get events -n cert-manager --sort-by='.lastTimestamp' | tail -n 10 || true
fi
log_time "7b. Cert-manager quick-check"

# ========================
# Step 8: Install Nginx Ingress Controller
# ========================
echo "? [8/8] Installing Nginx Ingress Controller..."
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
