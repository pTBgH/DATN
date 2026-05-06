#!/usr/bin/env bash
# scripts/zta-teardown.sh
#
# Wipe sạch cluster Kind "job7189" và toàn bộ artefact liên quan.
# An toàn để chạy nhiều lần (idempotent).
#
# Usage:
#   bash scripts/zta-teardown.sh                # full teardown, prompt confirm
#   bash scripts/zta-teardown.sh --yes          # full teardown, no prompt
#   bash scripts/zta-teardown.sh --keep-images  # giữ docker images đã build
#   bash scripts/zta-teardown.sh --keep-volumes # giữ persistent volume host paths
#
# Order:
#   1. kind delete cluster job7189
#   2. (optional) docker rmi <local images>
#   3. (optional) rm -rf /mnt/data /var/lib/job7189-* (persistent host paths)
#   4. evidence/baseline-* dọn nhẹ (giữ folder, xoá file >7 ngày)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

CLUSTER_NAME="${CLUSTER_NAME:-job7189}"
KEEP_IMAGES=0
KEEP_VOLUMES=0
NO_PROMPT=0

for arg in "$@"; do
  case "$arg" in
    --yes|-y) NO_PROMPT=1 ;;
    --keep-images) KEEP_IMAGES=1 ;;
    --keep-volumes) KEEP_VOLUMES=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Teardown — wipe everything for clean rebuild"
blue " Cluster: $CLUSTER_NAME"
blue " Keep images:  $([ "$KEEP_IMAGES" -eq 1 ] && echo YES || echo NO)"
blue " Keep volumes: $([ "$KEEP_VOLUMES" -eq 1 ] && echo YES || echo NO)"
blue "============================================================"

if [ "$NO_PROMPT" -ne 1 ]; then
  read -r -p "  ⚠  This will DELETE the Kind cluster and host data. Continue? (yes/NO) " ans
  if [ "${ans,,}" != "yes" ]; then
    yellow "  Cancelled."
    exit 0
  fi
fi

# 1) Kind cluster
echo
blue "[1/4] Deleting Kind cluster '$CLUSTER_NAME'..."
if command -v kind >/dev/null 2>&1; then
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    kind delete cluster --name "$CLUSTER_NAME"
    green "      ✓ cluster deleted"
  else
    yellow "      cluster '$CLUSTER_NAME' not present"
  fi
else
  red "      kind not installed — skipping cluster delete"
fi

# 2) Local docker images
echo
blue "[2/4] Cleaning local docker images..."
if [ "$KEEP_IMAGES" -eq 1 ]; then
  yellow "      --keep-images set — skipping"
else
  if command -v docker >/dev/null 2>&1; then
    # Pattern khớp images project DATN: identity-service, hiring-service, ...
    # KHÔNG xoá images base hệ thống (kindest/node, cilium, etc.)
    PROJECT_PATTERNS=(
      'job7189' 'datn' 'identity-service' 'hiring-service' 'job-service'
      'candidate-service' 'manager-service' 'mail-service' 'cv-service'
    )
    for pat in "${PROJECT_PATTERNS[@]}"; do
      ids=$(docker images --format '{{.ID}} {{.Repository}}' 2>/dev/null \
        | awk -v p="$pat" '$2 ~ p {print $1}' | sort -u)
      if [ -n "$ids" ]; then
        echo "      removing images matching '$pat'..."
        # shellcheck disable=SC2086
        docker rmi -f $ids 2>/dev/null || true
      fi
    done
    green "      ✓ project images cleaned"
  else
    yellow "      docker not available — skipping"
  fi
fi

# 3) Persistent host data (hostPath mounts của Kafka/MySQL/Vault/Elasticsearch)
echo
blue "[3/4] Cleaning persistent host data..."
if [ "$KEEP_VOLUMES" -eq 1 ]; then
  yellow "      --keep-volumes set — skipping"
else
  HOST_PATHS=(
    "/mnt/data/job7189"
    "/var/lib/job7189-mysql"
    "/var/lib/job7189-vault"
    "/var/lib/job7189-kafka"
    "/var/lib/job7189-elasticsearch"
  )
  for p in "${HOST_PATHS[@]}"; do
    if [ -d "$p" ]; then
      echo "      removing $p ..."
      sudo rm -rf "$p" 2>/dev/null || rm -rf "$p" 2>/dev/null || true
    fi
  done
  green "      ✓ host data cleaned"
fi

# 4) Evidence cleanup (giữ baseline-* folders, dọn file > 7 ngày)
echo
blue "[4/4] Light evidence/ cleanup..."
if [ -d "$SCRIPT_DIR/evidence" ]; then
  find "$SCRIPT_DIR/evidence" -type f -mtime +7 -delete 2>/dev/null || true
  green "      ✓ files older than 7d removed (folders kept)"
else
  yellow "      no evidence/ folder"
fi

echo
green "============================================================"
green " ✅  Teardown complete."
green "    Next: bash scripts/zta-rebuild.sh"
green "============================================================"
