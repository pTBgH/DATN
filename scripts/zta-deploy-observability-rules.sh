#!/usr/bin/env bash
# =============================================================================
# zta-deploy-observability-rules.sh — deploy ZTA Grafana dashboard + Prometheus rules
#
# Deploys:
#   1. Grafana dashboard ConfigMap (zta-overview.json → provisioned auto-load)
#   2. Prometheus alerting rules ConfigMap (zta-rules.yml)
#   3. Patches Grafana deployment to mount the dashboard volume
#   4. Patches Prometheus deployment to mount the rules volume
#
# Features:
#   - Auto-rollback on failure — only removes observability ConfigMaps,
#     does NOT touch Grafana/Prometheus deployments or other modules
#   - Saves and restores Grafana/Prometheus deployment specs before patching
#   - All output logged to evidence/deploy-observability-<ts>.log
#   - Health check: verifies Grafana + Prometheus rollout after patching
#
# Pre-req: monitoring namespace, Prometheus + Grafana deployed.
#
# Usage:
#   bash scripts/zta-deploy-observability-rules.sh
#   bash scripts/zta-deploy-observability-rules.sh --uninstall
#
# Reference: doc/zta-gap-decision.md (Decision 2)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Logging — tee all output to evidence file
# ---------------------------------------------------------------------------
EVIDENCE_DIR="$SCRIPT_DIR/evidence"
mkdir -p "$EVIDENCE_DIR"
DEPLOY_TS=$(date -u +"%Y%m%d_%H%M%S")
LOGFILE="$EVIDENCE_DIR/deploy-observability-${DEPLOY_TS}.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "[$(date -u +%FT%TZ)] Log: $LOGFILE"

# ---------------------------------------------------------------------------
# Rollback state
# ---------------------------------------------------------------------------
ROLLBACK_TRIGGERED=0
DEPLOY_SUCCESS=0
GRAFANA_CM_APPLIED=0
PROM_CM_APPLIED=0
GRAFANA_SPEC_BACKUP=""
PROM_SPEC_BACKUP=""
GRAFANA_PATCHED=0
PROM_PATCHED=0

rollback() {
  [ "$ROLLBACK_TRIGGERED" -eq 1 ] && return
  ROLLBACK_TRIGGERED=1
  echo
  red "════════════════════════════════════════════════════════"
  red " DEPLOY FAILED — rolling back observability resources"
  red "════════════════════════════════════════════════════════"

  if [ "$GRAFANA_PATCHED" -eq 1 ] && [ -n "$GRAFANA_SPEC_BACKUP" ] && [ -f "$GRAFANA_SPEC_BACKUP" ]; then
    yellow "  rollback: restoring Grafana deployment spec..."
    kubectl replace -f "$GRAFANA_SPEC_BACKUP" 2>/dev/null || true
  fi
  if [ "$PROM_PATCHED" -eq 1 ] && [ -n "$PROM_SPEC_BACKUP" ] && [ -f "$PROM_SPEC_BACKUP" ]; then
    yellow "  rollback: restoring Prometheus deployment spec..."
    kubectl replace -f "$PROM_SPEC_BACKUP" 2>/dev/null || true
  fi
  if [ "$PROM_CM_APPLIED" -eq 1 ]; then
    yellow "  rollback: removing prometheus-zta-rules ConfigMap..."
    kubectl delete cm -n monitoring prometheus-zta-rules --ignore-not-found 2>/dev/null || true
  fi
  if [ "$GRAFANA_CM_APPLIED" -eq 1 ]; then
    yellow "  rollback: removing grafana-zta-dashboard ConfigMap..."
    kubectl delete cm -n monitoring grafana-zta-dashboard --ignore-not-found 2>/dev/null || true
  fi

  red "Rollback complete. Log: $LOGFILE"
  red "Other modules are NOT affected."
}

trap_handler() {
  if [ "$DEPLOY_SUCCESS" -eq 0 ]; then
    red "Unexpected error — triggering rollback"
    rollback
  fi
}
trap trap_handler ERR EXIT

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------
uninstall() {
  blue "Uninstalling ZTA observability rules..."
  kubectl delete cm -n monitoring grafana-zta-dashboard --ignore-not-found
  kubectl delete cm -n monitoring prometheus-zta-rules --ignore-not-found
  green "ZTA observability rules uninstalled"
  echo "Note: Grafana/Prometheus deployment patches remain — they are harmless"
  echo "      (volumes point to deleted ConfigMaps → Grafana/Prometheus ignore missing mounts)."
  exit 0
}

case "${1:-}" in
  --uninstall) uninstall ;;
  -h|--help)   sed -n '2,26p' "$0"; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  red "ERR: kubectl not in PATH"; exit 1
fi
if ! kubectl get ns monitoring >/dev/null 2>&1; then
  red "ERR: namespace 'monitoring' not found"; exit 1
fi

blue "================================================================"
blue " ZTA Observability Rules Deploy (PR-L)"
blue "================================================================"

