#!/bin/bash
# Setup Keycloak realm configuration as ConfigMap
set -euo pipefail

echo "? Creating Keycloak realm configuration ConfigMap..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify realm-infra.json exists
if [ ! -f "$SCRIPT_DIR/realm-infra.json" ]; then
  echo "? ERROR: realm-infra.json not found at $SCRIPT_DIR/realm-infra.json"
  exit 1
fi

# Create ConfigMap from realm-infra.json
kubectl create configmap keycloak-realm-config \
  --from-file="realm-infra.json=$SCRIPT_DIR/realm-infra.json" \
  -n security \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "? Keycloak realm configuration ConfigMap created/updated"
echo "  ConfigMap name: keycloak-realm-config"
echo "  Realm: realm-infra.json"
echo "  Namespace: security"
