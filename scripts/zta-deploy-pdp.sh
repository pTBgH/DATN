#!/usr/bin/env bash
# =============================================================================
# zta-deploy-pdp.sh — deploy PDP Controller (Step 2.3.6 Adaptive Loop)
#
# Pre-req: cluster running, security namespace exists, Cilium installed.
#
# Usage:
#   bash scripts/zta-deploy-pdp.sh                    # full deploy
#   bash scripts/zta-deploy-pdp.sh --regen-cm-only    # rebuild ConfigMap from .py
#   bash scripts/zta-deploy-pdp.sh --uninstall
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/infras/k8s-yaml/pdp"
PY_SOURCE="$SCRIPT_DIR/infras/pdp"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

regenerate_configmap() {
  blue "📦 Regenerating ConfigMap from infras/pdp/*..."
  python3 - <<PYEOF
import textwrap

script = open("$PY_SOURCE/pdp_controller.py").read()
reqs = open("$PY_SOURCE/requirements.txt").read()

def indent_block(s, prefix="    "):
    return "\n".join(prefix + line if line else prefix.rstrip() for line in s.split("\n"))

header = '''# =============================================================================
# PDP Controller — Python script packaged as ConfigMap (no image build).
# Mounted to /app/pdp_controller.py in the python:3.11-slim container.
#
# To regenerate this ConfigMap after editing infras/pdp/pdp_controller.py:
#   bash scripts/zta-deploy-pdp.sh --regen-cm-only
# =============================================================================
'''

cm_yaml = f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: zta-pdp-script
  namespace: security
  labels:
    zta.job7189/tier: T1
    zta.job7189/role: pdp
    zta.job7189/team: security
    zta.job7189/data-classification: confidential
    zta.job7189/env: prod
    zta.job7189/exposure: cluster-only
data:
  pdp_controller.py: |
{indent_block(script)}
  requirements.txt: |
{indent_block(reqs)}
"""

with open("$MANIFEST_DIR/20-configmap.yaml", "w") as f:
    f.write(header)
    f.write(cm_yaml)

import yaml
list(yaml.safe_load_all(open("$MANIFEST_DIR/20-configmap.yaml")))
print("✅ ConfigMap regenerated:", "$MANIFEST_DIR/20-configmap.yaml")
PYEOF
}

uninstall() {
  blue "🗑️  Uninstalling PDP Controller..."
  kubectl delete -f "$MANIFEST_DIR/30-deployment.yaml" --ignore-not-found
  kubectl delete -f "$MANIFEST_DIR/20-configmap.yaml" --ignore-not-found
  kubectl delete -f "$MANIFEST_DIR/10-rbac.yaml" --ignore-not-found
  kubectl delete cnp -n security allow-pdp-controller-egress --ignore-not-found 2>/dev/null || true
  green "✅ PDP Controller uninstalled"
  exit 0
}

# Parse args
case "${1:-}" in
  --regen-cm-only) regenerate_configmap; exit 0 ;;
  --uninstall) uninstall ;;
  -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
esac

# Validate environment
if ! command -v kubectl >/dev/null 2>&1; then
  red "ERR: kubectl not in PATH"; exit 1
fi
if ! kubectl get ns security >/dev/null 2>&1; then
  red "ERR: namespace 'security' không tồn tại — chạy 02-deploy-infrastructure.sh trước"
  exit 1
fi

blue "════════════════════════════════════════════════════════"
blue " PDP Controller Deploy (Step 2.3.6 Adaptive Loop)"
blue "════════════════════════════════════════════════════════"

# 1. Regenerate ConfigMap to ensure it's in sync with .py
regenerate_configmap

# 2. Apply manifests
echo
blue "📋 [1/4] RBAC (ServiceAccount + ClusterRole + ClusterRoleBinding)..."
kubectl apply -f "$MANIFEST_DIR/10-rbac.yaml"

blue "📋 [2/4] ConfigMap (Python script + requirements)..."
kubectl apply -f "$MANIFEST_DIR/20-configmap.yaml"

blue "📋 [3/4] Deployment + Service (zta-pdp)..."
kubectl apply -f "$MANIFEST_DIR/30-deployment.yaml"

# 3. Apply Cilium policy allowing PDP egress to kube-apiserver
blue "📋 [4/4] CNP allow-pdp-controller-egress (apiserver + dns)..."
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-pdp-controller-egress
  namespace: security
spec:
  endpointSelector:
    matchLabels:
      app: zta-pdp
  egress:
  # K8s API server — PDP watches pods cluster-wide
  - toEntities: [kube-apiserver, host, remote-node]
    toPorts:
    - ports:
      - {port: "443", protocol: TCP}
      - {port: "6443", protocol: TCP}
  - toCIDR: ["10.96.0.0/12", "172.18.0.0/16"]
    toPorts:
    - ports:
      - {port: "443", protocol: TCP}
      - {port: "6443", protocol: TCP}
  # DNS — must have rules.dns: matchPattern "*" so Cilium DNS proxy
  # learns IP→FQDN mappings for the toFQDNs rule below to work.
  - toEndpoints:
    - matchLabels:
        k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name: kube-system
        k8s:k8s-app: kube-dns
    toPorts:
    - ports:
      - {port: "53", protocol: UDP}
      - {port: "53", protocol: TCP}
      rules:
        dns:
        - matchPattern: "*"
  # PyPI (initial pip install only — broad pattern because PyPI uses
  # Fastly CDN with rotating IPs).
  - toFQDNs:
    - matchPattern: "*.pypi.org"
    - matchPattern: "*.pythonhosted.org"
    - matchPattern: "*.fastly.net"
    - matchPattern: "*.fastlylb.net"
    toPorts:
    - ports:
      - {port: "443", protocol: TCP}
  # Fallback: temporary broad CIDR for first install. PDP only needs this
  # once — after pip cache is warm, can remove via:
  #   kubectl -n security patch cnp allow-pdp-controller-egress --type=json \
  #     -p='[{"op":"remove","path":"/spec/egress/4"}]'
  - toCIDR: ["0.0.0.0/0"]
    toPorts:
    - ports:
      - {port: "443", protocol: TCP}
  ingress:
  # Prometheus scrape on port 9100
  - fromEndpoints:
    - matchLabels:
        k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name: monitoring
        app: prometheus
    toPorts:
    - ports:
      - {port: "9100", protocol: TCP}
EOF

echo
blue "⏳ Waiting for PDP Controller pod ready (timeout 360s — pip install)..."
if kubectl rollout status deployment/zta-pdp -n security --timeout=360s; then
  green "✅ zta-pdp rollout complete"
else
  red "❌ zta-pdp rollout timed out — check logs:"
  kubectl describe pod -n security -l app=zta-pdp | tail -30
  kubectl logs -n security -l app=zta-pdp --tail=30 || true
  exit 1
fi

echo
green "════════════════════════════════════════════════════════"
green " ✅ PDP Controller deployed"
green "════════════════════════════════════════════════════════"
echo
echo "Verify:"
echo "  kubectl -n security get pod -l app=zta-pdp"
echo "  kubectl -n security logs -l app=zta-pdp --tail=20"
echo "  kubectl -n security port-forward svc/zta-pdp-metrics 9100:9100 &"
echo "  curl -s localhost:9100/metrics | grep ^pdp_"
echo
echo "Run 09-verify-zta.sh — Test 4g sẽ check PDP health."
