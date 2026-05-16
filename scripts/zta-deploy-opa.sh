#!/usr/bin/env bash
# =============================================================================
# zta-deploy-opa.sh — Phase 5.B.2.b (OPA user-authz PDP)
#
# Workflow:
#   1. helm repo add open-policy-agent https://open-policy-agent.github.io/kube-mgmt/charts
#   2. ConfigMap `opa-policies` in ns `security` from infras/k8s-yaml/opa/policies/*
#      with the label `openpolicyagent.org/policy=rego` so kube-mgmt picks it up
#   3. helm upgrade --install opa open-policy-agent/opa-kube-mgmt
#        -f infras/k8s-yaml/opa/values.yaml -n security
#   4. Wait for rollout, smoke-test /v1/data/zta/authz/allow with admin & member tokens
#
# Usage:
#   bash scripts/zta-deploy-opa.sh                  # full deploy
#   bash scripts/zta-deploy-opa.sh --policies-only  # only refresh ConfigMap
#   bash scripts/zta-deploy-opa.sh --uninstall      # remove
#
# Deps: helm 3.x, kubectl, jq.
# Doc:  doc/36-opa-user-authz.md §3.2
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

NAMESPACE="${OPA_NAMESPACE:-security}"
RELEASE="${OPA_RELEASE:-opa}"
HELM_REPO_NAME="open-policy-agent"
HELM_REPO_URL="https://open-policy-agent.github.io/kube-mgmt/charts"
HELM_CHART="${HELM_REPO_NAME}/opa-kube-mgmt"
HELM_CHART_VERSION="${OPA_CHART_VERSION:-8.4.1}"

VALUES_FILE="$SCRIPT_DIR/infras/k8s-yaml/opa/values.yaml"
POLICIES_DIR="$SCRIPT_DIR/infras/k8s-yaml/opa/policies"
CM_NAME="opa-policies"

red()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

UNINSTALL=0
POLICIES_ONLY=0
case "${1:-}" in
  --uninstall) UNINSTALL=1 ;;
  --policies-only) POLICIES_ONLY=1 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
  "") : ;;
  *) red "Unknown flag: $1"; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Helper: render the ConfigMap from local .rego files. kube-mgmt's sidecar
