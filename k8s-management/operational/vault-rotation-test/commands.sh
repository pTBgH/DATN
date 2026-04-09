#!/usr/bin/env bash
set -euo pipefail

# Usage: set VAULT_ADDR and VAULT_TOKEN in environment before running.
# Example:
# VAULT_ADDR=https://vault.vault.svc.cluster.local:8200 \
# VAULT_TOKEN=... ./commands.sh

if [ -z "${VAULT_ADDR:-}" ] || [ -z "${VAULT_TOKEN:-}" ]; then
  echo "Please set VAULT_ADDR and VAULT_TOKEN environment variables." >&2
  exit 2
fi

OUTDIR="$(dirname "$0")/backups"
mkdir -p "$OUTDIR"

echo "Backing up current role to $OUTDIR/role-backup.json"
vault read -format=json -address="$VAULT_ADDR" database/roles/identity-service > "$OUTDIR/role-backup.json"

echo "Setting test TTL: default_ttl=300 (5m), max_ttl=3600"
# This requires permission to write the role. Adjust parameters if desired.
vault write -address="$VAULT_ADDR" database/roles/identity-service default_ttl=300 max_ttl=3600 || { echo "Failed to write role (check permissions)"; exit 3; }

echo "Verify new role by requesting a credential"
vault read -format=json -address="$VAULT_ADDR" database/creds/identity-service | jq . > "$(dirname "$0")/outputs/creds-response-after.json"
cat "$(dirname "$0")/outputs/creds-response-after.json"

echo "Revoke existing leases (force agent to fetch new creds)"
vault lease revoke -address="$VAULT_ADDR" -prefix database/creds/identity-service || echo "revoke failed or not permitted"

echo "Tail the pod secret file to see update (run in separate shell if you want live tail)"
echo "kubectl exec -n job7189-apps identity-service-65977b665-fwsks -c env-loader -- tail -n +1 -f /vault/secrets/.env.db"

echo "After test, restore original role from backups/role-backup.json"
echo "vault write -address=\"$VAULT_ADDR\" database/roles/identity-service @backups/role-backup.json"
