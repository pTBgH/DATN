#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="$1"
VERSION="$2"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REGISTRY="100.74.189.43:5443"

SHORT="${SERVICE_NAME//-/_}"

if [[ "$SHORT" != *_service ]]; then
  SRC_DIR_NAME="${SHORT}_service"
else
  SRC_DIR_NAME="$SHORT"
fi

SRC_DIR="$ROOT/src/$SRC_DIR_NAME/laravel_back"

SHORT_NO_SVC="${SHORT%_service}"

VALUES_FILE="$ROOT/k8s-management/values/${SHORT_NO_SVC}-values.yaml"

IMAGE_BASE="$REGISTRY/job7189/$SHORT_NO_SVC"

# -----------------------------
# VALIDATION
# -----------------------------
if [ ! -d "$SRC_DIR" ]; then
  echo "❌ Source directory not found: $SRC_DIR"
  exit 1
fi

if [ ! -f "$VALUES_FILE" ]; then
  echo "❌ Values file not found: $VALUES_FILE"
  exit 1
fi

echo "============================"
echo "BUILD: $SERVICE_NAME:$VERSION"
echo "REGISTRY: $REGISTRY"
echo "IMAGE: $IMAGE_BASE"
echo "============================"

cd "$SRC_DIR"

# -----------------------------
# BUILD
# -----------------------------
docker build -t "$IMAGE_BASE:$VERSION" .

# IMPORTANT: ensure tag exists in local repo
docker tag "$IMAGE_BASE:$VERSION" "$IMAGE_BASE:latest"

# -----------------------------
# PUSH
# -----------------------------
docker push "$IMAGE_BASE:$VERSION"
docker push "$IMAGE_BASE:latest"

# -----------------------------
# DIGEST RESOLVE (FIXED)
# -----------------------------
echo "🔎 Resolving digest..."

DIGEST_FULL=""

# METHOD 1: docker inspect (works ONLY if local registry supports RepoDigests)
DIGEST_FULL=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_BASE:$VERSION" 2>/dev/null || true)

# METHOD 2 (RELIABLE): query registry manifest v2 API
if [[ -z "$DIGEST_FULL" || "$DIGEST_FULL" == "<no value>" ]]; then
  DIGEST=$(curl -sI -k \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://$REGISTRY/v2/job7189/$SHORT_NO_SVC/manifests/$VERSION" \
    | grep -i "docker-content-digest" \
    | awk '{print $2}' | tr -d $'\r')

  if [[ -n "$DIGEST" ]]; then
    DIGEST_FULL="$IMAGE_BASE@${DIGEST}"
  fi
fi

# fallback
if [[ -z "$DIGEST_FULL" ]]; then
  echo "⚠️  Could not resolve digest, using tag-based reference"
  DIGEST_FULL="$IMAGE_BASE:$VERSION"
fi

echo "✅ Resolved digest: $DIGEST_FULL"

# -----------------------------
# COSIGN SIGNING
# -----------------------------
if [[ "$DIGEST_FULL" == *@sha256:* ]]; then
  echo "🔐 Signing image with Cosign..."
  COSIGN_PASSWORD="" cosign sign --key "$ROOT/infras/cosign-keys/zta.key" --tlog-upload=false "$DIGEST_FULL"
else
  echo "⚠️ Skipping signature: digest not resolved or tag-based reference used."
fi

# Update VALUES_FILE with new digest
echo "📝 Updating values file: $VALUES_FILE"
sed -i "s|fullImage:.*|fullImage: \"$DIGEST_FULL\"|g" "$VALUES_FILE"

# Deploy using Helm (using generic laravel-app chart)
echo "🚀 Deploying $SERVICE_NAME..."
RELEASE_NAME="${SHORT_NO_SVC}-service"
helm upgrade --install "$RELEASE_NAME" "$ROOT/k8s-management/charts/laravel-app" \
  -f "$ROOT/k8s-management/values/laravel-common-values.yaml" \
  -f "$VALUES_FILE" \
  -n job7189-apps \
  --wait

echo "✅ Deployment complete!"