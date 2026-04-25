#!/bin/bash
# ==========================================
# Script 11: Provision Grafana Security Dashboards + Prometheus Alert Rules
# ==========================================
# PURPOSE: Deploy pre-built Grafana dashboards and Prometheus alerting rules
#          to complete the PIP → PE feedback loop (Observability → Policy Engine).
# RUN AFTER: Script 07 (Monitoring Exporters)
# THESIS REF: Chapter 3, §3.6 — Security Metrics, Alertmanager pipeline
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "============================================================"
echo "📊 SCRIPT 11: GRAFANA DASHBOARDS + PROMETHEUS ALERTS"
echo "============================================================"
echo ""

# ========================
# Step 1: Prometheus Alert Rules
# ========================
echo "━━━ Step 1: Deploying Prometheus Alert Rules ━━━"

cat <<'ALERTRULES' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alert-rules
  namespace: monitoring
  labels:
    app: prometheus
data:
  zta-alerts.yml: |
    groups:
    - name: zta-security-alerts
      rules:
      # Alert 1: High Cilium policy drop rate (possible network scan)
      - alert: CiliumHighPolicyDropRate
        expr: rate(hubble_flows_processed_total{verdict="DROPPED"}[5m]) > 1.5
        for: 2m
        labels:
          severity: warning
          layer: network
        annotations:
          summary: "High Cilium policy drop rate detected"
          description: "More than 1.5 drops/sec for 2min — possible network reconnaissance"

      # Alert 2: Pod restart storm (possible attack or misconfiguration)
      - alert: PodRestartStorm
        expr: increase(kube_pod_container_status_restarts_total{namespace="job7189-apps"}[10m]) > 5
        for: 1m
        labels:
          severity: critical
          layer: application
        annotations:
          summary: "Pod {{ $labels.pod }} restarting excessively"
          description: "{{ $labels.pod }} has restarted {{ $value }} times in 10min"

      # Alert 3: Vault lease explosion (credential abuse indicator)
      - alert: VaultHighLeaseCount
        expr: vault_core_active_lease_count > 50
        for: 5m
        labels:
          severity: warning
          layer: data
        annotations:
          summary: "Vault active lease count is very high"
          description: "{{ $value }} active leases — possible credential abuse"

      # Alert 4: Node memory pressure
      - alert: NodeMemoryPressure
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.15
        for: 3m
        labels:
          severity: warning
          layer: infrastructure
        annotations:
          summary: "Node {{ $labels.instance }} memory below 15%"

      # Alert 5: Kong high 401/403 rate (brute force indicator)
      - alert: KongHighAuthFailureRate
        expr: rate(kong_http_requests_total{code=~"401|403"}[5m]) > 5
        for: 2m
        labels:
          severity: warning
          layer: gateway
        annotations:
          summary: "High auth failure rate at Kong Gateway"
          description: "{{ $value }} 401/403 responses/sec — possible brute force"
ALERTRULES

echo "   ✅ Prometheus alert rules deployed"

# Check if Prometheus config already includes the rules file
PROM_CONFIG=$(kubectl get configmap prometheus-config -n monitoring -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null || echo "")
if echo "$PROM_CONFIG" | grep -q "zta-alerts.yml"; then
  echo "   ℹ️  Alert rules already referenced in prometheus.yml"
else
  echo "   ⚠️  NOTE: You may need to add 'rule_files: [/etc/prometheus/rules/*.yml]'"
  echo "          and mount prometheus-alert-rules ConfigMap to Prometheus pod."
fi
echo ""

# ========================
# Step 2: Grafana ZTA Security Dashboard
# ========================
echo "━━━ Step 2: Deploying Grafana Security Dashboard ━━━"

cat <<'DASHBOARD' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-zta-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "true"
data:
  zta-security-overview.json: |
    {
      "dashboard": {
        "title": "ZTA Security Overview — job7189",
        "uid": "zta-security-001",
        "timezone": "browser",
        "refresh": "30s",
        "panels": [
          {
            "id": 1,
            "title": "Cilium Policy Drops (PIP: Hubble)",
            "type": "timeseries",
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
            "targets": [
              {
                "expr": "rate(hubble_flows_processed_total{verdict=\"DROPPED\"}[5m])",
                "legendFormat": "{{namespace}} drops/sec"
              }
            ]
          },
          {
            "id": 2,
            "title": "Cilium Forwarded Flows (PIP: Hubble)",
            "type": "timeseries",
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
            "targets": [
              {
                "expr": "rate(hubble_flows_processed_total{verdict=\"FORWARDED\"}[5m])",
                "legendFormat": "{{namespace}} fwd/sec"
              }
            ]
          },
          {
            "id": 3,
            "title": "Pod Restarts — job7189-apps (PIP: kube-state-metrics)",
            "type": "stat",
            "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8},
            "targets": [
              {
                "expr": "sum(increase(kube_pod_container_status_restarts_total{namespace=\"job7189-apps\"}[1h]))",
                "legendFormat": "restarts/hour"
              }
            ]
          },
          {
            "id": 4,
            "title": "Running Pods by Namespace (PIP: kube-state-metrics)",
            "type": "bargauge",
            "gridPos": {"h": 8, "w": 6, "x": 6, "y": 8},
            "targets": [
              {
                "expr": "count by (namespace) (kube_pod_status_phase{phase=\"Running\"})",
                "legendFormat": "{{namespace}}"
              }
            ]
          },
          {
            "id": 5,
            "title": "Node Memory Usage % (PIP: node-exporter)",
            "type": "gauge",
            "gridPos": {"h": 4, "w": 6, "x": 12, "y": 8},
            "targets": [
              {
                "expr": "100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100)",
                "legendFormat": "{{instance}}"
              }
            ]
          },
          {
            "id": 6,
            "title": "Node CPU Usage % (PIP: node-exporter)",
            "type": "gauge",
            "gridPos": {"h": 4, "w": 6, "x": 18, "y": 8},
            "targets": [
              {
                "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                "legendFormat": "{{instance}}"
              }
            ]
          }
        ],
        "templating": {"list": []},
        "annotations": {"list": []},
        "schemaVersion": 39,
        "version": 1
      },
      "overwrite": true
    }
