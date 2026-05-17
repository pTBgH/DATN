#!/usr/bin/env bash
# =============================================================================
# zta-deploy-opa.sh — Phase 5.B.2.b (OPA user-authz PDP)
# Stable version with rollout + health-aware smoke test
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

NAMESPACE="${OPA_NAMESPACE:-security}"
RELEASE="${OPA_RELEASE:-opa}"

HELM_REPO_NAME="open-policy-agent"
HELM_REPO_URL="https://open-policy-agent.github.io/kube-mgmt/charts"

HELM_CHART="${HELM_REPO_NAME}/opa-kube-mgmt"
HELM_CHART_VERSION="${OPA_CHART_VERSION:-11.0.7}"

VALUES_FILE="$SCRIPT_DIR/infras/k8s-yaml/opa/values.yaml"
POLICIES_DIR="$SCRIPT_DIR/infras/k8s-yaml/opa/policies"

CM_NAME="opa-policies"

# =============================================================================
# COLORS
# =============================================================================

red()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[32m%s\033[0m\n' "$*" >&2; }
yellow() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
blue()   { printf '\033[34m%s\033[0m\n' "$*" >&2; }

# =============================================================================
# FLAGS
# =============================================================================

UNINSTALL=0
POLICIES_ONLY=0

case "${1:-}" in
  --uninstall)
    UNINSTALL=1
    ;;
  --policies-only)
    POLICIES_ONLY=1
    ;;
  -h|--help)
    sed -n '2,40p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  "")
    ;;
  *)
    red "Unknown flag: $1"
    exit 1
    ;;
esac

# =============================================================================
# PRECHECKS
# =============================================================================

command -v helm >/dev/null 2>&1 || {
  red "helm missing"
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  red "kubectl missing"
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  red "python3 missing"
  exit 1
}

python3 - <<'PY' >/dev/null 2>&1 || {
import yaml
PY
  red "python3 package missing: pyyaml"
  exit 1
}

# =============================================================================
# CONFIGMAP BUILDER
# =============================================================================

apply_policies_configmap() {

  if [ ! -d "$POLICIES_DIR" ]; then
    red "Policies dir not found: $POLICIES_DIR"
    exit 1
  fi

  shopt -s nullglob

  local rego_files=("$POLICIES_DIR"/*.rego)

  if [ ${#rego_files[@]} -eq 0 ]; then
    red "No .rego files found in $POLICIES_DIR"
    exit 1
  fi

  blue "Building ConfigMap $NAMESPACE/$CM_NAME"

  local cm_args=()

  for f in "${rego_files[@]}"; do
    cm_args+=("--from-file=$(basename "$f")=$f")
  done

  kubectl create configmap "$CM_NAME" \
    -n "$NAMESPACE" \
    "${cm_args[@]}" \
    --dry-run=client -o yaml \
  | python3 -c '
import sys, yaml

cm = yaml.safe_load(sys.stdin.read())

if cm is None:
    raise SystemExit("Failed to parse generated ConfigMap YAML")

meta = cm.setdefault("metadata", {})
labels = meta.setdefault("labels", {})

labels["openpolicyagent.org/policy"] = "rego"
labels["zta.job7189/role"] = "pdp-policy"
labels["zta.job7189/team"] = "security"

print(yaml.safe_dump(cm, default_flow_style=False))
'
}

# =============================================================================
# UNINSTALL
# =============================================================================

if [ "$UNINSTALL" -eq 1 ]; then

  yellow "[1/2] Removing Helm release"
  helm uninstall "$RELEASE" -n "$NAMESPACE" || true

  yellow "[2/2] Removing policy ConfigMap"
  kubectl -n "$NAMESPACE" delete configmap "$CM_NAME" \
    --ignore-not-found

  green "✓ OPA removed"
  exit 0
fi

# =============================================================================
# POLICIES ONLY
# =============================================================================

if [ "$POLICIES_ONLY" -eq 1 ]; then

  apply_policies_configmap | kubectl apply -f -

  green "✓ Policies refreshed"
  exit 0
fi

# =============================================================================
# MAIN
# =============================================================================

blue "============================================================"
blue " ZTA Phase 5.B.2 — OPA user-authz PDP"
blue "============================================================"

# =============================================================================
# HELM REPO
# =============================================================================

blue "[1/5] Helm repository"

helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" \
  >/dev/null 2>&1 || true

helm repo update "$HELM_REPO_NAME" \
  >/dev/null 2>&1 || true

# =============================================================================
# CONFIGMAP
# =============================================================================

blue "[2/5] Applying policy ConfigMap"

apply_policies_configmap | kubectl apply -f -

# =============================================================================
# HELM DEPLOY
# =============================================================================

blue "[3/5] Deploying OPA"

helm upgrade --install "$RELEASE" "$HELM_CHART" \
  --version "$HELM_CHART_VERSION" \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait \
  --timeout 300s

# =============================================================================
# ROLLOUT
# =============================================================================

blue "[4/5] Waiting rollout"

kubectl -n "$NAMESPACE" rollout status deployment/"$RELEASE" \
  --timeout=180s

# =============================================================================
# SMOKE TEST
# =============================================================================

blue "[5/5] Smoke test"

TMP_JSON=$(mktemp)

cleanup() {
  rm -f "$TMP_JSON"

  if [ -n "${PF_PID:-}" ]; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

cat > "$TMP_JSON" <<'EOF'
{
  "input": {
    "method": "GET",
    "path": "/api/jobs",
    "jwt": {
      "preferred_username": "admin1",
      "realm_access": {
        "roles": ["admin", "default-roles-job7189"]
      }
    }
  }
}
EOF

kubectl -n "$NAMESPACE" port-forward svc/opa 28181:8181 \
  >/dev/null 2>&1 &

PF_PID=$!

# -----------------------------------------------------------------------------
# Wait until OPA health endpoint responds
# -----------------------------------------------------------------------------

READY=0

for _ in {1..20}; do

  if curl -sf http://127.0.0.1:28181/health >/dev/null 2>&1; then
    READY=1
    break
  fi

  sleep 1
done

if [ "$READY" -ne 1 ]; then
  red "OPA health endpoint not ready"
  exit 1
fi

# -----------------------------------------------------------------------------
# Call policy endpoint
# -----------------------------------------------------------------------------

RAW_RESPONSE=$(
  curl -s -X POST \
    -H 'Content-Type: application/json' \
    --data @"$TMP_JSON" \
    http://127.0.0.1:28181/v1/data/zta/authz/allow
)

if [ -z "$RAW_RESPONSE" ]; then
  red "Smoke test failed: empty response"
  exit 1
fi

RESULT=$(
  printf '%s' "$RAW_RESPONSE" \
  | python3 -c '
import sys, json

try:
    data = json.load(sys.stdin)
    print(data.get("result"))
except Exception:
    print("PARSE_ERROR")
'
)

blue "OPA response: $RAW_RESPONSE"

if [[ "$RESULT" =~ ^([Tt]rue|1)$ ]]; then
  green "✓ Smoke test PASS — allow=true"
else
  yellow "⚠ Smoke test FAILED — result=$RESULT"
fi

green "============================================================"
green "✓ OPA READY ($HELM_CHART_VERSION)"
green "============================================================"
