#!/usr/bin/env bash
# scripts/zta-deploy-gatekeeper.sh
#
# Install OPA Gatekeeper + apply ZTA Constraint Templates and Constraints.
# Idempotent. Skips reinstall if Gatekeeper helm release already healthy.
#
# Usage:
#   bash scripts/zta-deploy-gatekeeper.sh                # install + apply
#   bash scripts/zta-deploy-gatekeeper.sh --uninstall    # remove all
#   bash scripts/zta-deploy-gatekeeper.sh --constraints-only  # skip helm
#
# Prerequisites:
#   - kubectl, helm
#   - PR #9 labels applied (else dry-run violations rất nhiều — đã chấp nhận
#     trên audit-only mode)
#
# After install:
#   kubectl get constrainttemplate
#   kubectl get constraints
#   kubectl get ztarequiredlabels.constraints.gatekeeper.sh \
#     zta-labels-required -o jsonpath='{.status.violations}' | jq
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

GK_NS="gatekeeper-system"
GK_VERSION="${GATEKEEPER_VERSION:-3.16.3}"
GK_CHART_REPO="https://open-policy-agent.github.io/gatekeeper/charts"
CONSTRAINT_DIR="$SCRIPT_DIR/infras/k8s-yaml/opa-gatekeeper"

UNINSTALL=0
CONSTRAINTS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --constraints-only) CONSTRAINTS_ONLY=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Step 2.3.5 — OPA Gatekeeper (PEP Admission)"
blue " Mode: $([ "$UNINSTALL" -eq 1 ] && echo UNINSTALL || ([ "$CONSTRAINTS_ONLY" -eq 1 ] && echo APPLY-CONSTRAINTS || echo INSTALL+APPLY))"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL path
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/3] Removing constraints..."
  for f in "$CONSTRAINT_DIR"/0[2456]-constraint-*.yaml; do
    kubectl delete -f "$f" --ignore-not-found 2>&1 | sed 's/^/    /' || true
  done

  yellow "[2/3] Removing constraint templates..."
  for f in "$CONSTRAINT_DIR"/0[1356]-constraint-template-*.yaml; do
    kubectl delete -f "$f" --ignore-not-found 2>&1 | sed 's/^/    /' || true
  done

  yellow "[3/3] Uninstalling Gatekeeper helm release..."
  if helm list -n "$GK_NS" 2>/dev/null | grep -q gatekeeper; then
    helm uninstall gatekeeper -n "$GK_NS" || true
  fi
  kubectl delete ns "$GK_NS" --ignore-not-found

  green "✓ Gatekeeper + ZTA constraints removed"
  exit 0
fi

# ---------------------------------------------------------------
# INSTALL path
# ---------------------------------------------------------------
if [ "$CONSTRAINTS_ONLY" -ne 1 ]; then
  blue "[1/4] Installing OPA Gatekeeper $GK_VERSION via helm..."
  if helm list -n "$GK_NS" 2>/dev/null | grep -q gatekeeper; then
    yellow "    helm release 'gatekeeper' already present — running upgrade"
    helm repo add gatekeeper "$GK_CHART_REPO" >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    helm upgrade gatekeeper gatekeeper/gatekeeper \
      -n "$GK_NS" \
      --version "$GK_VERSION" \
      --reuse-values
  else
    helm repo add gatekeeper "$GK_CHART_REPO" >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    kubectl create ns "$GK_NS" --dry-run=client -o yaml | kubectl apply -f -
    helm install gatekeeper gatekeeper/gatekeeper \
      -n "$GK_NS" \
      --version "$GK_VERSION" \
      --set replicas=1 \
      --set audit.replicas=1 \
      --set controllerManager.resources.limits.memory=256Mi \
      --set controllerManager.resources.requests.memory=128Mi \
      --set audit.resources.limits.memory=256Mi \
      --set audit.resources.requests.memory=128Mi \
      --set postInstall.labelNamespace.enabled=false \
      --set postUpgrade.labelNamespace.enabled=false
  fi

  blue "[2/4] Waiting for Gatekeeper controller-manager rollout..."
  kubectl -n "$GK_NS" rollout status deploy/gatekeeper-controller-manager --timeout=240s || {
    red "    ✗ controller-manager rollout failed"
    kubectl -n "$GK_NS" get pod
    exit 1
  }
  kubectl -n "$GK_NS" rollout status deploy/gatekeeper-audit --timeout=240s || true
  green "    ✓ Gatekeeper running"
fi

# ---------------------------------------------------------------
# APPLY constraints
# ---------------------------------------------------------------
blue "[3/4] Applying ConstraintTemplates..."
for f in "$CONSTRAINT_DIR"/0[1356]-constraint-template-*.yaml; do
  echo "    + $(basename "$f")"
  kubectl apply -f "$f"
done

# Constraint CRDs lag behind ConstraintTemplate by ~5-10s
echo "    waiting 12s for constraint CRDs to register..."
sleep 12

blue "[4/4] Applying Constraints..."
for f in "$CONSTRAINT_DIR"/0[2456]-constraint-*.yaml; do
  if [[ "$(basename "$f")" == *constraint-template* ]]; then
    continue
  fi
  echo "    + $(basename "$f")"
  kubectl apply -f "$f"
done

# Brief wait for first audit pass
sleep 5

green "============================================================"
green " ✓ Gatekeeper + ZTA constraints applied"
green "============================================================"
echo
echo "Constraints status (audit-only by default):"
kubectl get constrainttemplate 2>&1 | head -10
echo
echo "Active constraints:"
kubectl get ztarequiredlabels,ztablockhostmounts,ztarestrictprivileged 2>&1 | head -20
echo
yellow "Next steps:"
echo "  - Inspect violations:"
echo "      kubectl get ztarequiredlabels.constraints.gatekeeper.sh \\"
echo "        zta-labels-required -o jsonpath='{.status.violations}' | jq"
echo "  - When 0 violations, switch enforcementAction: dryrun → deny in"
echo "    02-constraint-zta-labels.yaml + re-apply."
