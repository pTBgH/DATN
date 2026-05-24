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
GRAFANA_PATCHED=0
PROM_RELOADED=0

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
  # No Prometheus Deployment patching happens any more (PR-N) — the rules
  # ConfigMap is mounted statically in 08-prometheus.yaml, so the only
  # rollback step for Prom is removing the rules CM (done below).
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
  echo 'Note: Grafana deployment patch remains (volume points to deleted ConfigMap → harmless).'
  echo '      Prometheus mounts the rules ConfigMap as optional=true, so it keeps running'
  echo '      with zero ZTA rules loaded after this uninstall.'
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
kubectl get deployment grafana -n monitoring -o yaml > "$GRAFANA_SPEC_BACKUP" 2>/dev/null || true

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
# Reload Prometheus to pick up the new rules ConfigMap
# ---------------------------------------------------------------------------
# Prometheus deployment in `infras/k8s-yaml/08-prometheus.yaml` already
# mounts `prometheus-zta-rules` ConfigMap at /etc/prometheus/zta-rules
# (optional volume) and its `prometheus.yml` has `rule_files:
# /etc/prometheus/zta-rules/*.yml`. So once the ConfigMap is applied above,
# we just need Prometheus to re-read its config + rule files. With
# `--web.enable-lifecycle` enabled (default in 08-prometheus.yaml), a
# POST to /-/reload is the lightweight way to trigger that without
# bouncing the pod.
#
# Historical bug (B1, fixed in PR-N): this step used to patch the
# Prometheus Deployment with a non-existent `--rules.path=...` CLI flag
# (Prometheus has no such flag — rules are loaded via `rule_files:` in
# the YAML config). The patch either silently no-op'd or crash-looped
# the pod. Both modes resulted in ZTA rules never being loaded.
blue "[4/4] Restarting Prometheus to load the rules ConfigMap..."
# We restart instead of POST /-/reload because:
#   1. `prom/prometheus` v2.45+ is distroless (no wget/curl in pod) so
#      we can't reload from inside the pod itself.
#   2. The Cilium CNP `allow-prometheus-ingress` (13-monitoring.yaml)
#      only permits ingress on :9090 from grafana / oauth2-proxy /
#      ingress-nginx. An ephemeral busybox pod is rejected before reaching
#      /-/reload, so the in-cluster reload trick doesn't work either.
#   3. Rolling restart takes ~30s, costs nothing in this lab, and
#      guarantees Prometheus picks up the freshly-applied ConfigMap on
#      the kubelet's next volume mount (no stale subPath caching).
#
# Note: a 15-30 s gap in metrics during the rollout is acceptable for
# a PoC. If that is unacceptable in a future production setup, expose
# /-/reload through grafana (already in the allow-prometheus-ingress
# whitelist) or add a dedicated reloader SA to the CNP.
PROM_POD=$(kubectl -n monitoring get pod -l app=prometheus \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$PROM_POD" ]; then
  if kubectl -n monitoring rollout restart deployment/prometheus >/dev/null 2>&1; then
    kubectl -n monitoring rollout status deployment/prometheus --timeout=120s >/dev/null 2>&1 || true
    PROM_RELOADED=1
    green "  ✓ Prometheus restarted (rules active after fresh boot)"
  else
    yellow "  (rollout restart failed — restart the Prometheus pod manually)"
  fi
else
  yellow "  (Prometheus pod not running — rules will load when pod starts)"
fi

# Re-fetch the new pod name after restart (used by the verification step
# below to call /api/v1/rules from grafana — see comment block above for
# why we don't probe directly from a busybox pod).
PROM_POD=$(kubectl -n monitoring get pod -l app=prometheus \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

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

# After PR-N, the rules ConfigMap is mounted statically in 08-prometheus.yaml,
# so the deploy script never modifies the Prometheus Deployment. Instead we
# probe the rules API to confirm Prometheus actually loaded the rules.
if [ "$PROM_CM_APPLIED" -eq 1 ] && [ -n "$PROM_POD" ]; then
  blue "Verifying ZTA rules are loaded in Prometheus..."
  # We can't probe directly from a busybox pod (see Cilium-policy note in
  # step [4/4] above), so we re-use the grafana pod — already in the
  # allow-prometheus-ingress whitelist and based on alpine, which ships
  # wget. Falls back to a non-fatal warning if grafana is not deployed.
  GRAFANA_POD=$(kubectl -n monitoring get pod -l app=grafana \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$GRAFANA_POD" ]; then
    RULES_JSON=$(kubectl -n monitoring exec "$GRAFANA_POD" -- \
      wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/rules \
      2>/dev/null || true)
    ZTA_RULE_GROUPS=$(echo "$RULES_JSON" | grep -oE '"name":"zta-[a-z-]+"' | sort -u | wc -l)
    if [ "${ZTA_RULE_GROUPS:-0}" -ge 1 ]; then
      green "  ✓ Prometheus has ${ZTA_RULE_GROUPS} ZTA rule group(s) loaded"
    else
      yellow "  ✗ Prometheus is up but no ZTA rule groups loaded yet"
      yellow "     (Probe from a host w/ kubectl port-forward:"
      yellow "        kubectl -n monitoring port-forward svc/prometheus 9090:9090 &"
      yellow "        curl -s localhost:9090/api/v1/rules | jq '.data.groups[].name')"
      deploy_ok=0
    fi
  else
    yellow "  (grafana pod not found — skipping in-cluster verification"
    yellow "   Use: kubectl -n monitoring port-forward svc/prometheus 9090:9090)"
  fi
fi

if [ "$deploy_ok" -eq 0 ]; then
  red "One or more deployments failed to roll out"
  rollback
  exit 1
fi

# Cleanup backup files on success
rm -f "$GRAFANA_SPEC_BACKUP" 2>/dev/null || true

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
