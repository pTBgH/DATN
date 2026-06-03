#!/bin/bash
exec > patch_realm.log 2>&1
echo "Starting..."
kubectl run sec-curl2 -n security --image=curlimages/curl --restart=Never -- sleep 3600
echo "Waiting for pod..."
kubectl wait --for=condition=Ready pod/sec-curl2 -n security --timeout=60s

KC_ADMIN_PASS=$(kubectl get secret -n security app-secrets -o jsonpath='{.data.keycloak-admin-password}' | base64 -d)

# Get admin token
TOKEN=$(kubectl exec -n security sec-curl2 -- curl -s http://keycloak:8080/realms/master/protocol/openid-connect/token \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=${KC_ADMIN_PASS}" \
  -d "grant_type=password" | grep -o '"access_token":"[^"]*' | grep -o '[^"]*$')

echo "Token length: ${#TOKEN}"

if [ "${#TOKEN}" -gt 0 ]; then
  # Get client UUID
  CLIENT_UUID=$(kubectl exec -n security sec-curl2 -- curl -s http://keycloak:8080/admin/realms/7189_internal/clients?clientId=oauth2-proxy \
    -H "Authorization: Bearer $TOKEN" | grep -o '"id":"[^"]*' | head -n 1 | grep -o '[^"]*$')

  echo "Client UUID: $CLIENT_UUID"

  # Patch Client
  kubectl exec -n security sec-curl2 -- curl -s -X PUT http://keycloak:8080/admin/realms/7189_internal/clients/$CLIENT_UUID \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "oauth2-proxy",
      "redirectUris": [
        "http://auth.job7189.local/*",
        "http://db.job7189.local/oauth2/callback",
        "http://kibana.job7189.local/oauth2/callback",
        "http://prometheus.job7189.local/oauth2/callback",
        "http://grafana.job7189.local/oauth2/callback",
        "http://hubble.job7189.local/oauth2/callback",
        "http://kafka.job7189.local/oauth2/callback",
        "http://localhost:8080/oauth2/callback"
      ],
      "webOrigins": [
        "http://auth.job7189.local",
        "http://db.job7189.local",
        "http://kibana.job7189.local",
        "http://prometheus.job7189.local",
        "http://grafana.job7189.local",
        "http://hubble.job7189.local",
        "http://kafka.job7189.local",
        "http://localhost:8080"
      ]
    }' -w "\nClient HTTP Status: %{http_code}\n"

  # Patch Realm
  kubectl exec -n security sec-curl2 -- curl -s -X PUT http://keycloak:8080/admin/realms/7189_internal \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "attributes": {
        "frontendUrl": "http://auth.job7189.local"
      }
    }' -w "\nRealm HTTP Status: %{http_code}\n"
else
  echo "Failed to get token"
fi

kubectl delete pod sec-curl2 -n security
echo "Done"
