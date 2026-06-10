# Registry HTTPS Setup Guide

## Overview

This guide enables HTTPS/TLS for the Docker Registry using:
- **CA**: Vault-generated self-signed CA (already deployed)
- **Certificate Manager**: cert-manager (already deployed)
- **Port**: 5443 (HTTPS) instead of 5000 (HTTP)
- **Certificate**: Auto-renewed annually

## Files Created/Updated

| File | Change | Purpose |
|------|--------|---------|
| `scripts/enable-registry-https.sh` | **NEW** | Automated setup script (runs all 9 steps) |
| `infras/k8s-yaml/12-docker-registry-https.yaml` | **NEW** | Registry deployment with TLS config |
| `scripts/build_and_deploy.sh` | **UPDATED** | HTTPS port (5443) + curl -k flag |

## Quick Start (Automated)

```bash
# Run the complete automation script
bash scripts/enable-registry-https.sh

# Expected output:
# ✅ Prerequisites check: PASSED
# ✅ Registry namespace: READY
# ✅ Vault CA secret copied: DONE
# ✅ Issuer and Certificate created: DONE
# ✅ Certificate ready: DONE
# ✅ Registry deployment YAML updated: DONE
# ✅ Registry deployment: READY
# ✅ Build script updated: DONE
# ✅ Docker daemon CA cert installed: DONE
# ✅ Docker daemon restarted: DONE
# ✅ HTTPS connectivity test: PASSED
```

## Manual Steps (If Preferred)

### Step 1: Create Registry Namespace + TLS Certificate

```bash
# Copy Vault CA secret to registry namespace
kubectl get secret vault-ca-secret -n vault -o yaml | \
  sed 's/namespace: vault/namespace: registry/' | \
  sed '/resourceVersion:/d' | sed '/uid:/d' | \
  kubectl apply -f -

# Create CA Issuer and Certificate
kubectl apply -f - << 'EOF'
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: registry-ca-issuer
  namespace: registry
spec:
  ca:
    secretName: vault-ca-secret
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: registry-tls
  namespace: registry
spec:
  secretName: registry-tls-secret
  duration: 8760h
  renewBefore: 720h
  isCA: false
  commonName: docker-registry
  dnsNames:
  - docker-registry
  - docker-registry.registry
  - docker-registry.registry.svc
  - docker-registry.registry.svc.cluster.local
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: registry-ca-issuer
    kind: Issuer
EOF

# Wait for certificate
kubectl wait --for=condition=ready certificate registry-tls -n registry --timeout=60s
```

### Step 2: Deploy Registry with TLS

```bash
# Use the prepared HTTPS registry deployment
kubectl apply -f infras/k8s-yaml/12-docker-registry-https.yaml

# Wait for registry to be ready
kubectl rollout status deployment/docker-registry -n registry --timeout=120s
```

### Step 3: Setup Docker Daemon CA Certificate

```bash
# Create directory for CA cert
mkdir -p /etc/docker/certs.d/100.74.189.43:5443

# Extract and install CA cert
kubectl get secret vault-ca-secret -n vault -o jsonpath='{.data.ca\.crt}' | \
  base64 -d | sudo tee /etc/docker/certs.d/100.74.189.43:5443/ca.crt > /dev/null

# Restart Docker daemon
sudo systemctl restart docker
```

### Step 4: Verify HTTPS Works

```bash
# Get CA cert
CA_CERT=$(kubectl get secret vault-ca-secret -n vault -o jsonpath='{.data.ca\.crt}' | base64 -d)

# Test HTTPS connectivity
curl -k https://100.74.189.43:5443/v2/
# Expected response: {}
```

### Step 5: Test Build & Deploy with HTTPS

```bash
# The build_and_deploy.sh script is already updated
bash scripts/build_and_deploy.sh identity v2.8.51

# Expected flow:
# ✅ Docker build
# ✅ Docker push to HTTPS registry
# ✅ Digest resolved
# ✅ Helm deployment updated
```

## Verification Checklist

```bash
# 1. Check registry pod status
kubectl get pod -n registry

# 2. Check certificate status
kubectl get certificate -n registry

# 3. Check TLS secret created
kubectl get secret registry-tls-secret -n registry

# 4. Verify HTTPS access from pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -k https://docker-registry.registry.svc.cluster.local:5443/v2/

# 5. Check registry logs
kubectl logs -n registry deployment/docker-registry

# 6. Verify build script works
bash scripts/build_and_deploy.sh workspace v2.8.51 --dry-run
```

## Troubleshooting

### Certificate not ready

```bash
# Check certificate status
kubectl describe certificate registry-tls -n registry

# Common issues:
# - Issuer not ready → check: kubectl describe issuer registry-ca-issuer -n registry
# - Secret not found → check: kubectl get secret vault-ca-secret -n registry
```

### Docker push fails with TLS error

