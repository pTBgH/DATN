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
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"

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
  for f in "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-*.yaml; do
    [[ "$(basename "$f")" == *constraint-template* ]] && continue
    kubectl delete -f "$f" --ignore-not-found 2>&1 | sed 's/^/    /' || true
  done

  yellow "[2/3] Removing constraint templates..."
  for f in "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-template-*.yaml; do
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
    wait_for_dns open-policy-agent.github.io
    helm_repo_update_retry gatekeeper
    helm upgrade gatekeeper gatekeeper/gatekeeper \
      -n "$GK_NS" \
      --version "$GK_VERSION" \
      --reuse-values
  else
    helm repo add gatekeeper "$GK_CHART_REPO" >/dev/null 2>&1 || true
    wait_for_dns open-policy-agent.github.io
    helm_repo_update_retry gatekeeper
    kubectl create ns "$GK_NS" --dry-run=client -o yaml | kubectl apply -f -
    helm install gatekeeper gatekeeper/gatekeeper \
      -n "$GK_NS" \
      --version "$GK_VERSION" \
      --set replicas=1 \
      --set audit.replicas=1 \
      --set controllerManager.resources.limits.memory=384Mi \
      --set controllerManager.resources.requests.memory=192Mi \
      --set controllerManager.resources.limits.cpu=500m \
      --set controllerManager.resources.requests.cpu=100m \
      --set audit.resources.limits.memory=384Mi \
      --set audit.resources.requests.memory=192Mi \
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
blue "[3/4] Applying ConstraintTemplates (sequentially, with CRD wait)..."
# Apply each template ONE at a time and wait for its generated CRD to be
# Established before moving to the next. Gatekeeper's controller-manager
# generates a `<kind>.constraints.gatekeeper.sh` CRD per ConstraintTemplate;
# on a busy cluster (ours: 76+ pods, control-plane under load) the
# controller-manager can be CPU-throttled or restart during a batch apply,
# silently dropping CRD generation for the later templates. Sequential
# apply gives the controller breathing room and surfaces failures cleanly.
declare -A TEMPLATE_TO_CRD=(
  [01-constraint-template-required-zta-labels.yaml]=ztarequiredlabels
  [03-constraint-template-block-host-mounts.yaml]=ztablockhostmounts
  [05-constraint-template-restrict-privileged.yaml]=ztarestrictprivileged
  [07-constraint-template-image-digest-required.yaml]=k8simagedigestrequired
  [09-constraint-template-block-latest-tag.yaml]=k8sblocklatesttag
  [11-constraint-template-signed-image-annotation.yaml]=k8ssignedimageannotation
)
# Iterate in numerically-sorted filename order so we match the on-disk numbering.
for f in $(ls "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-template-*.yaml | sort); do
  base=$(basename "$f")
  crd_kind="${TEMPLATE_TO_CRD[$base]:-}"
  if [ -z "$crd_kind" ]; then
    red "    ✗ unknown template $base — add to TEMPLATE_TO_CRD map"
    exit 1
  fi
  echo "    + $base"
  kubectl apply -f "$f"
  echo "      waiting for crd/${crd_kind}.constraints.gatekeeper.sh to be Established (up to 120s)..."
  if ! kubectl wait --for=condition=Established "crd/${crd_kind}.constraints.gatekeeper.sh" --timeout=120s 2>/dev/null; then
    red "    ✗ CRD ${crd_kind}.constraints.gatekeeper.sh never reached Established"
    red "      Likely cause: ConstraintTemplate Rego compile error, or Gatekeeper controller-manager"
    red "      OOM/CPU-throttled. Inspect:"
    red "        kubectl describe constrainttemplate $crd_kind"
    red "        kubectl -n $GK_NS logs deploy/gatekeeper-controller-manager --tail=80"
    exit 1
  fi
  green "      ✓ ${crd_kind} CRD Established"
done
green "    ✓ all ConstraintTemplate CRDs registered"

blue "[4/4] Applying Constraints..."
for f in "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-*.yaml; do
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
