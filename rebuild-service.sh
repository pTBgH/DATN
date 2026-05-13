#!/bin/bash
# rebuild-service.sh — build + push + redeploy one Laravel service.
#
# Dual-mode:
#   --vm (default)  Push the built image to the in-cluster registry. The
#                   real nodes pull it from there; no kind-specific load.
#                   Override the push target with VM_REGISTRY_HOST=<host:port>
#                   (defaults to 7189srv05.<tailnet>.ts.net:30005 — read from
#                   k8s-management/values/<service>-values.yaml when present).
#   --kind          Push to localhost:5000 AND `kind load docker-image` so the
#                   Kind node containerd can satisfy pulls without HTTPS.
set -euo pipefail

SCRIPT_DIR_RS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils/zta-cluster-mode.sh
source "$SCRIPT_DIR_RS/scripts/utils/zta-cluster-mode.sh"

# Parse --kind / --vm; preserve remaining args ($1 = service name, $2 = tag).
zta_parse_mode_flag "$@"
eval "$(zta_apply_parsed_args_cmd)"
zta_mode_banner "rebuild-service.sh"

# ========================
# 1. CẤU HÌNH CƠ BẢN
# ========================
REGISTRY_HOST="localhost:5000"
CHART_REGISTRY="docker-registry.registry.svc.cluster.local:5000"
NAMESPACE="job7189-apps"
VALUES_DIR="k8s-management/values"
HELMFILE_PATH="k8s-management/helmfile.yaml"

# ========================
# 2. XỬ LÝ ĐẦU VÀO
# ========================
if [ "$#" -lt 1 ]; then
    echo "Sử dụng: $0 <ten-service> [version-tag]"
    exit 1
fi

SERVICE_NAME="$1"
TAG="${2:-latest}"

declare -A SERVICE_DIRS=(
  ["identity-service"]="identity_service"
  ["workspace-service"]="workspace_service"
  ["job-service"]="job_service"
  ["hiring-service"]="hiring_service"
  ["candidate-service"]="candidate_service"
  ["communication-service"]="communication_service"
  ["storage-service"]="storage_service"
)

DIR_NAME=${SERVICE_DIRS[$SERVICE_NAME]:-}
if [ -z "$DIR_NAME" ]; then
    echo "Lỗi: Không tìm thấy thư mục cho service '$SERVICE_NAME'."
    exit 1
fi

SERVICE_PATH="src/$DIR_NAME/laravel_back"
DOCKERFILE="$SERVICE_PATH/Dockerfile.production"

# ========================
# 1.5 ENSURE LOCAL REGISTRY IS RUNNING (từ 03-deploy-microservices.sh)
# ========================
echo "Kiểm tra Local Registry..."
if ! docker ps 2>/dev/null | grep -q "local-registry"; then
  echo "Khởi động Local Registry..."
  cd infras/local-registry
  docker-compose up -d 2>/dev/null || true
  cd - > /dev/null
  sleep 1
fi
echo "✓ Local Registry sẵn sàng"
echo ""

# ========================
# 2. BUILD & PUSH IMAGE
# ========================
IMAGE_BASE="job7189/$SERVICE_NAME:$TAG"
IMAGE_HOST="$REGISTRY_HOST/$IMAGE_BASE"

echo "--- [1/5] BUILD IMAGE ---"
if [ ! -f "$DOCKERFILE" ]; then
    echo "Lỗi: Không tìm thấy $DOCKERFILE"
    exit 1
fi

docker build -f "$DOCKERFILE" -t "$IMAGE_HOST" "$SERVICE_PATH"
echo "✓ Build thành công: $IMAGE_HOST"
echo ""

# ========================
# 3. PUSH VÀO LOCAL REGISTRY
# ========================
echo "--- [2/5] PUSH VÀO REGISTRY ---"
docker push "$IMAGE_HOST"
echo "✓ Push thành công"
echo ""

# ========================
# 4. RETAG UNPREFIXED
# ========================
echo "--- [3/5] RETAG UNPREFIXED ---"
docker tag "$IMAGE_HOST" "$IMAGE_BASE"
echo "✓ Retagged: $IMAGE_BASE"
echo ""

# ========================
# 4B. PUBLISH IMAGE TO CLUSTER
# ========================
if is_kind_mode; then
  echo "--- [3B/5] LOAD IMAGE VÀO KIND CLUSTER ---"
  if kind load docker-image "$IMAGE_BASE" --name job7189 2>&1; then
      echo "✓ Image loaded into kind cluster"
  else
      echo "⚠️ kind load failed (image might still work if already downloaded)"
  fi
