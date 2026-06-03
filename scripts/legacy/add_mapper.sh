#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="security"
REALM="7189_internal"
CLIENT_ID_NAME="oauth2-proxy"
MAPPER_NAME="audience-oauth2-proxy"

log() {
    echo -e "\n=== $1 ==="
}

cleanup() {
    if [[ -n "${PF_PID:-}" ]]; then
        kill "$PF_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

log "1. Get Keycloak admin password"
KC_ADMIN_PASS=$(kubectl get secret -n "$NAMESPACE" app-secrets -o jsonpath='{.data.keycloak-admin-password}' | base64 -d)

log "2. Port-forward Keycloak"
kubectl port-forward -n "$NAMESPACE" svc/keycloak 8080:8080 >/dev/null 2>&1 &
PF_PID=$!
sleep 3

log "3. Get access token"
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=admin" \
    -d "password=$KC_ADMIN_PASS" \
    -d "grant_type=password" \
    | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "❌ Failed to get token"
    exit 1
fi

log "4. Get client UUID"
CLIENT_UUID=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "http://localhost:8080/admin/realms/$REALM/clients?clientId=$CLIENT_ID_NAME" \
    | jq -r '.[0].id')

if [[ -z "$CLIENT_UUID" || "$CLIENT_UUID" == "null" ]]; then
    echo "❌ Cannot find client: $CLIENT_ID_NAME"
    exit 1
fi

echo "Client UUID: $CLIENT_UUID"

log "5. Check existing mapper"
# Sửa dấu nháy kép lồng nhau trong jq bằng cách dùng nháy đơn bên ngoài
EXISTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "http://localhost:8080/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    | jq -r ".[] | select(.name==\"$MAPPER_NAME\") | .name")

if [[ "$EXISTS" == "$MAPPER_NAME" ]]; then
    echo "✅ Mapper already exists. Done."
    exit 0
fi

log "6. Create mapper"
# Sử dụng biến EOF hoặc bọc single quote để tránh xung đột nháy kép trong JSON payload
RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "http://localhost:8080/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    -d "{
        \"name\": \"$MAPPER_NAME\",
        \"protocol\": \"openid-connect\",
        \"protocolMapper\": \"oidc-audience-mapper\",
        \"consentRequired\": false,
        \"config\": {
            \"included.client.audience\": \"$CLIENT_ID_NAME\",
            \"id.token.claim\": \"false\",
            \"access.token.claim\": \"true\", \
            \"lightweight.claim\": \"false\", \
            \"introspection.token.claim\": \"true\"
        }
    }")

if [[ "$RESP" == "201" || "$RESP" == "204" ]]; then
    echo "✅ Mapper created successfully!"
else
    echo "❌ Failed to create mapper (HTTP $RESP)"
    exit 1
fi
