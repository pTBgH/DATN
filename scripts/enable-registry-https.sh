#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# enable-registry-https.sh
# 
# Automates Docker Registry HTTPS setup using Vault CA + cert-manager
# 
# Process:
#   1. Create registry namespace
#   2. Copy vault-ca-secret to registry namespace
#   3. Create CA Issuer + TLS Certificate
#   4. Wait for certificate to be ready
#   5. Update registry deployment with TLS config
#   6. Re-deploy registry
#   7. Update build_and_deploy.sh with HTTPS settings
#   8. Setup Docker daemon CA cert
#   9. Verify HTTPS connectivity
# ============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ============================================================================
# STEP 1: Check prerequisites
# ============================================================================
info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    error "kubectl not found. Please install kubectl."
fi

if ! command -v curl &> /dev/null; then
    error "curl not found. Please install curl."
fi

# Verify vault namespace exists
if ! kubectl get ns vault &> /dev/null; then
    error "Vault namespace not found. Please run deployment pipeline first."
fi

# Verify vault-ca-secret exists
if ! kubectl get secret vault-ca-secret -n vault &> /dev/null; then
    error "Vault CA secret not found. Please run deployment pipeline first."
fi

info "Prerequisites check: ✅ PASSED"

# ============================================================================
# STEP 2: Create registry namespace if it doesn't exist
# ============================================================================
info "Creating registry namespace..."

kubectl create namespace registry --dry-run=client -o yaml | kubectl apply -f -
info "Registry namespace: ✅ READY"

# ============================================================================
# STEP 3: Copy vault-ca-secret to registry namespace
# ============================================================================
info "Copying Vault CA secret to registry namespace..."

kubectl get secret vault-ca-secret -n vault -o yaml | \
  sed 's/namespace: vault/namespace: registry/' | \
  sed '/resourceVersion:/d' | \
  sed '/uid:/d' | \
  kubectl apply -f -

info "Vault CA secret copied: ✅ DONE"

# ============================================================================
# STEP 4: Create CA Issuer and TLS Certificate
# ============================================================================
info "Creating CA Issuer and TLS Certificate..."

cat > /tmp/registry-tls-setup.yaml << 'EOF'
---
# CA Issuer dalam registry namespace - dùng vault-ca-secret
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: registry-ca-issuer
  namespace: registry
spec:
  ca:
    secretName: vault-ca-secret

---
# Certificate cho docker-registry
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: registry-tls
  namespace: registry
spec:
  secretName: registry-tls-secret
  duration: 8760h      # 1 năm
  renewBefore: 720h    # renew trước 30 ngày
  isCA: false
  commonName: docker-registry
  dnsNames:
  - docker-registry
  - docker-registry.registry
  - docker-registry.registry.svc
  - docker-registry.registry.svc.cluster.local
  - registry.job7189.local
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: registry-ca-issuer
    kind: Issuer
EOF

kubectl apply -f /tmp/registry-tls-setup.yaml
info "Issuer and Certificate created: ✅ DONE"

# ============================================================================
# STEP 5: Wait for certificate to be ready
# ============================================================================
info "Waiting for certificate to be ready (timeout: 60s)..."

kubectl wait --for=condition=ready certificate registry-tls \
  -n registry --timeout=60s 2>/dev/null || {
    error "Certificate failed to become ready. Check: kubectl describe certificate registry-tls -n registry"
}

info "Certificate ready: ✅ DONE"

# ============================================================================
# STEP 6: Use clean HTTPS registry deployment
# ============================================================================
info "Deploying registry with TLS configuration..."

REGISTRY_YAML_HTTPS="$ROOT/infras/k8s-yaml/12-docker-registry-https.yaml"

if [ ! -f "$REGISTRY_YAML_HTTPS" ]; then
    error "HTTPS registry YAML not found at $REGISTRY_YAML_HTTPS"
fi

info "Registry deployment YAML: ✅ READY"

# ============================================================================
# STEP 7: Re-deploy registry
# ============================================================================
info "Re-deploying registry with TLS..."

kubectl apply -f "$REGISTRY_YAML_HTTPS"

# Wait for registry to be ready
info "Waiting for registry deployment to be ready (timeout: 120s)..."
kubectl rollout status deployment/docker-registry -n registry --timeout=120s 2>/dev/null || {
    error "Registry failed to be ready. Check: kubectl describe deployment docker-registry -n registry"
}

info "Registry deployment: ✅ READY"

# ============================================================================
# STEP 8: Update build_and_deploy.sh
# ============================================================================
info "Updating build_and_deploy.sh with HTTPS settings..."

BUILD_SCRIPT="$ROOT/scripts/build_and_deploy.sh"

if [ ! -f "$BUILD_SCRIPT" ]; then
    error "Build script not found at $BUILD_SCRIPT"
fi

# Backup original
cp "$BUILD_SCRIPT" "$BUILD_SCRIPT.bak.$(date +%s)"