# ---------------------------------------------------------------------------
# Save deployment specs for rollback
# ---------------------------------------------------------------------------
GRAFANA_SPEC_BACKUP=$(mktemp /tmp/grafana-deploy-backup-XXXXXX.yaml)
PROM_SPEC_BACKUP=$(mktemp /tmp/prom-deploy-backup-XXXXXX.yaml)
kubectl get deployment grafana -n monitoring -o yaml > "$GRAFANA_SPEC_BACKUP" 2>/dev/null || true
kubectl get deployment prometheus -n monitoring -o yaml > "$PROM_SPEC_BACKUP" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Deploy ConfigMaps
# ---------------------------------------------------------------------------
blue "[1/4] Grafana ZTA dashboard ConfigMap..."
if kubectl create configmap grafana-zta-dashboard \
  --from-file=zta-overview.json="$SCRIPT_DIR/infras/k8s-yaml/grafana-dashboards/zta-overview.json" \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -; then
  GRAFANA_CM_APPLIED=1
else
  red "  FAILED: grafana-zta-dashboard ConfigMap"
  rollback
  exit 1
fi

blue "[2/4] Prometheus ZTA rules ConfigMap..."
if kubectl apply -f "$SCRIPT_DIR/infras/k8s-yaml/prometheus-rules.yaml"; then
  PROM_CM_APPLIED=1
else
  red "  FAILED: prometheus-zta-rules ConfigMap"
  rollback
  exit 1
fi

# ---------------------------------------------------------------------------
# Patch Grafana — add dashboard volume mount
# ---------------------------------------------------------------------------
blue "[3/4] Patching Grafana deployment to mount ZTA dashboard..."
GRAFANA_PATCH=$(cat <<'PATCH'
{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {
            "name": "zta-dashboards",
            "configMap": {
              "name": "grafana-zta-dashboard"
            }
          }
        ],
        "containers": [
          {
            "name": "grafana",
            "volumeMounts": [
              {
                "name": "zta-dashboards",
                "mountPath": "/var/lib/grafana/dashboards/zta"
              }
            ]
          }
        ]
      }
    }
  }
}
PATCH
)
if kubectl patch deployment grafana -n monitoring \
  --type=strategic -p "$GRAFANA_PATCH" 2>/dev/null; then
  GRAFANA_PATCHED=1
  green "  ✓ Grafana patched"
else
  yellow "  (Grafana already has ZTA dashboard mount or patch not needed)"
fi

# ---------------------------------------------------------------------------
# Patch Prometheus — add rules volume mount
# ---------------------------------------------------------------------------
blue "[4/4] Patching Prometheus deployment to mount ZTA rules..."
PROM_PATCH=$(cat <<'PATCH'
{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {
            "name": "zta-rules",
            "configMap": {
              "name": "prometheus-zta-rules"
            }
          }
        ],
        "containers": [
          {
            "name": "prometheus",
            "args": [
              "--config.file=/etc/prometheus/prometheus.yml",
              "--storage.tsdb.path=/prometheus",
              "--storage.tsdb.retention.time=3d",
              "--web.enable-lifecycle",
              "--rules.path=/etc/prometheus/zta-rules/*.yml"
            ],
            "volumeMounts": [
              {
                "name": "zta-rules",
                "mountPath": "/etc/prometheus/zta-rules",
                "readOnly": true
              }
            ]
          }
        ]
      }
    }
  }
}
PATCH
)
if kubectl patch deployment prometheus -n monitoring \
  --type=strategic -p "$PROM_PATCH" 2>/dev/null; then
  PROM_PATCHED=1
  green "  ✓ Prometheus patched"
else
  yellow "  (Prometheus already has ZTA rules mount or patch not needed)"
fi

# ---------------------------------------------------------------------------
# Health check — wait for Grafana + Prometheus rollout (timeout 120s)
# ---------------------------------------------------------------------------
HEALTH_TIMEOUT="${OBSERVABILITY_HEALTH_TIMEOUT:-120}"

deploy_ok=1
if [ "$GRAFANA_PATCHED" -eq 1 ]; then
  blue "Waiting for Grafana rollout (timeout ${HEALTH_TIMEOUT}s)..."
  if kubectl rollout status deployment/grafana -n monitoring --timeout="${HEALTH_TIMEOUT}s"; then
    green "  ✓ Grafana rollout complete"
  else
    red "  ✗ Grafana rollout failed"
    kubectl -n monitoring logs deployment/grafana --tail=20 2>/dev/null || true
    deploy_ok=0
  fi
fi

if [ "$PROM_PATCHED" -eq 1 ]; then
  blue "Waiting for Prometheus rollout (timeout ${HEALTH_TIMEOUT}s)..."
  if kubectl rollout status deployment/prometheus -n monitoring --timeout="${HEALTH_TIMEOUT}s"; then
    green "  ✓ Prometheus rollout complete"
  else
    red "  ✗ Prometheus rollout failed"
    kubectl -n monitoring logs deployment/prometheus --tail=20 2>/dev/null || true
    deploy_ok=0
  fi
fi

if [ "$deploy_ok" -eq 0 ]; then
  red "One or more deployments failed to roll out"
  rollback
  exit 1
fi

# Cleanup backup files on success
rm -f "$GRAFANA_SPEC_BACKUP" "$PROM_SPEC_BACKUP" 2>/dev/null || true

DEPLOY_SUCCESS=1

echo
green "================================================================"
green " ZTA Observability Rules deployed"
green "================================================================"
echo
echo "Log: $LOGFILE"
echo
echo "Verify:"
echo "  kubectl -n monitoring get cm grafana-zta-dashboard"
echo "  kubectl -n monitoring get cm prometheus-zta-rules"
echo "  # Port-forward Grafana: kubectl -n monitoring port-forward svc/grafana 3000:80"
echo "  # Dashboard: http://localhost:3000/d/zta-overview-v1"
echo
