#!/usr/bin/env bash
# scripts/zta-apply-tracing-policies.sh
#
# Apply (or delete) all Tetragon TracingPolicies under
# infras/k8s-yaml/tetragon-policies/.
#
# Usage:
#   bash scripts/zta-apply-tracing-policies.sh --apply
#   bash scripts/zta-apply-tracing-policies.sh --delete
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DIR="$SCRIPT_DIR/infras/k8s-yaml/tetragon-policies"

MODE=""
for arg in "$@"; do
  case "$arg" in
    --apply) MODE=apply ;;
    --delete) MODE=delete ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Usage: $0 --apply | --delete" >&2
  exit 1
fi

if ! kubectl get crd tracingpoliciesnamespaced.cilium.io >/dev/null 2>&1; then
  echo "  ⚠  TracingPolicyNamespaced CRD not present — install Tetragon first"
  echo "     Run: bash 10-deploy-tetragon.sh"
  exit 1
fi

for f in "$POLICY_DIR"/*.yaml; do
  [ -f "$f" ] || continue
  case "$MODE" in
    apply)  kubectl apply  -f "$f" ;;
    delete) kubectl delete -f "$f" --ignore-not-found ;;
  esac
done

echo
echo "Tetragon policies in namespaces:"
kubectl get tracingpoliciesnamespaced.cilium.io -A 2>/dev/null
