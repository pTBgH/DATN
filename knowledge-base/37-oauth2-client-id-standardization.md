# 37 — OAuth2 Client ID Standardization

> **Status**: Implemented (June 6, 2026)  
> **Scope**: Unified naming convention for Keycloak clients across all frontends and services  
> **Impact**: Simplifies JWT verification in Kong and backend services; eliminates environment-specific suffixes from app names

## 1. Problem & Motivation

### Before standardization:
```
❌ Inconsistent: recruiter-app-dev, candidate-app-dev
   ├─ "-dev" suffix implies environment (dev/staging/prod)
   ├─ But it's hardcoded in all configs (not swapped by environment)
   └─ Creates confusion: is "-dev" part of app name or environment?

❌ Multiple naming conventions:
   ├─ Keycloak realm: recruiter-app-dev, candidate-app-dev
   ├─ Frontend .env: recruiter-app-dev, candidate-app-dev
   ├─ Backend defaults: recruiter-client, candidate-client, topjob-client (outdated!)
   ├─ Kong config: Expected azp claim value (unclear)
   └─ Results: azp mismatch → 401 errors
```

### After standardization:
```
✅ Unified: recruiter-app, candidate-app
   ├─ No environment suffix (environment is K8s namespace, Helm values)
   ├─ Clear app identity: "recruiter" and "candidate"
   └─ Consistent across all systems
```

---

## 2. Naming Convention Decision

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| **App suffix** | `-app` | Generic, clear it's an application |
| **Environment suffix** | ❌ None | Environment is managed via K8s namespace + Helm values (dev, staging, prod) |
| **Platform prefix** | ❌ None | All in job7189 realm; no need for duplication |
| **Client names** | `recruiter-app`, `candidate-app` | Minimal, unambiguous |
| **Fallback defaults** | Same as standard names | No environment-specific defaults in code |

---

## 3. Changes Implemented

### 3.1 Keycloak Realm (realm-job7189.json)

**Before:**
```json
{
  "clientId": "recruiter-app-dev",
  "name": "Recruiter Web App Dev",
  ...
},
{
  "clientId": "candidate-app-dev",
  "name": "Candidate Web App Dev",
  ...
}
```

**After:**
```json
{
  "clientId": "recruiter-app",
  "name": "Recruiter App (RCT Frontend)",
  ...
},
{
  "clientId": "candidate-app",
  "name": "Candidate App (ATD Frontend)",
  ...
}
```

**Effect:** Keycloak will issue tokens with `azp: recruiter-app` or `azp: candidate-app` in JWT payload.

### 3.2 Frontend Configuration

#### rct_frontend / atd_frontend

**File**: `.env.example`
```diff
- NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=recruiter-app-dev
+ NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=recruiter-app
```

**File**: `src/lib/config.ts`
```diff
- process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID ?? "recruiter-app-dev",
+ process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID ?? "recruiter-app",
```

**Effect**: Frontend passes correct `client_id` to Keycloak OAuth2 password grant → correct JWT `azp` claim.

### 3.3 Backend Services

#### Helm values (k8s-management/values/laravel-common-values.yaml)

**Before:**
```yaml
KEYCLOAK_RECRUITER_CLIENT_ID: "recruiter-app-dev"
KEYCLOAK_CANDIDATE_CLIENT_ID: "candidate-app-dev"
```

**After:**
```yaml
KEYCLOAK_RECRUITER_CLIENT_ID: "recruiter-app"
KEYCLOAK_CANDIDATE_CLIENT_ID: "candidate-app"
```

**Effect:** All 7 Laravel microservices (identity, candidate, job, hiring, communication, storage, workspace) now expect azp match against standardized names.

#### Service config defaults (src/*/laravel_back/config/services.php)

**Updated for all services:**
```php
'clients' => [
    'recruiter' => env('KEYCLOAK_RECRUITER_CLIENT_ID', 'recruiter-app'),
    'candidate' => env('KEYCLOAK_CANDIDATE_CLIENT_ID', 'candidate-app'),
]
```

**Previous inconsistency (FIXED):**
```php
// ❌ Before: Different defaults in different services
'recruiter' => env(..., 'recruiter-client'),     // identity-service
'candidate' => env(..., 'candidate-client'),     // candidate-service
'candidate' => env(..., 'topjob-client'),        // others (outdated!)
```

### 3.4 Test & Utility Scripts

