#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/build_and_deploy_service.sh <service-name> <version>
# Example: ./scripts/build_and_deploy_service.sh hiring-service v2.8.21

SERVICE_NAME="$1"
VERSION="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Normalize names:
# src directories are named like 'hiring_service', 'job_service'
SHORT="${SERVICE_NAME//-/_}"
if [[ "$SHORT" != *_service ]]; then
  SRC_DIR_NAME="${SHORT}_service"
else
  SRC_DIR_NAME="$SHORT"
fi
SRC_DIR="$ROOT/src/$SRC_DIR_NAME/laravel_back"

# values files are named like 'hiring-values.yaml', 'job-values.yaml'
SHORT_NO_SVC="$SHORT"
SHORT_NO_SVC=${SHORT_NO_SVC%_service}
VALUES_FILE="$ROOT/k8s-management/values/${SHORT_NO_SVC}-values.yaml"

IMAGE_BASE="localhost:5000/job7189/$SHORT_NO_SVC"

if [ ! -d "$SRC_DIR" ]; then
  echo "Source directory not found: $SRC_DIR"
  exit 1
fi
if [ ! -f "$VALUES_FILE" ]; then
  echo "Values file not found: $VALUES_FILE"
  exit 1
fi

echo "Building $SERVICE_NAME:$VERSION from $SRC_DIR"
cd "$SRC_DIR"

docker build -t "$IMAGE_BASE:$VERSION" .
docker tag "$IMAGE_BASE:$VERSION" "$IMAGE_BASE:latest"

echo "Pushing images to registry"
docker push "$IMAGE_BASE:$VERSION"
docker push "$IMAGE_BASE:latest"

DIGEST_FULL=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_BASE:$VERSION")
# RepoDigests sometimes returns empty if registry is local - fallback to manifest inspect
if [ -z "$DIGEST_FULL" ] || [[ "$DIGEST_FULL" == "<no value>" ]]; then
  echo "RepoDigest not found via docker inspect, trying skopeo (if available) or fallback"
  DIGEST_FULL="${IMAGE_BASE}@$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_BASE:$VERSION" || echo "")"
fi
if [ -z "$DIGEST_FULL" ]; then
  echo "WARNING: Could not determine image digest. Using tag instead."
  IMAGE_REF="$IMAGE_BASE:$VERSION"
else
  IMAGE_REF="$DIGEST_FULL"
fi

echo "Image reference to use in Helm values: $IMAGE_REF"

# Update values file: set image.fullImage or repository/tag
# Use yq if available, otherwise sed replace fullImage placeholder
if command -v yq >/dev/null 2>&1; then
  echo "Updating values file with yq"
  yq eval ".image.fullImage = \"$IMAGE_REF\"" -i "$VALUES_FILE"
else
  echo "Updating values file by replacing fullImage line"
  # Replace existing fullImage line or add if missing
  if grep -q "fullImage:" "$VALUES_FILE"; then
    sed -i "s|fullImage: .*|fullImage: \"$IMAGE_REF\"|" "$VALUES_FILE"
  else
    # insert under image:
    sed -i "/^image:/a\  fullImage: \"$IMAGE_REF\"" "$VALUES_FILE"
  fi
fi

# Deploy with Helm
RELEASE_NAME="$SERVICE_NAME"
CHART_DIR="$ROOT/k8s-management/charts/laravel-app"
NAMESPACE="job7189-apps"

echo "Deploying $RELEASE_NAME with Helm"
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" -n "$NAMESPACE" -f "$VALUES_FILE"

echo "Waiting for rollout to finish"
kubectl rollout status deployment/$RELEASE_NAME -n "$NAMESPACE" --timeout=300s

# Basic verification: show pod status and check injected creds
POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE_NAME" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' || true)
if [ -n "$POD" ]; then
  echo "Pod is running: $POD"
  echo "Credentials in /var/www/.env:"
  kubectl exec -n "$NAMESPACE" "$POD" -c app -- grep -E "DB_USERNAME|DB_PASSWORD|LEASE_ID" /var/www/.env || true
  # Try a simple PHP DB connection test if DB env present
  USER=$(kubectl exec -n "$NAMESPACE" "$POD" -c app -- sh -c "grep '^DB_USERNAME=' /var/www/.env | cut -d'=' -f2 | tr -d '\"'" || true)
  PASS=$(kubectl exec -n "$NAMESPACE" "$POD" -c app -- sh -c "grep '^DB_PASSWORD=' /var/www/.env | cut -d'=' -f2 | tr -d '\"'" || true)
  DB_NAME=$(kubectl exec -n "$NAMESPACE" "$POD" -c app -- sh -c "grep '^DB_DATABASE=' /var/www/.env | cut -d'=' -f2 | tr -d '\"'" || echo "")
  if [ -n "$USER" ] && [ -n "$PASS" ]; then
    echo "Testing DB connection from pod"
    kubectl exec -n "$NAMESPACE" "$POD" -c app -- /bin/sh -c "cat > /tmp/test_db.php <<'PHP'
<?php
try {
  \$pdo = new PDO('mysql:host=mysql.data.svc.cluster.local;dbname=' . getenv('DB_DATABASE'), getenv('DB_USERNAME'), getenv('DB_PASSWORD'), [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
  echo 'DB OK';
} catch (Exception \$e) {
  echo 'DB FAILED: ' . \$e->getMessage();
}
PHP
php /tmp/test_db.php"
  fi
else
  echo "No running pod found for $SERVICE_NAME"
fi

echo "DONE"
