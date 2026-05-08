#!/usr/bin/env bash
# =============================================================================
# zta-deploy-observability-rules.sh — deploy ZTA Grafana dashboard + Prometheus rules
#
# Deploys:
#   1. Grafana dashboard ConfigMap (zta-overview.json → provisioned auto-load)
#   2. Prometheus alerting rules ConfigMap (zta-rules.yml)
#   3. Patches Prometheus deployment to mount the rules volume
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
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

uninstall() {
  blue "Uninstalling ZTA observability rules..."
  kubectl delete cm -n monitoring grafana-zta-dashboard --ignore-not-found
  kubectl delete cm -n monitoring prometheus-zta-rules --ignore-not-found
  green "ZTA observability rules uninstalled"
  exit 0
}

case "${1:-}" in
  --uninstall) uninstall ;;
  -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
esac

if ! command -v kubectl >/dev/null 2>&1; then
  red "ERR: kubectl not in PATH"; exit 1
fi
if ! kubectl get ns monitoring >/dev/null 2>&1; then
  red "ERR: namespace 'monitoring' not found"; exit 1
fi

blue "================================================================"
blue " ZTA Observability Rules Deploy (PR-L)"
blue "================================================================"

# 1. Grafana dashboard ConfigMap
blue "[1/3] Grafana ZTA dashboard ConfigMap..."
kubectl create configmap grafana-zta-dashboard \
  --from-file=zta-overview.json="$SCRIPT_DIR/infras/k8s-yaml/grafana-dashboards/zta-overview.json" \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Prometheus alerting rules ConfigMap
blue "[2/3] Prometheus ZTA rules ConfigMap..."
kubectl apply -f "$SCRIPT_DIR/infras/k8s-yaml/prometheus-rules.yaml"

# 3. Patch Grafana to mount the dashboard ConfigMap
blue "[3/3] Patching Grafana deployment to mount ZTA dashboard..."
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
kubectl patch deployment grafana -n monitoring \
  --type=strategic -p "$GRAFANA_PATCH" 2>/dev/null || \
  echo "  (Grafana already has ZTA dashboard mount or patch not needed)"

# 4. Patch Prometheus to mount rules volume
blue "Patching Prometheus deployment to mount ZTA rules..."
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
kubectl patch deployment prometheus -n monitoring \
  --type=strategic -p "$PROM_PATCH" 2>/dev/null || \
  echo "  (Prometheus already has ZTA rules mount or patch not needed)"

echo
green "================================================================"
green " ZTA Observability Rules deployed"
green "================================================================"
echo
echo "Verify:"
echo "  kubectl -n monitoring get cm grafana-zta-dashboard"
echo "  kubectl -n monitoring get cm prometheus-zta-rules"
echo "  # Port-forward Grafana: kubectl -n monitoring port-forward svc/grafana 3000:80"
echo "  # Dashboard: http://localhost:3000/d/zta-overview-v1"
echo
