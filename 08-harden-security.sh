#!/bin/bash
# ==========================================
# Script 08: Security Hardening — mTLS + WireGuard
# ==========================================
# PURPOSE: Enable Cilium mutual authentication (sidecarless mTLS) and
#          WireGuard transparent encryption AFTER all services are stable.
#
# ⚠️ IMPORTANT ORDER:
#   1. Run 01→02→03→05 first and verify ALL pods are Running/Ready
#   2. Run this script ONLY when the cluster is stable
#   3. Each phase does a rolling restart + health check before proceeding
#   4. Use ZTA_HARDEN_WIREGUARD=0 to skip WireGuard (mTLS only)
#
# ROLLBACK:
#   kubectl -n kube-system patch configmap cilium-config --type merge \
#     -p '{"data":{"mesh-auth-enabled":"false","enable-wireguard":"false"}}'
#   kubectl -n kube-system rollout restart ds/cilium
# ==========================================

set -euo pipefail

SCRIPT_START_TIME=$(date +%s)
ZTA_HARDEN_WIREGUARD="${ZTA_HARDEN_WIREGUARD:-1}"
CILIUM_RESTART_TIMEOUT="${CILIUM_RESTART_TIMEOUT:-300}"
POST_RESTART_SETTLE="${POST_RESTART_SETTLE:-30}"

echo ""
echo "============================================================"
echo "🔒 SCRIPT 08: SECURITY HARDENING (mTLS + WireGuard)"
echo "============================================================"
echo ""

# ========================
# Pre-flight: All critical pods must be healthy
# ========================
echo "🔍 Pre-flight: Verifying cluster stability..."

# Check Laravel services
NOT_READY=$(kubectl get deploy -n job7189-apps --no-headers 2>/dev/null \
  | awk '{if ($2 != $4 && $4+0 < $2+0) print $1}' || true)
if [ -n "$NOT_READY" ]; then
  echo "❌ ERROR: Some Laravel deployments are not fully Ready:"
  echo "$NOT_READY"
  echo "   Fix these before enabling security hardening"
  exit 1
fi
echo "   ✓ All Laravel deployments Ready"

# Check Vault
if ! kubectl exec -n vault vault-0 -- vault status 2>/dev/null | grep -q "Sealed.*false"; then
  echo "❌ ERROR: Vault is sealed or not accessible"
  exit 1
fi
echo "   ✓ Vault unsealed"

# Check Cilium
CILIUM_READY=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
CILIUM_DESIRED=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
if [ "$CILIUM_READY" != "$CILIUM_DESIRED" ] || [ "$CILIUM_READY" = "0" ]; then
  echo "❌ ERROR: Cilium agents not fully Ready ($CILIUM_READY/$CILIUM_DESIRED)"
  exit 1
fi
echo "   ✓ Cilium agents Ready ($CILIUM_READY/$CILIUM_DESIRED)"

# Show current Cilium security config
echo ""
echo "📋 Current Cilium security configuration:"
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.mesh-auth-enabled}' 2>/dev/null && echo " ← mesh-auth-enabled" || echo "(not set) ← mesh-auth-enabled"
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}' 2>/dev/null && echo " ← enable-wireguard" || echo "(not set) ← enable-wireguard"
echo ""

# ========================
# Phase 1: Enable Mutual Authentication (mTLS sidecarless)
# ========================
echo "🔐 Phase 1: Enabling Cilium Mutual Authentication..."
echo "   This provides service-to-service mTLS without sidecars using Cilium's"
echo "   built-in SPIFFE identity framework."
echo ""

# Enable mesh-auth
kubectl -n kube-system patch configmap cilium-config --type merge \
  -p '{"data":{"mesh-auth-enabled":"true"}}' 2>/dev/null || {
  echo "❌ Failed to patch cilium-config for mesh-auth"
  exit 1
}
echo "   ✓ mesh-auth-enabled=true set in cilium-config"

# Rolling restart Cilium agents
echo "   Rolling restart Cilium agents (timeout: ${CILIUM_RESTART_TIMEOUT}s)..."
kubectl -n kube-system rollout restart ds/cilium
if kubectl -n kube-system rollout status ds/cilium --timeout="${CILIUM_RESTART_TIMEOUT}s"; then
  echo "   ✓ Cilium agents restarted with mesh-auth enabled"
else
  echo "❌ Cilium rollout failed after enabling mesh-auth!"
  echo "   ROLLBACK: kubectl -n kube-system patch configmap cilium-config --type merge -p '{\"data\":{\"mesh-auth-enabled\":\"false\"}}'"
  echo "   Then: kubectl -n kube-system rollout restart ds/cilium"
  exit 1
fi

# Settle period — let pods re-establish connections
echo "   Settling (${POST_RESTART_SETTLE}s) — letting services re-establish connections..."
sleep "$POST_RESTART_SETTLE"

# Post-check: verify services still healthy
echo "   Post-check: verifying service health after mTLS..."
NOT_READY_POST=$(kubectl get deploy -n job7189-apps --no-headers 2>/dev/null \
  | awk '{if ($4+0 < $2+0) print $1}' || true)
