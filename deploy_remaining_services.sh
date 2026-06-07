#!/bin/bash

# ========================================================================
# SERVICE DEPLOYMENT AUTOMATION SCRIPT
# Deploy remaining services: hiring, candidate, communication, storage
# Usage: Update DIGESTS section below, then run: bash deploy_remaining_services.sh
# ========================================================================

set -e

NAMESPACE="job7189-apps"
CHART_PATH="k8s-management/charts/laravel-app"
VALUES_PATH="k8s-management/values"
REPO_PATH="/home/ptb/projects/DATN"

cd "$REPO_PATH"

# ========================================================================
# UPDATE THESE DIGESTS AFTER BUILDING EACH SERVICE
# ========================================================================
HIRING_DIGEST="PLACEHOLDER_HIRING_DIGEST"
CANDIDATE_DIGEST="PLACEHOLDER_CANDIDATE_DIGEST"
COMMUNICATION_DIGEST="PLACEHOLDER_COMMUNICATION_DIGEST"
STORAGE_DIGEST="PLACEHOLDER_STORAGE_DIGEST"

# ========================================================================
# FUNCTION: Deploy a single service
# ========================================================================
deploy_service() {
  local SERVICE=$1
  local DIGEST=$2
  local DB_NAME=$3
  
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "🚀 Deploying: $SERVICE"
  echo "════════════════════════════════════════════════════════════"
  
  # Update helm values with digest
  local VALUES_FILE="$VALUES_PATH/${SERVICE}-values.yaml"
  sed -i "s|PLACEHOLDER_${SERVICE^^}_DIGEST|$DIGEST|g" "$VALUES_FILE"
  
  # Deploy with helm
  helm upgrade --install "$SERVICE" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$VALUES_FILE"
  
  # Wait for rollout (with timeout)
  echo "⏳ Waiting for $SERVICE deployment..."
  if kubectl rollout status deployment/"$SERVICE" -n "$NAMESPACE" --timeout=300s 2>/dev/null; then
    echo "✅ $SERVICE deployment ready!"
  else
    echo "⚠️  $SERVICE rollout status check timed out (pod may still be starting)"
  fi
  
  # Verify credentials
  sleep 3
  POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  if [ -z "$POD" ]; then
    echo "⚠️  No running pod yet for $SERVICE"
    return 1
  fi
  
  echo "Pod: $POD"
  
  # Check credentials
  CREDS=$(kubectl exec -n "$NAMESPACE" "$POD" -c app -- grep -E "DB_USERNAME|DB_PASSWORD|LEASE_ID" /var/www/.env 2>/dev/null)
  if [ -z "$CREDS" ]; then
    echo "❌ Credentials not injected!"
    return 1
  fi
  
  echo "✅ Credentials injected"
  echo "$CREDS" | sed 's/^/   /'
  
  echo "✅ $SERVICE deployed successfully!"
  return 0
}

# ========================================================================
# DEPLOYMENT SEQUENCE
# ========================================================================
echo "🎯 SERVICE DEPLOYMENT PLAN"
echo "Services to deploy:"
echo "  1. hiring-service"
echo "  2. candidate-service"
echo "  3. communication-service"
echo "  4. storage-service"
echo ""
echo "Please ensure DIGESTS are updated above before running this script!"
echo ""

# Check if digests are still placeholders
if [[ "$HIRING_DIGEST" == "PLACEHOLDER"* ]]; then
  echo "❌ ERROR: DIGESTS not updated! Please update the script with actual digests."
  exit 1
fi

# Deploy services
deploy_service "hiring-service" "$HIRING_DIGEST" "job7189_hiring_db"
deploy_service "candidate-service" "$CANDIDATE_DIGEST" "job7189_candidate_db"
deploy_service "communication-service" "$COMMUNICATION_DIGEST" "job7189_communication_db"
deploy_service "storage-service" "$STORAGE_DIGEST" "job7189_storage_db"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ ALL SERVICES DEPLOYED"
echo "════════════════════════════════════════════════════════════"
