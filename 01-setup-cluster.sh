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
helm upgrade --install cilium cilium/cilium \
  --version $CILIUM_VERSION \
  --namespace kube-system \
  -f k8s-management/cilium/cilium-values.yaml \
  --set image.pullPolicy=IfNotPresent
log_time "5a. Install Cilium"

echo "    Waiting for Cilium pods to be ready..."
echo "    Current pod status:"
kubectl get pod -n kube-system -l k8s-app=cilium -o wide 2>/dev/null || echo "    (pods not created yet)"

if kubectl wait --for=condition=Ready=True pod \
  -l k8s-app=cilium \
  -n kube-system \
  --timeout=300s 2>/dev/null; then
  echo "    ? Cilium ready"
else
  echo "?  Cilium wait timeout - checking status..."
  kubectl get pod -n kube-system -l k8s-app=cilium || true
  echo "    (Continuing anyway...)"
fi
log_time "5b. Wait for Cilium ready"

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

echo "    Waiting for cert-manager webhook to be ready..."
echo "    Current pod status:"
kubectl get pod -n cert-manager -o wide 2>/dev/null || echo "    (namespace not ready yet)"

if kubectl wait --for=condition=Ready=True pod \
  -l app.kubernetes.io/component=webhook \
  -n cert-manager \
  --timeout=180s 2>/dev/null; then
  echo "    ? cert-manager ready"
else
  echo "?  cert-manager wait timeout - checking status..."
  kubectl get pod -n cert-manager || true
  echo "    (Continuing anyway...)"
fi
log_time "7b. Wait for cert-manager ready"

# ========================
# Step 8: Install Nginx Ingress Controller
# ========================
echo "? [8/8] Installing Nginx Ingress Controller..."
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.0/deploy/static/provider/kind/deploy.yaml
log_time "8a. Install Nginx Ingress"

echo "    Waiting for Nginx controller to be ready..."
echo "    Current pod status:"
kubectl get pod -n ingress-nginx -o wide 2>/dev/null || echo "    (namespace not ready yet)"

if kubectl wait --for=condition=Ready=True pod \
  -l app.kubernetes.io/component=controller \
  -n ingress-nginx \
  --timeout=600s 2>/dev/null; then
  echo "    ? Nginx Ingress ready"
else
  echo "?  Nginx Ingress wait timeout - checking status..."
  kubectl get pod -n ingress-nginx || true
  echo "    (Continuing anyway...)"
fi
log_time "8b. Wait for Nginx Ingress ready"

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
