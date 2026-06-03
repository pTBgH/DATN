import urllib.request
import urllib.parse
import json
import os

token_url = 'http://localhost:8080/realms/master/protocol/openid-connect/token'
admin_pass = os.environ.get('KC_ADMIN_PASS')

data = urllib.parse.urlencode({
    'client_id': 'admin-cli',
    'username': 'admin',
    'password': admin_pass,
    'grant_type': 'password'
}).encode('utf-8')

req = urllib.request.Request(token_url, data=data)
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        token = res.get('access_token')
except Exception as e:
    print(f"Error getting token: {e}")
    exit(1)

print(f"Got token, length {len(token)}")

clients_url = 'http://localhost:8080/admin/realms/7189_internal/clients?clientId=oauth2-proxy'
req = urllib.request.Request(clients_url, headers={'Authorization': f'Bearer {token}'})
try:
    with urllib.request.urlopen(req) as response:
        clients = json.loads(response.read().decode())
        client_id = clients[0]['id']
except Exception as e:
    print(f"Error getting client: {e}")
    exit(1)

print(f"Got client UUID: {client_id}")

client_patch = {
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
}

req = urllib.request.Request(
    f'http://localhost:8080/admin/realms/7189_internal/clients/{client_id}',
    data=json.dumps(client_patch).encode('utf-8'),
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    method='PUT'
)
try:
    with urllib.request.urlopen(req) as response:
        print(f"Client patch status: {response.status}")
except Exception as e:
    print(f"Error patching client: {e}")

realm_patch = {
    "attributes": {
        "frontendUrl": "http://auth.job7189.local"
    }
}

req = urllib.request.Request(
    'http://localhost:8080/admin/realms/7189_internal',
    data=json.dumps(realm_patch).encode('utf-8'),
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    method='PUT'
)
try:
    with urllib.request.urlopen(req) as response:
        print(f"Realm patch status: {response.status}")
except Exception as e:
    print(f"Error patching realm: {e}")