**Files updated:**
- `scripts/utils/test-keycloak-token.sh`
- `scripts/utils/get-keycloak-token.sh`
- `scripts/legacy/atd-bringup.sh`
- `scripts/legacy/atd-fix-identity-jwt.sh`
- `infras/keycloak/scripts/add-test-users.sh`

**Change:** All hardcoded `recruiter-app-dev`, `candidate-app-dev` → `recruiter-app`, `candidate-app`

---

## 4. JWT Flow (with standardized client IDs)

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Frontend OAuth2 Password Grant                              │
├─────────────────────────────────────────────────────────────────┤
│ POST /realms/job7189/protocol/openid-connect/token             │
│ {                                                               │
│   grant_type: "password"                                        │
│   client_id: "recruiter-app"  ← Standardized                   │
│   username: "recruiter1"                                        │
│   password: "..."                                               │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Keycloak Signs Token                                        │
├─────────────────────────────────────────────────────────────────┤
│ JWT Payload (RS256 signed):                                     │
│ {                                                               │
│   sub: "keycloak-user-id-xxx"                                  │
│   preferred_username: "recruiter1"                              │
│   azp: "recruiter-app"  ← Standardized (client that requested)│
│   iss: "http://keycloak.security.svc.cluster.local:8080/..."  │
│   ...                                                           │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Kong Validates JWT                                          │
├─────────────────────────────────────────────────────────────────┤
│ POST request:                                                   │
│   Authorization: Bearer <token>                                 │
│                                                                 │
│ Kong jwt plugin:                                                │
│   ✓ Verify signature against Keycloak RSA public key           │
│   ✓ Confirm iss matches one of 4 keys in jwt_secrets[]         │
│   ✓ Confirm azp=recruiter-app matches consumer config          │
│   → Token valid → Forward to pre-function                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Kong Pre-function Calls OPA                                 │
├─────────────────────────────────────────────────────────────────┤
│ POST http://opa.security.svc.cluster.local:8181/v1/data/...    │
│ {                                                               │
│   input: {                                                      │
│     method: "GET",                                              │
│     path: "/api/recruiters/profile",                            │
│     jwt: {                                                      │
│       sub: "keycloak-user-id-xxx",                             │
│       azp: "recruiter-app",  ← Used for logging + audit        │
│       preferred_username: "recruiter1"                          │
│     }                                                           │
│   }                                                             │
│ }                                                               │
│                                                                 │
│ OPA default.rego:                                               │
│   if path in public.rego whitelist → allow                     │
│   elif jwt.sub != "" → allow  (✓ recruiter-app has sub)        │
│   else → deny 403                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Identity Service Receives Request                           │
├─────────────────────────────────────────────────────────────────┤
│ Laravel middleware VerifyKeycloakToken:                         │
│   - Re-decode JWT payload                                       │
│   - Extract azp claim → "recruiter-app"                        │
│   - Match against KEYCLOAK_RECRUITER_CLIENT_ID="recruiter-app" │
│   ✓ Match! → Set Auth::user(type='recruiter')                 │
│                                                                 │
│ Laravel middleware EnsureUserRole ('role:recruiter'):           │
│   - Check user->type == 'recruiter' ✓                          │
│   - Allow → execute controller                                  │
│                                                                 │
│ GET /api/recruiters/profile                                     │
│   → 200 OK { id, email, name, ... }                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Deployment Changes

### 5.1 Keycloak StatefulSet/Deployment

- **ConfigMap**: `security/keycloak-realm-config` contains updated `realm-job7189.json`
- **Restart required**: Yes (pick up new client names from realm file)
- **Downtime**: ~2-3 minutes (Keycloak DB migration if needed)
- **Rollback**: Revert realm JSON and restart

### 5.2 Backend Services (All 7)

- **Deployment method**: Helm upgrade
- **Values file**: `k8s-management/values/laravel-common-values.yaml`
- **Changes**: Environment variables updated via ConfigMap injection
- **Rollout**: Rolling update (pods restart 1-by-1)
- **Downtime**: None (rolling)

#### Affected deployments:
```bash
identity-service
candidate-service
job-service
hiring-service
communication-service
storage-service
workspace-service
```

### 5.3 Frontend (Cloudflare Pages)

- **Deployment method**: Git push + Cloudflare Pages rebuild
- **Changes**: `.env` variables (NEXT_PUBLIC_KEYCLOAK_CLIENT_ID)
- **Rollout**: Atomic (build/deploy whole app)
- **Downtime**: None (blue-green by Cloudflare)

---

## 6. Verification Checklist

### ✅ Pre-deployment
- [x] Keycloak realm JSON updated (clients renamed)
- [x] Helm values updated (laravel-common-values.yaml)
- [x] Backend config defaults updated (all 7 services)
- [x] Frontend .env.example updated
- [x] Frontend config.ts updated (default fallback)
- [x] Test scripts updated

### ✅ Deployment
- [x] Keycloak restarted (loads new realm)
- [x] Identity-service redeployed (Helm upgrade)
- [x] Frontend redeployed (Git push + Pages rebuild)

### ✅ Post-deployment testing
```bash
# 1. Token acquisition
curl http://keycloak.security.svc.cluster.local:8080/realms/job7189/protocol/openid-connect/token \
  -X POST \
  -d "grant_type=password&client_id=recruiter-app&username=recruiter1&password=recruiter1" \
| jq '.access_token' | base64 -d | jq '.azp'
# Expected: "recruiter-app"

# 2. Kong JWT verification
# Send token with Authorization header
# Kong logs should show: azp=recruiter-app (not empty)

# 3. Identity service verification
# GET /api/recruiters/profile should return 200 (not 401/403)

# 4. OPA audit logs
# Check Kong decision logs for OPA allow/deny decisions
```

---

## 7. Troubleshooting

### Symptom: Still getting 401 after deployment

**Check**:
1. Keycloak clients have correct names:
   ```bash
   curl http://keycloak.security.svc.cluster.local:8080/admin/realms/job7189/clients \
     -H "Authorization: Bearer <admin-token>" | jq '.[].clientId'
   # Should see: recruiter-app, candidate-app
   ```

2. Token contains correct azp:
   ```bash
   <token> | base64 -d | jq '.azp'
   # Should be: recruiter-app or candidate-app
   ```

3. Kong jwt plugin enabled on route:
   ```bash
   kubectl port-forward -n gateway pod/kong-gateway-... 8001:8001
   curl http://localhost:8001/routes | jq '.[] | select(.name=="identity-profiles") | .plugins[].name'
   # Should include: jwt
   ```

4. Identity-service env vars loaded:
   ```bash
   kubectl exec -n job7189-apps pod/identity-service-... -- env | grep KEYCLOAK_
   # Should show: recruiter-app, candidate-app (not -dev suffix)
   ```

### Symptom: Keycloak realm not loaded

**Fix**:
```bash
# Restart Keycloak to reload realm-job7189.json from ConfigMap
export KUBECONFIG=/home/ptb/.kube/config-job7189
kubectl rollout restart deployment/keycloak -n security
kubectl rollout status deployment/keycloak -n security --timeout=180s
```

### Symptom: Frontend using old client ID in localStorage

**Fix**:
```bash
# Clear browser localStorage
localStorage.removeItem('job7189.token')
# Force Pages rebuild: git push or use Cloudflare API
```

---

## 8. Environment-Specific Deployments

The standardized names are **environment-agnostic**. To deploy to different environments:

### Example: Deploy to Staging

```bash
# 1. Update Keycloak for staging:
#    Edit staging realm JSON or create staging clients in Keycloak

# 2. Update K8s Helm values for staging namespace:
kubectl create namespace job7189-staging

helm upgrade identity-service ./k8s-management/charts/laravel-app \
  --namespace job7189-staging \
  -f k8s-management/values/laravel-common-values.yaml \
  -f k8s-management/values/identity-values.yaml

# 3. Deploy frontend to staging environment:
#    Cloudflare Pages → Staging deployment
#    Set NEXT_PUBLIC_KEYCLOAK_URL=https://auth-staging.job7189.com
#    Keep NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=recruiter-app
```

**Key insight:** Client IDs stay the same; only the Keycloak URL and namespace change.

---

## 9. References

- **Related docs**:
  - [36-opa-user-authz.md](36-opa-user-authz.md) — JWT verification at Kong level
  - [Kong configuration](../infras/kong/kong.yml) — JWT plugin + consumer setup
  - [Keycloak realm](../infras/keycloak/realms/realm-job7189.json) — Client definitions

- **Implementation files**:
  - [k8s-management/values/laravel-common-values.yaml](../k8s-management/values/laravel-common-values.yaml)
  - [rct_frontend/src/lib/config.ts](../rct_frontend/src/lib/config.ts)
  - [src/identity_service/laravel_back/config/services.php](../src/identity_service/laravel_back/config/services.php)