else
  echo "--- [3B/5] PUSH IMAGE VÀO IN-CLUSTER REGISTRY (VM mode) ---"
  # Resolve the VM registry endpoint. Priority:
  #   1. VM_REGISTRY_HOST env var (explicit override)
  #   2. spec.image.registry from k8s-management/values/<service>-values.yaml
  #   3. error — user must say where to push to
  VM_REGISTRY_HOST="${VM_REGISTRY_HOST:-}"
  if [ -z "$VM_REGISTRY_HOST" ]; then
      BASE_NAME="${SERVICE_NAME%-service}"
      VALUES_PROBE="$VALUES_DIR/${BASE_NAME}-values.yaml"
      if [ -f "$VALUES_PROBE" ]; then
          VM_REGISTRY_HOST=$(grep -m1 -E '^[[:space:]]*registry:[[:space:]]*' "$VALUES_PROBE" \
              | sed -E 's/^[[:space:]]*registry:[[:space:]]*//; s/[[:space:]]+$//; s/^"//; s/"$//' || true)
      fi
  fi
  if [ -z "$VM_REGISTRY_HOST" ]; then
      echo "❌ VM mode: cannot determine push target."
      echo "   Set VM_REGISTRY_HOST=<host:port> (e.g. 7189srv05.<tailnet>.ts.net:30005)"
      echo "   or add an 'image.registry: ...' line to $VALUES_DIR/${SERVICE_NAME%-service}-values.yaml."
      exit 1
  fi
  IMAGE_VM="$VM_REGISTRY_HOST/$IMAGE_BASE"
  echo "   Tag → $IMAGE_VM"
  docker tag "$IMAGE_HOST" "$IMAGE_VM"
  echo "   Push → $IMAGE_VM"
  docker push "$IMAGE_VM"
  echo "✓ Image pushed to $VM_REGISTRY_HOST"
fi
echo ""

# ========================
# 5. CẬP NHẬT TAG & DEPLOY K8S
# ========================
BASE_NAME="${SERVICE_NAME%-service}"
VALUES_FILE="$VALUES_DIR/${BASE_NAME}-values.yaml"

echo "--- [4/5] CẬP NHẬT TAG & DEPLOY QUA HELM ---"
if [ -f "$VALUES_FILE" ]; then
    # Thay thế tag value
    sed -i "s|^\([[:space:]]*tag:\).*|\1 \"$TAG\"|g" "$VALUES_FILE"
    echo "✓ Đã cập nhật tag: $TAG"
    
    # Đặt imagePullPolicy là IfNotPresent
    sed -i "s|^\([[:space:]]*pullPolicy:\).*|\1 IfNotPresent|g" "$VALUES_FILE"
    echo "✓ Đã cập nhật pullPolicy: IfNotPresent"
    
    # Đặt registry rỗng (để chart sử dụng unprefixed image names)
    sed -i "s|^\([[:space:]]*registry:\).*|\1 \"\"|g" "$VALUES_FILE"
    echo "✓ Đã set registry rỗng (unprefixed images)"
    
    echo ""
    echo "Đồng bộ hóa Helm deployment..."
    cd k8s-management
    if helmfile apply 2>&1 | grep -E "has changed|created"; then
        echo "✓ Helm đã cập nhật deployment"
    fi
    cd - > /dev/null
else
    echo "⚠️ Không tìm thấy values file: $VALUES_FILE"
fi


# ========================
# 6. KHỞI ĐỘNG LẠI POD
# ========================
echo "--- [5/5] KHỞI ĐỘNG LẠI DEPLOYMENT ---"

# Tìm deployment theo tên service
APP_DEPLOY=$(kubectl get deployment -n "$NAMESPACE" -o name 2>/dev/null | grep "^deployment.apps/${SERVICE_NAME}$" | head -n 1)

if [ -z "$APP_DEPLOY" ]; then
    # Fallback: tìm bằng grep pattern nếu tên exact không match
    APP_DEPLOY=$(kubectl get deployment -n "$NAMESPACE" -o name 2>/dev/null | grep -E "${SERVICE_NAME}[^-]|${SERVICE_NAME}$" | head -n 1)
fi

if [ ! -z "$APP_DEPLOY" ]; then
    echo "♻️ Deployment tìm thấy: $APP_DEPLOY"
    echo "Tiến hành rolling restart..."
    
    if kubectl rollout restart "$APP_DEPLOY" -n "$NAMESPACE"; then
        echo "✓ Restart command sent successfully"
        
        echo ""
        echo "⏳ Chờ pod khởi động (timeout 3 phút)..."
        if kubectl rollout status "$APP_DEPLOY" -n "$NAMESPACE" --timeout=3m 2>&1; then
            echo "✅ Deployment sẵn sàng!"
        else
            echo "⚠️ Pod chưa sẵn sàng trong 3 phút"
        fi
    else
        echo "❌ Restart gặp lỗi"
        exit 1
    fi
else
    echo "❌ LỖI: Không tìm thấy Deployment '$SERVICE_NAME'."
    echo ""
    echo "📋 Deployment hiện có trong namespace $NAMESPACE:"
    kubectl get deployment -n "$NAMESPACE" --no-headers -o custom-columns=NAME:.metadata.name | sort
    echo ""
fi