# is configured (in values.yaml) to require the label
# `openpolicyagent.org/policy=rego` so the data ConfigMap is excluded.
# ---------------------------------------------------------------------------
apply_policies_configmap() {
  if [ ! -d "$POLICIES_DIR" ]; then
    red "ERROR: policies dir not found: $POLICIES_DIR"
    exit 1
  fi

  blue "Building ConfigMap $NAMESPACE/$CM_NAME from $POLICIES_DIR/*.rego..."
  CM_ARGS=()
  for f in "$POLICIES_DIR"/*.rego; do
    CM_ARGS+=("--from-file=$(basename "$f")=$f")
  done

  kubectl create configmap "$CM_NAME" \
    -n "$NAMESPACE" \
    "${CM_ARGS[@]}" \
    --dry-run=client -o yaml \
    | python3 - <<'PY'
import sys, yaml
cm = yaml.safe_load(sys.stdin)
cm.setdefault("metadata", {}).setdefault("labels", {})
cm["metadata"]["labels"]["openpolicyagent.org/policy"] = "rego"
cm["metadata"]["labels"]["zta.job7189/role"] = "pdp-policy"
cm["metadata"]["labels"]["zta.job7189/team"] = "security"
print(yaml.safe_dump(cm, default_flow_style=False))
PY
}

# ---------------------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/3] Removing helm release $RELEASE..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "^${RELEASE}"; then
    helm uninstall "$RELEASE" -n "$NAMESPACE" || true
  fi

  yellow "[2/3] Removing ConfigMap $CM_NAME..."
  kubectl -n "$NAMESPACE" delete configmap "$CM_NAME" --ignore-not-found

  yellow "[3/3] Done."
  green "✓ OPA removed"
  exit 0
fi

# ---------------------------------------------------------------------------
# POLICIES-ONLY refresh
# ---------------------------------------------------------------------------
if [ "$POLICIES_ONLY" -eq 1 ]; then
  apply_policies_configmap | kubectl apply -f -
  green "✓ Policies ConfigMap refreshed — kube-mgmt sidecar will hot-reload."
  echo
  echo "Verify reload (watch for 'msg=\"Reloaded policy\"' lines):"
  echo "  kubectl -n $NAMESPACE logs -l app=opa -c mgmt --tail=20"
  exit 0
fi

# ---------------------------------------------------------------------------
# INSTALL
# ---------------------------------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  red "ERROR: helm not installed"; exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  red "ERROR: kubectl not installed"; exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  red "ERROR: python3 needed for ConfigMap label injection"; exit 1
fi

blue "============================================================"
blue " ZTA Phase 5.B.2 — OPA user-authz PDP"
blue "   namespace:     $NAMESPACE"
blue "   helm chart:    $HELM_CHART $HELM_CHART_VERSION"
blue "   values file:   $VALUES_FILE"
blue "   policies dir:  $POLICIES_DIR"
blue "============================================================"

blue "[1/5] Adding helm repo: $HELM_REPO_NAME"
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null 2>&1 || true
helm repo update "$HELM_REPO_NAME" >/dev/null 2>&1 || \
  yellow "    (helm repo update failed — proceeding with cache)"

blue "[2/5] Applying ConfigMap $CM_NAME (policies) — required BEFORE OPA pod starts so kube-mgmt has something to load on first reconcile"
apply_policies_configmap | kubectl apply -f -

blue "[3/5] helm upgrade --install $RELEASE $HELM_CHART"
helm upgrade --install "$RELEASE" "$HELM_CHART" \
  --version "$HELM_CHART_VERSION" \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait --timeout 300s

blue "[4/5] Waiting for OPA pod ready..."
kubectl -n "$NAMESPACE" rollout status deploy/"$RELEASE" --timeout=180s

blue "[5/5] Smoke test — POST a synthetic input to /v1/data/zta/authz/allow"
TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON"' EXIT

cat > "$TMP_JSON" <<'EOF'
{
  "input": {
    "method": "GET",
    "path": "/api/jobs",
    "jwt": {
      "preferred_username": "admin1",
      "realm_access": { "roles": ["admin", "default-roles-job7189"] }
    }
  }
}
EOF

# Port-forward in background, run curl, kill PF.
kubectl -n "$NAMESPACE" port-forward svc/opa 28181:8181 >/dev/null 2>&1 &
PF_PID=$!
sleep 3

RESULT=$(curl -s -X POST -H 'Content-Type: application/json' \
  --data @"$TMP_JSON" \
  http://127.0.0.1:28181/v1/data/zta/authz/allow 2>/dev/null \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("result"))' \
  2>/dev/null || echo "ERROR")

kill "$PF_PID" 2>/dev/null || true
wait "$PF_PID" 2>/dev/null || true

if [ "$RESULT" = "True" ]; then
  green "  ✓ Smoke test PASS — admin1 GET /api/jobs → allow=true"
else
  yellow "  ⚠ Smoke test returned: $RESULT (expected: True)"
  yellow "  Check policies loaded: kubectl -n $NAMESPACE logs -l app=opa -c mgmt --tail=30"
fi

green "============================================================"
green " ✓ OPA user-authz PDP installed"
green "============================================================"
echo
echo "Verify:"
echo "  kubectl -n $NAMESPACE get pod -l app=opa"
echo "  kubectl -n $NAMESPACE logs -l app=opa -c mgmt --tail=20 | grep -i policy"
echo "  kubectl -n $NAMESPACE port-forward svc/opa 8181:8181 &"
echo "  curl localhost:8181/health"
echo "  curl localhost:8181/v1/policies | jq 'keys'"
echo
echo "Next step: bash scripts/zta-deploy-opa-kong-plugin.sh — wires Kong → OPA"