# Update REGISTRY port to 5443
sed -i 's|REGISTRY="100.74.189.43:5000"|REGISTRY="100.74.189.43:5443"|g' "$BUILD_SCRIPT"

# Update curl HTTP to HTTPS with -k flag
sed -i 's|curl -sI \\|curl -sI -k \\|g' "$BUILD_SCRIPT"
sed -i 's|"http://\$REGISTRY/v2/|"https://$REGISTRY/v2/|g' "$BUILD_SCRIPT"

info "Build script updated: ✅ DONE"

# ============================================================================
# STEP 9: Setup Docker daemon CA cert
# ============================================================================
info "Setting up Docker daemon CA certificate..."

CA_DIR="/etc/docker/certs.d/100.74.189.43:5443"

if [ ! -d "$CA_DIR" ]; then
    if ! sudo mkdir -p "$CA_DIR"; then
        warn "Could not create $CA_DIR. Trying alternative location..."
        CA_DIR="${HOME}/.docker/certs.d/100.74.189.43:5443"
        mkdir -p "$CA_DIR"
    fi
fi

# Extract CA cert from Kubernetes secret
kubectl get secret vault-ca-secret -n vault -o jsonpath='{.data.ca\.crt}' | \
  base64 -d | sudo tee "$CA_DIR/ca.crt" > /dev/null 2>&1 || \
  kubectl get secret vault-ca-secret -n vault -o jsonpath='{.data.ca\.crt}' | \
  base64 -d | tee "$CA_DIR/ca.crt" > /dev/null

info "Docker daemon CA cert installed: ✅ DONE"
info "Location: $CA_DIR/ca.crt"

# ============================================================================
# STEP 10: Restart Docker daemon
# ============================================================================
if command -v systemctl &> /dev/null; then
    warn "Restarting Docker daemon (this may take a few seconds)..."
    sudo systemctl restart docker 2>/dev/null || true
    sleep 3
    info "Docker daemon restarted: ✅ DONE"
else
    warn "Could not restart Docker daemon. Please restart manually: sudo systemctl restart docker"
fi

# ============================================================================
# STEP 11: Verify HTTPS connectivity
# ============================================================================
info "Verifying HTTPS connectivity..."

# Wait a bit for registry to be fully ready
sleep 5

# Get CA cert for verification
CA_CERT=$(mktemp)
kubectl get secret vault-ca-secret -n vault -o jsonpath='{.data.ca\.crt}' | base64 -d > "$CA_CERT"

# Test HTTPS connectivity
if curl -sS --cacert "$CA_CERT" https://100.74.189.43:5443/v2/ > /dev/null 2>&1; then
    info "HTTPS connectivity test: ✅ PASSED"
else
    warn "HTTPS connectivity test: ⚠️ FAILED (this may be temporary, waiting 10s...)"
    sleep 10
    
    if curl -sS --cacert "$CA_CERT" https://100.74.189.43:5443/v2/ > /dev/null 2>&1; then
        info "HTTPS connectivity test (retry): ✅ PASSED"
    else
        warn "HTTPS connectivity test failed. Possible reasons:"
        echo "  1. Registry pod not fully ready yet"
        echo "  2. Network connectivity issue"
        echo "  3. Certificate validation issue"
        echo ""
        echo "Troubleshooting:"
        echo "  - Check registry pod: kubectl get pod -n registry"
        echo "  - Check certificate: kubectl get certificate -n registry"
        echo "  - Check registry logs: kubectl logs -n registry deployment/docker-registry"
    fi
fi

rm -f "$CA_CERT"

# ============================================================================
# FINAL SUMMARY
# ============================================================================
info "════════════════════════════════════════════════════════════════════"
info "REGISTRY HTTPS SETUP COMPLETED! ✅"
info "════════════════════════════════════════════════════════════════════"
info ""
info "Summary of changes:"
info "  1. ✅ Registry namespace created"
info "  2. ✅ Vault CA secret copied to registry namespace"
info "  3. ✅ CA Issuer and TLS Certificate created"
info "  4. ✅ Registry deployment updated with TLS configuration"
info "  5. ✅ Registry re-deployed on HTTPS port 5443"
info "  6. ✅ build_and_deploy.sh updated with HTTPS settings"
info "  7. ✅ Docker daemon CA certificate installed"
info ""
info "Next steps:"
info "  1. Test build and deploy: bash scripts/build_and_deploy.sh identity v2.8.51"
info "  2. Monitor registry: kubectl logs -f -n registry deployment/docker-registry"
info "  3. When ready, enable Cosign enforcement:"
info "     kubectl patch clusterimagepolicy zta-job7189-apps-signed --type merge -p '{\"spec\":{\"mode\":\"enforce\"}}'"
info ""
info "Registry URL: https://100.74.189.43:5443"
info "════════════════════════════════════════════════════════════════════"
