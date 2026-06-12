#!/usr/bin/env bash
# =============================================================================
# zta-backup-dr.sh — Automated ZTA Policy & Vault Secret Store Backup
#
# Addresses: NIST SP 1800-35 §5.5 & C4 Gap (Backup/DR for policy/secrets)
#
# Usage:
#   bash scripts/zta-backup-dr.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
VAULT_INIT_JSON="$SCRIPT_DIR/infras/k8s-yaml/vault-scripts/vault-prod-init.json"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$TS"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

mkdir -p "$BACKUP_PATH"

blue "════════════════════════════════════════════════════════"
blue " Starting ZTA Backup & Disaster Recovery Export"
blue " Timestamp: $TS"
blue "════════════════════════════════════════════════════════"

# -----------------------------------------------------------------------------
# 1. Back up K8s / Cilium Network Policies
# -----------------------------------------------------------------------------
echo
blue "🛡️  [1/4] Exporting Cilium Network Policies..."

if kubectl get cnp -A >/dev/null 2>&1; then
  kubectl get cnp -A -o yaml > "$BACKUP_PATH/cilium-network-policies.yaml"
  green "  ✓ Exported CiliumNetworkPolicies (cnp) to backups/$TS/cilium-network-policies.yaml"
else
  yellow "  ⚠ No CiliumNetworkPolicies found"
fi

if kubectl get ccnp >/dev/null 2>&1; then
  kubectl get ccnp -o yaml > "$BACKUP_PATH/cilium-clusterwide-policies.yaml"
  green "  ✓ Exported CiliumClusterwideNetworkPolicies (ccnp) to backups/$TS/cilium-clusterwide-policies.yaml"
else
  yellow "  ⚠ No CiliumClusterwideNetworkPolicies found"
fi

# -----------------------------------------------------------------------------
# 2. Back up Gatekeeper OPA Constraints & Templates
# -----------------------------------------------------------------------------
echo
blue "🛡️  [2/4] Exporting OPA Gatekeeper Constraints..."

if kubectl get constrainttemplates >/dev/null 2>&1; then
  kubectl get constrainttemplates -o yaml > "$BACKUP_PATH/gatekeeper-templates.yaml"
  kubectl get constraints -o yaml > "$BACKUP_PATH/gatekeeper-constraints.yaml"
  green "  ✓ Exported Gatekeeper templates & constraints to backups/$TS/"
else
  yellow "  ⚠ Gatekeeper CRDs not registered or no constraints found"
fi

# -----------------------------------------------------------------------------
# 3. Back up Vault Secrets Store (Supports File and Raft storage types)
# -----------------------------------------------------------------------------
echo
blue "🔑 [3/4] Exporting HashiCorp Vault Secrets Store..."

if ! kubectl get pods -n vault vault-0 >/dev/null 2>&1; then
  red "  ❌ Vault pod vault-0 is not running; skipping Vault backup."
else
  # Retrieve Vault storage type
  STORAGE_TYPE=$(kubectl exec -n vault vault-0 -c vault -- sh -c \
    "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json" \
    | jq -r '.storage_type' 2>/dev/null || echo "file")

  blue "  Detected Vault Storage Type: $STORAGE_TYPE"

  if [ "$STORAGE_TYPE" = "file" ]; then
    blue "  Saving file storage data tarball from vault-0..."
    if kubectl exec -n vault vault-0 -c vault -- sh -c \
      "tar -czf /tmp/vault-data.tar.gz -C /vault data" >/dev/null 2>&1; then
      
      blue "  Downloading backup tarball to host..."
      if kubectl cp vault/vault-0:/tmp/vault-data.tar.gz "$BACKUP_PATH/vault-data.tar.gz" -c vault >/dev/null 2>&1; then
        green "  ✓ Exported Vault File storage tarball to backups/$TS/vault-data.tar.gz"
      else
        red "  ❌ Failed to copy data tarball from vault-0 pod"
      fi
      
      # Clean up inside container
      kubectl exec -n vault vault-0 -c vault -- rm -f /tmp/vault-data.tar.gz
    else
      red "  ❌ Failed to create tarball inside vault-0 pod"
    fi
  else
    # Raft storage type
    if [ ! -f "$VAULT_INIT_JSON" ]; then
      red "  ❌ Vault initialization file not found at: $VAULT_INIT_JSON"
      red "  ❌ Unable to retrieve root token for Vault snapshot; skipping."
    else
      TOKEN=$(jq -r '.root_token' "$VAULT_INIT_JSON" 2>/dev/null || echo "")
      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        red "  ❌ Failed to parse root token from vault-prod-init.json"
      else
        blue "  Saving raft snapshot on vault-0..."
        if kubectl exec -n vault vault-0 -c vault -- sh -c \
          "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN=$TOKEN vault operator raft snapshot save /tmp/vault-snapshot.snap" >/dev/null 2>&1; then
          
          blue "  Downloading snapshot file to host..."
          if kubectl cp vault/vault-0:/tmp/vault-snapshot.snap "$BACKUP_PATH/vault-raft-database.snap" -c vault >/dev/null 2>&1; then
            green "  ✓ Exported Vault Raft Database Snapshot to backups/$TS/vault-raft-database.snap"
          else
            red "  ❌ Failed to copy snapshot file from vault-0 pod"
          fi
          
          # Clean up temp file inside container
          kubectl exec -n vault vault-0 -c vault -- rm -f /tmp/vault-snapshot.snap
        else
          red "  ❌ Failed to execute vault snapshot inside vault-0 pod (is Vault sealed?)"
        fi
      fi
    fi
  fi
fi

# -----------------------------------------------------------------------------
# 4. Packaging and Summary
# -----------------------------------------------------------------------------
echo
blue "📦 [4/4] Archiving backup files..."
cd "$BACKUP_DIR"
tar -czf "$TS-backup.tar.gz" "$TS"
rm -rf "$TS"

green "════════════════════════════════════════════════════════"
green " ✅ ZTA Backup & DR Export Completed Successfully!"
green " Archive location: backups/$TS-backup.tar.gz"
green "════════════════════════════════════════════════════════"
echo