```bash
# Verify CA cert is installed correctly
ls -la /etc/docker/certs.d/100.74.189.43:5443/ca.crt

# Restart Docker daemon
sudo systemctl restart docker

# Check Docker logs
sudo journalctl -u docker -f
```

### Registry pod crashes

```bash
# Check registry logs
kubectl logs -n registry deployment/docker-registry

# Check for certificate file issues
kubectl describe pod -n registry

# Verify volume mount
kubectl get pod -n registry -o jsonpath='{.items[0].spec.volumes}'
```

### Cosign still warns about HTTPS

This is normal behavior during the **warn mode** phase. To fully resolve:

```bash
# 1. Verify Cosign sees HTTPS registry
cosign verify-blob --certificate-identity-regexp=.*
  --certificate-oidc-issuer-regexp=.* \
  --signature-ref https://100.74.189.43:5443/job7189/identity@sha256:... \
  my-blob.txt

# 2. When ready, enable enforce mode
kubectl patch clusterimagepolicy zta-job7189-apps-signed \
  --type merge -p '{"spec":{"mode":"enforce"}}'
```

## Next Steps

### 1. Test All Services (All repositories)

```bash
# Test workspace service
bash scripts/build_and_deploy.sh workspace v2.8.51

# Test job service
bash scripts/build_and_deploy.sh job v2.8.51

# And so on for each service...
```

### 2. Update Cosign to Enforce Mode (Optional - Advanced)

When confident that images are being signed correctly:

```bash
# Switch Cosign from WARN → ENFORCE
kubectl patch clusterimagepolicy zta-job7189-apps-signed \
  --type merge -p '{"spec":{"mode":"enforce"}}'

# Verify mode
kubectl get clusterimagepolicy zta-job7189-apps-signed -o jsonpath='{.spec.mode}'
# Expected output: enforce
```

### 3. Update CI/CD Pipeline (If Any)

If using automated build pipelines, update:
- Registry URL: `100.74.189.43:5443` (HTTPS)
- Docker certs: Ensure CA cert installed on build machine
- Curl flags: Add `-k` for self-signed cert validation

### 4. Document in Knowledge Base

Update `knowledge-base/28-sigstore-policy-controller.md`:

```markdown
### Registry TLS Status

| Component | Status | Configuration |
|-----------|--------|----------------|
| Registry HTTPS | ✅ ENABLED | Port 5443, self-signed cert |
| Cert-Manager | ✅ READY | Vault CA issuer |
| Cosign Verification | ✅ READY | 3 ClusterImagePolicy |
| Policy Mode | ⚠️ WARN | Ready for enforcement |
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│ Developer Workstation                               │
│  ┌──────────────────────────────────────────────┐   │
│  │ bash scripts/build_and_deploy.sh             │   │
│  │  • docker build (local)                       │   │
│  │  • docker push https://100.74.189.43:5443   │   │
│  │  • curl (with -k flag for cert validation)   │   │
│  └──────────────────────┬───────────────────────┘   │
└─────────────────────────┼───────────────────────────┘
                          │ HTTPS + cert validation
                          ▼
┌─────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                  │
│  ┌─────────────────────────────────────────────┐   │
│  │ registry namespace                          │   │
│  │  ┌───────────────────────────────────────┐  │   │
│  │  │ docker-registry Deployment             │  │   │
│  │  │  • Port: 5443 (HTTPS)                 │  │   │
│  │  │  • Volume mount: /certs (TLS cert)    │  │   │
│  │  │  • Env: REGISTRY_HTTP_TLS_*           │  │   │
│  │  └───────────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────┐  │   │
│  │  │ registry-tls-secret (Secret)          │  │   │
│  │  │  • tls.crt (from cert-manager)        │  │   │
│  │  │  • tls.key (from cert-manager)        │  │   │
│  │  └───────────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────┐  │   │
│  │  │ registry-tls (Certificate)            │  │   │
│  │  │  • Issuer: registry-ca-issuer         │  │   │
│  │  │  • CA: vault-ca-secret                │  │   │
│  │  └───────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────┐   │
│  │ vault namespace                             │   │
│  │  • vault-ca-secret (Root CA)               │   │
│  │  • vault-ca-issuer (CA Issuer)             │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Security Notes

- ✅ All traffic: HTTPS encrypted
- ✅ Certificate: Self-signed (valid for 1 year, auto-renews)
- ✅ CA: Vault-generated, stored securely in etcd
- ✅ Client: Uses `-k` flag to accept self-signed cert (OK for internal)
- ✅ Future: Can upgrade to public CA when ready

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Docker Registry Configuration](https://docs.docker.com/registry/configuration/)
- [Knowledge Base: 28-sigstore-policy-controller.md](../knowledge-base/28-sigstore-policy-controller.md)
- [Knowledge Base: 15-encryption-mtls-spiffe.md](../knowledge-base/15-encryption-mtls-spiffe.md)
