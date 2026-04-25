#!/bin/bash
# ==========================================
# Script 10: Deploy Tetragon Runtime Security
# ==========================================
# PURPOSE: Deploy Tetragon eBPF runtime enforcement (PEP Runtime layer)
#          and apply TracingPolicy to block suspicious syscalls in job7189-apps.
# RUN AFTER: Script 08 (Security Hardening)
# RESOURCE: ~128Mi per node (DaemonSet), total ~512Mi for 4 nodes
# ROLLBACK: helm uninstall tetragon -n kube-system
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "============================================================"
echo "🛡️ SCRIPT 10: TETRAGON RUNTIME SECURITY"
echo "============================================================"
echo ""

# ========================
# Step 1: Check available RAM
# ========================
echo "━━━ Step 1: Checking available memory ━━━"
AVAIL_MI=$(free -m | awk '/^Mem:/ {print $7}')
echo "   Available RAM: ${AVAIL_MI}Mi"

if [ "$AVAIL_MI" -lt 400 ]; then
  echo "   ⚠️  WARNING: Less than 400Mi available. Tetragon needs ~512Mi."
  echo "   Consider running: scripts/toggle-internal-ui.sh down"
  echo "   to free RAM from phpMyAdmin, Kafbat, Kibana, Grafana UIs."
  read -p "   Continue anyway? [y/N]: " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "   Aborted."
    exit 0
  fi
fi
echo ""

# ========================
# Step 2: Install Tetragon via Helm
# ========================
echo "━━━ Step 2: Installing Tetragon ━━━"

helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo update cilium 2>/dev/null || true

if helm status tetragon -n kube-system >/dev/null 2>&1; then
  echo "   ℹ️  Tetragon already installed, upgrading..."
  helm upgrade tetragon cilium/tetragon -n kube-system \
    --set tetragon.resources.requests.memory=64Mi \
    --set tetragon.resources.limits.memory=128Mi \
    --set tetragon.resources.requests.cpu=50m \
    --set tetragon.resources.limits.cpu=200m \
    --wait --timeout=120s
else
  echo "   Installing Tetragon..."
  helm install tetragon cilium/tetragon -n kube-system \
    --set tetragon.resources.requests.memory=64Mi \
    --set tetragon.resources.limits.memory=128Mi \
    --set tetragon.resources.requests.cpu=50m \
    --set tetragon.resources.limits.cpu=200m \
    --wait --timeout=120s
fi

echo "   Waiting for Tetragon pods..."
kubectl rollout status daemonset/tetragon -n kube-system --timeout=90s 2>/dev/null || true

TETRAGON_READY=$(kubectl get ds tetragon -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
echo "   ✅ Tetragon DaemonSet: ${TETRAGON_READY} nodes ready"
echo ""

# ========================
# Step 3: Apply TracingPolicy — Block suspicious exec in job7189-apps
# ========================
echo "━━━ Step 3: Applying TracingPolicy ━━━"

POLICY_DIR="${SCRIPT_DIR}/infras/k8s-yaml/tetragon-policies"
mkdir -p "$POLICY_DIR"

# TracingPolicy: block shell/curl/wget/nc in job7189-apps namespace
cat > "${POLICY_DIR}/block-suspicious-exec.yaml" <<'POLICY'
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-suspicious-exec
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchArgs:
      - index: 0
        operator: "In"
        values:
        - "/bin/sh"
        - "/bin/bash"
        - "/usr/bin/curl"
        - "/usr/bin/wget"
        - "/usr/bin/nc"
        - "/usr/bin/ncat"
        - "/usr/bin/nmap"
      matchNamespaces:
      - namespace: job7189-apps
        operator: In
      matchActions:
      - action: Sigkill
POLICY

# TracingPolicy: monitor sensitive file access
cat > "${POLICY_DIR}/monitor-sensitive-files.yaml" <<'POLICY'
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: monitor-sensitive-files
spec:
  kprobes:
  - call: "sys_openat"
    syscall: true
    args:
    - index: 1
      type: "string"
    selectors:
    - matchArgs:
      - index: 1
        operator: "Prefix"
        values:
        - "/etc/shadow"
        - "/etc/passwd"
        - "/proc/self/environ"
        - "/var/run/secrets/kubernetes.io"
      matchNamespaces:
      - namespace: job7189-apps
        operator: In
      matchActions:
      - action: Post
POLICY

echo "   Applying TracingPolicies..."
kubectl apply -f "${POLICY_DIR}/block-suspicious-exec.yaml" 2>/dev/null && \
  echo "   ✅ block-suspicious-exec applied" || \
  echo "   ⚠️  block-suspicious-exec failed (CRD may not be ready yet)"

kubectl apply -f "${POLICY_DIR}/monitor-sensitive-files.yaml" 2>/dev/null && \
  echo "   ✅ monitor-sensitive-files applied" || \
  echo "   ⚠️  monitor-sensitive-files failed"

echo ""

# ========================
# Step 4: Verify
# ========================
echo "━━━ Step 4: Verification ━━━"

POLICY_COUNT=$(kubectl get tracingpolicies --no-headers 2>/dev/null | wc -l || echo "0")
echo "   TracingPolicies: ${POLICY_COUNT}"
kubectl get tracingpolicies 2>/dev/null || echo "   (CRD not available yet)"

echo ""
echo "============================================================"
echo "✅ TETRAGON RUNTIME SECURITY DEPLOYED"
echo "============================================================"
echo ""
echo "   DaemonSet: ${TETRAGON_READY} nodes"
echo "   Policies:  ${POLICY_COUNT} TracingPolicy(ies)"
echo ""
echo "   📋 Test: Try running shell in a job7189-apps pod:"
echo "     kubectl exec -n job7189-apps deploy/identity-service -c app -- /bin/sh"
echo "     → Should be killed by Tetragon (SIGKILL)"
echo ""
echo "   📋 View events:"
echo "     kubectl logs -n kube-system ds/tetragon -c export-stdout --tail=20"
echo ""
echo "   🔄 Rollback:"
echo "     helm uninstall tetragon -n kube-system"
echo "     kubectl delete -f ${POLICY_DIR}/"
echo ""
