#!/bin/bash
# Setup oauth2-proxy with dynamic Keycloak IP
set -euo pipefail

echo "? Setting up oauth2-proxy..."
echo "  Waiting for Keycloak service to be assigned IP..."

# Get Keycloak service IP
KEYCLOAK_IP=""
RETRY=0
MAX_RETRIES=30

while [ -z "$KEYCLOAK_IP" ] && [ $RETRY -lt $MAX_RETRIES ]; do
  KEYCLOAK_IP=$(kubectl get svc keycloak -n security -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
  if [ -z "$KEYCLOAK_IP" ]; then
    echo "  (attempt $((RETRY+1))/$MAX_RETRIES) Waiting for Keycloak service..."
    sleep 2
    ((RETRY++))
  fi
done

if [ -z "$KEYCLOAK_IP" ]; then
  echo "? ERROR: Could not get Keycloak service IP after ${MAX_RETRIES} attempts"
  exit 1
fi

echo "? Keycloak service IP: $KEYCLOAK_IP"

# Get template YAML and update IP
TEMPLATE_FILE="/dev/stdin"
cat > /tmp/oauth2-proxy-patch.json <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "hostAliases": [
          {
            "ip": "$KEYCLOAK_IP",
            "hostnames": ["auth.job7189.local"]
          }
        ]
      }
    }
  }
}
EOF

# First apply the YAML files (ConfigMap, Secret, Deployment)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OAUTH2_YAML="$SCRIPT_DIR/04_oauth2_proxy.yaml"

if [ ! -f "$OAUTH2_YAML" ]; then
  echo "? ERROR: oauth2-proxy YAML not found at $OAUTH2_YAML"
  exit 1
fi

echo "? Applying oauth2-proxy configuration..."
kubectl apply -f "$OAUTH2_YAML"

# Wait a moment for ConfigMap and Secret to be created
sleep 2

# Patch deployment with correct Keycloak IP
echo "? Updating oauth2-proxy deployment with Keycloak IP $KEYCLOAK_IP..."
kubectl patch deployment oauth2-proxy -n security --type merge -p "$(cat /tmp/oauth2-proxy-patch.json)" || true

echo "? oauth2-proxy configuration complete"
echo "  ConfigMap: oauth2-proxy-config"
echo "  Secret: oauth2-proxy-secret"
echo "  Deployment: oauth2-proxy"
echo "  Keycloak endpoint: auth.job7189.local (IP: $KEYCLOAK_IP)"