DASHBOARD

echo "   ✅ Grafana ZTA dashboard ConfigMap deployed"

# Try to auto-import via Grafana API if running
GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$GRAFANA_POD" ]; then
  echo "   Importing dashboard via Grafana API..."
  DASHBOARD_JSON=$(kubectl get configmap grafana-zta-dashboard -n monitoring -o jsonpath='{.data.zta-security-overview\.json}' 2>/dev/null)
  if [ -n "$DASHBOARD_JSON" ]; then
    kubectl exec -n monitoring "$GRAFANA_POD" -- sh -c "
      curl -s -X POST http://localhost:3000/api/dashboards/db \
        -H 'Content-Type: application/json' \
        -u admin:admin \
        -d '${DASHBOARD_JSON}' 2>/dev/null
    " >/dev/null 2>&1 && echo "   ✅ Dashboard imported to Grafana" || echo "   ⚠️  Auto-import failed — import manually via Grafana UI"
  fi
fi
echo ""

# ========================
# Step 3: PIP Health Verification
# ========================
echo "━━━ Step 3: PIP Tools Health Check ━━━"

PIP_PASS=0
PIP_FAIL=0

check_pip() {
  local name=$1
  local ns=$2
  local kind=$3
  local target=$4

  local ready=""
  case "$kind" in
    deploy)
      ready=$(kubectl get deploy "$target" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      ;;
    sts)
      ready=$(kubectl get statefulset "$target" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      ;;
    ds)
      ready=$(kubectl get daemonset "$target" -n "$ns" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
      ;;
  esac

  if [ "${ready:-0}" -gt 0 ]; then
    echo "   ✅ PIP: $name ($ns/$target) — ${ready} ready"
    PIP_PASS=$((PIP_PASS + 1))
  else
    echo "   ❌ PIP: $name ($ns/$target) — NOT READY"
    PIP_FAIL=$((PIP_FAIL + 1))
  fi
}

echo ""
echo "   --- Identity PIPs ---"
check_pip "Keycloak (User Identity)" "security" "deploy" "keycloak"
check_pip "Vault (Secret Manager)" "vault" "sts" "vault"

echo ""
echo "   --- Network PIPs ---"
check_pip "Cilium Agent (SPIFFE/eBPF)" "kube-system" "ds" "cilium"
check_pip "Hubble Relay (Flow Data)" "kube-system" "deploy" "hubble-relay"

echo ""
echo "   --- Observability PIPs ---"
check_pip "Elasticsearch (Log Store)" "monitoring" "sts" "es"
check_pip "Filebeat (Log Collector)" "monitoring" "ds" "filebeat"
check_pip "Prometheus (Metrics)" "monitoring" "deploy" "prometheus"
check_pip "Grafana (Visualization)" "monitoring" "deploy" "grafana"
check_pip "node-exporter (Node Metrics)" "monitoring" "ds" "node-exporter"
check_pip "kube-state-metrics (K8s State)" "monitoring" "deploy" "kube-state-metrics"

echo ""
echo "   --- PEP PIPs ---"
check_pip "Kong Gateway (N-S PEP)" "gateway" "deploy" "kong-gateway"

# Optional: Tetragon
if kubectl get ds tetragon -n kube-system >/dev/null 2>&1; then
  check_pip "Tetragon (Runtime PEP)" "kube-system" "ds" "tetragon"
else
  echo "   ⚠️  PIP: Tetragon (Runtime PEP) — NOT DEPLOYED (run script 10)"
fi

PIP_TOTAL=$((PIP_PASS + PIP_FAIL))
echo ""
echo "============================================================"
echo "📊 PIP HEALTH SUMMARY"
echo "============================================================"
echo ""
echo "   ✅ Healthy: $PIP_PASS / $PIP_TOTAL PIP tools"
echo "   ❌ Failed:  $PIP_FAIL"
echo ""

if [ "$PIP_FAIL" -eq 0 ]; then
  echo "   🎉 ALL PIP TOOLS OPERATIONAL"
else
  echo "   ⚠️  $PIP_FAIL PIP tool(s) need attention"
fi

echo ""
echo "   📋 Dashboard: Access Grafana → 'ZTA Security Overview'"
echo "   📋 Alerts:    Check Prometheus → Status → Rules"
echo "   📋 Full PIP docs: doc/16-pip-data-sources.md"
echo ""
