#!/usr/bin/env bash
# =============================================================================
# rollback-namespace-consolidation.sh — Rollback script to restore pdp-system and trivy-system
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$REPO_DIR/backups/pre-namespace-consolidation"

export KUBECONFIG=/home/ptb/.kube/config-job7189

echo "🔄 Restoring Kubernetes namespaces..."

# Restore pdp-system namespace
if [ -f "$BACKUP_DIR/ns-pdp-system.yaml" ]; then
  echo "  Applying ns-pdp-system.yaml..."
  kubectl apply -f "$BACKUP_DIR/ns-pdp-system.yaml"
else
  echo "  ns-pdp-system.yaml not found, creating manually..."
  kubectl create namespace pdp-system --dry-run=client -o yaml | kubectl apply -f -
fi

# Restore trivy-system namespace
if [ -f "$BACKUP_DIR/ns-trivy-system.yaml" ]; then
  echo "  Applying ns-trivy-system.yaml..."
  kubectl apply -f "$BACKUP_DIR/ns-trivy-system.yaml"
else
  echo "  ns-trivy-system.yaml not found, creating manually..."
  kubectl create namespace trivy-system --dry-run=client -o yaml | kubectl apply -f -
fi

# Restore other objects in trivy-system
if [ -f "$BACKUP_DIR/all-trivy-system.yaml" ]; then
  echo "  Restoring trivy-system services & deployments..."
  # Use || true since completed jobs or immutable fields might throw warnings
  kubectl apply -f "$BACKUP_DIR/all-trivy-system.yaml" || true
fi

# Restore CiliumNetworkPolicies in trivy-system
if [ -f "$BACKUP_DIR/cnp-trivy-system.yaml" ]; then
  echo "  Restoring trivy-system CiliumNetworkPolicies..."
  kubectl apply -f "$BACKUP_DIR/cnp-trivy-system.yaml"
fi

echo "🔄 Restoring code files to pre-consolidation git commit..."
cd "$REPO_DIR"
git checkout -- \
  infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh \
  infras/k8s-yaml/cilium-policies/namespaces/README.md \
  scripts/zta-microseg-step2-validate.sh \
  scripts/zta-kb-reconcile.sh \
  scripts/diagnostics/zta-audit-selectors.sh \
  scripts/zta-audit-and-remediate.sh

# Recreate the deleted 24-trivy-system.yaml if it was deleted
git checkout -- infras/k8s-yaml/cilium-policies/namespaces/24-trivy-system.yaml || true

echo "✅ Rollback complete! Namespaces and policies restored."
