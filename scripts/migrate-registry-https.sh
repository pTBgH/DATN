#!/usr/bin/env bash
set -euo pipefail

# Script: Chuyển zta-registry từ HTTP (port 5000) sang HTTPS (port 5443)
# Chạy trên máy baosrc với sudo

CERT_SRC="/home/ptb/projects/DATN/infras/registry-certs"
REGISTRY_DATA="/var/lib/zta-registry"
CERT_DST="${REGISTRY_DATA}/certs"

echo "=== Phase 1: Copy TLS certs vào registry data dir ==="
sudo mkdir -p "$CERT_DST"
sudo cp "$CERT_SRC/tls.crt" "$CERT_DST/tls.crt"
sudo cp "$CERT_SRC/tls.key" "$CERT_DST/tls.key"
sudo cp "$CERT_SRC/ca.crt" "$CERT_DST/ca.crt"
sudo chmod 644 "$CERT_DST/tls.crt" "$CERT_DST/ca.crt"
sudo chmod 600 "$CERT_DST/tls.key"
echo "✅ Certs copied to $CERT_DST"
ls -la "$CERT_DST"

echo ""
echo "=== Phase 2: Recreate zta-registry container with HTTPS ==="
echo "Stopping old container..."
docker stop zta-registry 2>/dev/null || true
docker rm zta-registry 2>/dev/null || true

echo "Starting new container with TLS on port 5443..."
docker run -d --name zta-registry --restart=always \
  -p 5443:5443 \
  -v "${REGISTRY_DATA}:/var/lib/registry" \
  -v "${CERT_DST}:/certs:ro" \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/tls.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/tls.key \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2

echo "Waiting 3s for registry to start..."
sleep 3

echo ""
echo "=== Phase 3: Trust Vault CA on baosrc system ==="
sudo cp "$CERT_SRC/ca.crt" /usr/local/share/ca-certificates/vault-ca.crt
sudo update-ca-certificates

echo ""
echo "=== Phase 3b: Configure Docker daemon to trust Vault CA ==="
sudo mkdir -p /etc/docker/certs.d/localhost:5443
sudo cp "$CERT_SRC/ca.crt" /etc/docker/certs.d/localhost:5443/ca.crt

# Also set up for Tailscale IP access
BAOSRC_TS_IP="100.74.189.43"
sudo mkdir -p "/etc/docker/certs.d/${BAOSRC_TS_IP}:5443"
sudo cp "$CERT_SRC/ca.crt" "/etc/docker/certs.d/${BAOSRC_TS_IP}:5443/ca.crt"

echo ""
echo "=== Verify: Test HTTPS registry ==="
curl --cacert "$CERT_SRC/ca.crt" -s "https://localhost:5443/v2/_catalog" && echo ""
echo ""
curl --cacert "$CERT_SRC/ca.crt" -s "https://localhost:5443/v2/" && echo ""

echo ""
echo "=== Phase 4: Pull, Push, and Sign core third-party images (Redis) ==="
REDIS_SRC="redis@sha256:d3be87a1060455213a204d2b0a7f04d45d19a16a98e85b3c37b7c33b5f0c489e"
REDIS_DST_BASE="${BAOSRC_TS_IP}:5443/job7189/redis"
KEY_PATH="/home/ptb/projects/DATN/infras/cosign-keys/zta.key"
TEMP_TAG="redis-temp-local"

echo "Pulling $REDIS_SRC from Docker Hub..."
docker pull "$REDIS_SRC"

echo "Tagging image locally..."
docker tag "$REDIS_SRC" "$TEMP_TAG"
docker tag "$TEMP_TAG" "${REDIS_DST_BASE}:latest"

echo "Pushing to local HTTPS registry..."
docker push "${REDIS_DST_BASE}:latest"

# Get the exact digest returned by our registry
PUSHED_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${REDIS_DST_BASE}:latest")
echo "🎯 Real registry image reference: $PUSHED_DIGEST"

if [ -f "$KEY_PATH" ]; then
  echo "Signing Redis image with Cosign..."
  COSIGN_PASSWORD="" cosign sign --key "$KEY_PATH" --tlog-upload=false "$PUSHED_DIGEST"
  echo "✅ Redis signed successfully!"
else
  echo "⚠️  Cosign private key not found at $KEY_PATH."
fi

# Clean up temporary local tag
docker rmi "$TEMP_TAG" || true

echo ""
echo "✅ Registry HTTPS migration and Redis provisioning complete!"
echo ""
echo "Next steps:"
echo "  1. Use scripts/build_and_deploy.sh to build and deploy your services (they will be auto-signed)."
echo "  2. The containerd configuration on cluster nodes is already automated via DaemonSet."
