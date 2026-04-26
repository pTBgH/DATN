#!/usr/bin/env bash
# =============================================================================
# apply-zta-namespace-policies.sh — Step 2.3.2 microperimeter applier
# Reference: doc/18-daas-classification.md
#
# Mặc định: DRY-RUN. User phải explicit `--apply` mới apply thật.
#
# Usage:
#   bash apply-zta-namespace-policies.sh --namespace=registry            (dry-run)
#   bash apply-zta-namespace-policies.sh --namespace=registry --apply
#   bash apply-zta-namespace-policies.sh --namespace=registry --rollback
#   bash apply-zta-namespace-policies.sh --all --apply
#   bash apply-zta-namespace-policies.sh --all --rollback
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Order = ít rủi ro → rủi ro cao (xem README.md)
ORDER=(
  "registry:16-registry.yaml"
  "management:15-management.yaml"
  "monitoring:13-monitoring.yaml"
  "gateway:14-gateway.yaml"
  "security:12-security.yaml"
  "vault:11-vault.yaml"
  "data:10-data.yaml"
)

MODE="dry-run"
TARGET_NS=""
ALL=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace=*) TARGET_NS="${1#*=}"; shift;;
    --all)         ALL=1; shift;;
    --apply)       MODE="apply"; shift;;
    --rollback)    MODE="rollback"; shift;;
    --dry-run)     MODE="dry-run"; shift;;
    -h|--help)
      grep '^#' "$0" | head -20; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "$TARGET_NS" && $ALL -eq 0 ]]; then
  echo "ERR: cần --namespace=<name> hoặc --all" >&2
  exit 1
fi

apply_one() {
  local ns="$1" file="$2"
  local path="$SCRIPT_DIR/$file"
  if [[ ! -f "$path" ]]; then
    echo "  SKIP (file not found): $path"; return
  fi
  # Skip nếu namespace chưa được tạo trên cluster (graceful)
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "  SKIP (namespace '$ns' không tồn tại trên cluster)."
    echo "       Nếu cần dùng, deploy nguồn ns trước (vd: 'kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml' cho ns=registry)."
    return 0
  fi
  case "$MODE" in
    dry-run)
      echo "==> [DRY-RUN] kubectl apply --dry-run=server -f $file (ns=$ns)"
      kubectl apply --dry-run=server -f "$path" || {
        echo "  WARN: dry-run failed for $file"; return 1; }
      ;;
    apply)
      echo "==> [APPLY]   kubectl apply -f $file (ns=$ns)"
      kubectl apply -f "$path"
      echo "  -- chờ Cilium reconcile policy ..."
      sleep 3
      echo "  -- danh sách CNP hiện tại trong ns=$ns:"
      kubectl get cnp -n "$ns" 2>/dev/null || true
      ;;
    rollback)
      echo "==> [ROLLBACK] kubectl delete -f $file (ns=$ns) --ignore-not-found"
      kubectl delete -f "$path" --ignore-not-found
      ;;
  esac
}

verify_pods() {
  local ns="$1"
  echo
  echo "  -- pod status sau khi $MODE namespace $ns:"
  kubectl get pods -n "$ns" --no-headers 2>/dev/null \
    | awk '{print "     "$0}' || true
  local crash
  crash=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null \
    | awk '$3 ~ /CrashLoop|Error/ {c++} END{print c+0}')
  if [[ "$crash" -gt 0 ]]; then
    echo "  WARN: $crash pod đang crash trong ns=$ns. Cân nhắc rollback."
  fi
}

run_target() {
  local ns="$1" file="$2"
  echo "===================================================================="
  echo "  Namespace: $ns   |   Mode: $MODE   |   File: $file"
  echo "===================================================================="
  apply_one "$ns" "$file" || true
  if [[ "$MODE" != "dry-run" ]]; then
    verify_pods "$ns"
  fi
  echo
}

if [[ $ALL -eq 1 ]]; then
  for entry in "${ORDER[@]}"; do
    ns="${entry%%:*}"; file="${entry##*:}"
    run_target "$ns" "$file"
  done
else
  for entry in "${ORDER[@]}"; do
    ns="${entry%%:*}"; file="${entry##*:}"
    if [[ "$ns" == "$TARGET_NS" ]]; then
      run_target "$ns" "$file"
      exit 0
    fi
  done
  echo "ERR: namespace '$TARGET_NS' không nằm trong danh sách hỗ trợ:" >&2
  for entry in "${ORDER[@]}"; do echo "  - ${entry%%:*}" >&2; done
  exit 1
fi
