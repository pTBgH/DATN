#!/bin/bash
set -e

CLUSTER_NAME=job7189   # đổi nếu bạn đặt tên khác

echo "🐳 Using local Docker (Kind)..."

build_service () {
  NAME=$1
  SERVICE_PATH=$2
  VERSION=1.0.0

  DOCKERFILE_PATH="$SERVICE_PATH/laravel_back/Dockerfile.production"
  CONTEXT_PATH="$SERVICE_PATH/laravel_back"

  if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ Dockerfile not found: $DOCKERFILE_PATH"
    return
  fi

  echo "🐳 Building $NAME..."
  docker build -t job7189/$NAME:$VERSION \
    -f "$DOCKERFILE_PATH" \
    "$CONTEXT_PATH"

  echo "📦 Loading image into Kind..."
  kind load docker-image job7189/$NAME:$VERSION --name $CLUSTER_NAME
}

# Build tất cả service
build_service candidate-service      src/candidate_service
build_service communication-service  src/communication_service
build_service hiring-service         src/hiring_service
build_service identity-service       src/identity_service
build_service job-service            src/job_service
build_service storage-service        src/storage_service
build_service workspace-service      src/workspace_service

echo "------------------------------------------------"
echo "🔄 Restarting Deployments..."

kubectl rollout restart deployment candidate-service -n job7189-app
kubectl rollout restart deployment communication-service -n job7189-app
kubectl rollout restart deployment hiring-service -n job7189-app
kubectl rollout restart deployment identity-service -n job7189-app
kubectl rollout restart deployment job-service -n job7189-app
kubectl rollout restart deployment storage-service -n job7189-app
kubectl rollout restart deployment workspace-service -n job7189-app

echo "✅ DONE! All services rebuilt and restarted with Kind!"



