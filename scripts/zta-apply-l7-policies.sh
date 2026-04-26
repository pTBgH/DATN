#!/usr/bin/env bash
# scripts/zta-apply-l7-policies.sh
#
# ZTA Step 2.3.4 (PR #10) — Apply 5 L7 CNP for sensitive endpoints
# (Vault API, Keycloak OIDC, Kong admin, Prometheus scrape).
#
# Usage:
#   bash scripts/zta-apply-l7-policies.sh           # dry-run
#   bash scripts/zta-apply-l7-policies.sh --apply
#   bash scripts/zta-apply-l7-policies.sh --delete
#
# Reference: doc/20-5w1h-policy-matrix.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L7_DIR="$SCRIPT_DIR/infras/k8s-yaml/cilium-policies"

POLICIES=(
  "30-l7-vault-api.yaml"
  "30-l7-keycloak-oidc.yaml"
  "30-l7-keycloak-jwks.yaml"
  "30-l7-kong-admin.yaml"
  "30-l7-prom-metrics.yaml"
)

MODE="dry-run"
case "${1:-}" in
  --apply)  MODE="apply"  ;;
  --delete) MODE="delete" ;;
  ""|--dry-run) MODE="dry-run" ;;
  *)
    echo "Unknown flag: $1" >&2
    exit 1
    ;;
esac

echo "============================================================"
echo " ZTA Step 2.3.4 — L7 Policy Apply  (mode=$MODE)"
echo " Reference: doc/20-5w1h-policy-matrix.md"
echo "============================================================"

run() {
  if [[ "$MODE" == "dry-run" ]]; then
    echo "DRY-RUN: $*"
  else
    echo "EXEC:    $*"
    "$@"
  fi
}

for p in "${POLICIES[@]}"; do
  path="$L7_DIR/$p"
  if [[ ! -f "$path" ]]; then
    echo "SKIP missing: $path"
    continue
  fi
  case "$MODE" in
    apply|dry-run)
      run kubectl apply -f "$path"
      ;;
    delete)
      run kubectl delete -f "$path" --ignore-not-found
      ;;
  esac
done

if [[ "$MODE" == "apply" ]]; then
  echo
  echo "  -- chờ Cilium reconcile L7 (5s)..."
  sleep 5
  echo
  echo "  -- L7 CNP status:"
  kubectl get cnp -A | grep -E '^NAMESPACE|l7-' | sort -u
fi

echo
echo "Done. Verify L7 enforcement với:"
echo "  bash 09-verify-zta.sh         # Test 4e (L7 coverage)"
echo "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \\"
echo "    hubble observe --type l7 --last 30 -o compact"
