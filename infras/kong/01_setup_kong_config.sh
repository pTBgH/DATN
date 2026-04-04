#!/bin/bash
# Setup Kong declarative configuration as ConfigMap
set -euo pipefail

echo "? Creating Kong declarative configuration ConfigMap..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create ConfigMap from kong.yml
kubectl create configmap kong-declarative-config \
  --from-file="$SCRIPT_DIR/kong.yml" \
  -n gateway \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "? Kong configuration ConfigMap created/updated"
echo "  ConfigMap name: kong-declarative-config"
echo "  Namespace: gateway"
echo "  Config location: /opt/kong/kong.yml in pod"