if [ -n "$NOT_READY_POST" ]; then
  echo "⚠ WARNING: Some deployments lost Ready state after mTLS:"
  echo "$NOT_READY_POST"
  echo "   Check if services need restart: kubectl rollout restart deploy -n job7189-apps"
else
  echo "   ✓ All services healthy after mTLS activation"
fi

# Verify mesh-auth is active
echo ""
echo "   Verifying mesh-auth status on Cilium agent..."
POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -n1 || true)
if [ -n "$POD" ]; then
  kubectl -n kube-system exec "$POD" -c cilium-agent -- cilium config | grep -i "mesh-auth" || true
fi
echo ""
echo "✅ Phase 1 COMPLETE: Mutual Authentication (mTLS) enabled"
echo ""

# ========================
# Phase 2: Enable WireGuard Transparent Encryption
# ========================
if [ "$ZTA_HARDEN_WIREGUARD" = "1" ]; then
  echo "🔒 Phase 2: Enabling WireGuard Transparent Encryption..."
  echo "   This encrypts ALL pod-to-pod traffic at the kernel level using WireGuard."
  echo ""

  # Enable WireGuard
  kubectl -n kube-system patch configmap cilium-config --type merge \
    -p '{"data":{"enable-wireguard":"true"}}' 2>/dev/null || {
    echo "❌ Failed to patch cilium-config for WireGuard"
    exit 1
  }
  echo "   ✓ enable-wireguard=true set in cilium-config"

  # Rolling restart Cilium agents (again)
  echo "   Rolling restart Cilium agents for WireGuard (timeout: ${CILIUM_RESTART_TIMEOUT}s)..."
  kubectl -n kube-system rollout restart ds/cilium
  if kubectl -n kube-system rollout status ds/cilium --timeout="${CILIUM_RESTART_TIMEOUT}s"; then
    echo "   ✓ Cilium agents restarted with WireGuard enabled"
  else
    echo "❌ Cilium rollout failed after enabling WireGuard!"
    echo "   ROLLBACK: kubectl -n kube-system patch configmap cilium-config --type merge -p '{\"data\":{\"enable-wireguard\":\"false\"}}'"
    echo "   Then: kubectl -n kube-system rollout restart ds/cilium"
    exit 1
  fi

  # Settle period
  echo "   Settling (${POST_RESTART_SETTLE}s)..."
  sleep "$POST_RESTART_SETTLE"

  # Post-check
  echo "   Post-check: verifying service health after WireGuard..."
  NOT_READY_WG=$(kubectl get deploy -n job7189-apps --no-headers 2>/dev/null \
    | awk '{if ($4+0 < $2+0) print $1}' || true)
  if [ -n "$NOT_READY_WG" ]; then
    echo "⚠ WARNING: Some deployments lost Ready state after WireGuard:"
    echo "$NOT_READY_WG"
  else
    echo "   ✓ All services healthy after WireGuard activation"
  fi

  # Verify WireGuard interfaces
  echo ""
  echo "   Verifying WireGuard interfaces on Cilium agent..."
  POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o name | head -n1 || true)
  if [ -n "$POD" ]; then
    kubectl -n kube-system exec "$POD" -c cilium-agent -- cilium encrypt status 2>/dev/null || echo "   (encrypt status not available)"
  fi
  echo ""
  echo "✅ Phase 2 COMPLETE: WireGuard Transparent Encryption enabled"
else
  echo "⏩ Phase 2 SKIPPED: WireGuard disabled (ZTA_HARDEN_WIREGUARD=0)"
  echo "   To enable later: ZTA_HARDEN_WIREGUARD=1 bash 08-harden-security.sh"
fi

# ========================
# Summary
# ========================
TOTAL_TIME=$(($(date +%s) - SCRIPT_START_TIME))
echo ""
echo "============================================================"
echo "✔ SCRIPT 08 COMPLETED (${TOTAL_TIME}s)"
echo "============================================================"
echo ""
echo "📋 Security Posture Summary:"
echo "   Cilium Mesh Auth (mTLS): ENABLED"
if [ "$ZTA_HARDEN_WIREGUARD" = "1" ]; then
  echo "   WireGuard Encryption:    ENABLED"
else
  echo "   WireGuard Encryption:    DISABLED (run with ZTA_HARDEN_WIREGUARD=1)"
fi
echo "   Microsegmentation:       ENABLED (from script 02)"
echo ""
echo "📋 Final Cilium security config:"
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data}' 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k in sorted(d):
  if any(x in k for x in ['auth','wireguard','encrypt','l7-proxy']):
    print(f'   {k}: {d[k]}')
" 2>/dev/null || kubectl -n kube-system get configmap cilium-config -o yaml | grep -E "(mesh-auth|wireguard|encrypt|l7-proxy)" || true
echo ""
echo "⚠ ROLLBACK if issues arise:"
echo "   kubectl -n kube-system patch configmap cilium-config --type merge \\"
echo "     -p '{\"data\":{\"mesh-auth-enabled\":\"false\",\"enable-wireguard\":\"false\"}}'"
echo "   kubectl -n kube-system rollout restart ds/cilium"
echo ""
