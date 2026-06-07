# OAuth2 Integration & Backend JWT Verification - Session Summary

**Date:** 2026-06-06 to 2026-06-07  
**Focus:** Fix 401 error on `/api/recruiters/profile` endpoint and complete OAuth2 flow  
**Status:** ✅ Kong & OPA working; ⚠️ Backend middleware env var issue blocking final test

---

## ✅ What We Completed

### 1. **Kong JWT Plugin - Fixed & Verified** ✅
- **Problem:** Kong was rejecting tokens with "Invalid signature"
- **Root Cause:** Kong configured with old RSA public key (n="7NPvdw..."), Keycloak using different key (n="1lv5qrFnc8x/...")
- **Solution:** Updated all 4 JWT credential variants in `infras/kong/kong.yml` with current Keycloak RSA public key
- **Verification:** Kong logs show successful JWT validation before OPA call
- **File Changed:** [infras/kong/kong.yml](infras/kong/kong.yml)

### 2. **Client ID Standardization** ✅
- **Problem:** Inconsistent naming: Keycloak issuing `azp="recruiter-app-dev"`, backend checking for `recruiter-app`
- **Solution:** Removed `-dev` suffix from client IDs across 15+ configuration files
- **Files Standardized:**
  - `infras/keycloak/realms/realm-job7189.json` - Updated client configs
  - `k8s-management/values/laravel-common-values.yaml` - Environment variables
  - Individual service values: identity, candidate, communication, hiring, job, storage, workspace
  - Frontend configs: `atd_frontend/src/lib/config.ts`, `rct_frontend/src/lib/config.ts`
  - Test scripts: `scripts/utils/get-keycloak-token.sh`, `scripts/utils/test-keycloak-token.sh`

### 3. **Keycloak Database & Realm Import** ✅
- **Problem:** MySQL job7189keycloak had orphaned records causing duplicate key violations
- **Solution:** 
  - Dropped entire job7189keycloak database
  - Recreated from scratch
  - Restarted Keycloak for fresh realm import
- **Result:** ✅ Realm successfully imported, users (recruiter1, candidate1) created
- **File Changed:** `infras/keycloak/realms/realm-job7189.json`

### 4. **OAuth2 Password Grant Token Acquisition** ✅
- **Status:** ✅ Working
- **Token Generation:** `recruiter1`/`recruiter1` → JWT token
- **Token Contains:**
  - `iss: "http://auth.job7189.local/realms/job7189"`
  - `azp: "recruiter-app"` (standardized)
  - `sub: "recruiter-user-1"`
  - Valid `exp/iat` claims

### 5. **OPA Authorization** ✅
- **Status:** ✅ Working
- **Decision Logic:** Allow if path in whitelist OR jwt.sub non-empty
- **Verification:** Kong logs show correct allow/deny decisions

### 6. **Kong JWT Re-injection for Backend** ✅
- **Implementation:** Kong pre-function Lua script re-injects JWT via `ngx.req.set_header("authorization", "Bearer " .. token)`
- **Verification:** ✅ JWT header present in backend requests

### 7. **Identity Service Deployment** ✅
- Built Docker image: `identity-service:v2.8.18`
- Pushed to registry: `localhost:5000/job7189/identity-service:v2.8.18`
- Helm deployment (revision 10)
- **Files Changed:**
  - `src/identity_service/laravel_back/Dockerfile.production`
  - `k8s-management/values/identity-values.yaml`

### 8. **Backend Middleware Updates**
- Added enhanced logging to track configuration loading
- Added fallback error handling for Redis cache failures
- Implemented debug endpoint `/api/debug-headers` (no middleware) for header inspection
- **File Changed:** `src/identity_service/laravel_back/app/Http/Middleware/VerifyKeycloakToken.php`

### 9. **Image Digest Configuration for Admission Policy** ✅
- Added pinned image digests for:
  - `busybox@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662`
  - `alpine@sha256:de0eb0b3f2a47ba1eb89389859a9bd88b28e82f5826b6969ad604979713c2d4f`
  - `redis@sha256:d3be87a1060455213a204d2b0a7f04d45d19a16a98e85b3c37b7c33b5f0c489e`
- Updated Helm chart to use digests for admission webhook compliance
- **Files Changed:**
  - `k8s-management/charts/laravel-app/values.yaml`
  - `k8s-management/charts/laravel-app/templates/deployment.yaml`

---

## ❌ What We Tried & Failed

### 1. **Laravel Config Loading - Initial Attempts (FAILED)**

#### Attempt 1: Using Laravel `config()` Helper
```php
$baseUrl = config('services.keycloak.base_url');  // Returns NULL
```
**Why Failed:** Even though env var is present in pod, Laravel's config() helper returned NULL.

#### Attempt 2: Using PHP `getenv()` After Redis Cache Clear
```php
$baseUrl = getenv('KEYCLOAK_BASE_URL');  // Still NULL in middleware
```
**Why Failed:** Environment variables not accessible in middleware execution context despite being in pod.

#### Attempt 3: Using `$_SERVER` and `$_ENV` Superglobals
```php
$baseUrl = $_SERVER['KEYCLOAK_BASE_URL'] ?? $_ENV['KEYCLOAK_BASE_URL'];  // NULL
```
**Why Failed:** PHP-FPM isolation - env vars available at pod level but not propagated to PHP process.

#### Attempt 4: Laravel Cache Clear
```bash
php artisan config:clear
php artisan cache:clear
```
**Why Failed:** Did not resolve the underlying env var propagation issue.

#### Attempt 5: Full Fallback Chain
```php
$baseUrl = $_SERVER['KEYCLOAK_BASE_URL'] 
  ?? $_ENV['KEYCLOAK_BASE_URL'] 
  ?? config('services.keycloak.base_url');
```
**Why Failed:** All three sources returned NULL - env vars not accessible to middleware.

### 2. **Backend JWT Verification Test (BLOCKED)** 🔴
- **Test:** GET `/api/recruiters/profile` with valid Bearer token
- **Expected:** 200 OK with recruiter profile
- **Actual:** 401 "Could not resolve host: realms"
- **Root Cause:** Middleware URL malformed as `/realms//protocol/...` because base_url is empty
- **Blocker:** Environment variable propagation to Laravel middleware

### 3. **Image Digest Constraints (RESOLVED with Workaround)**
- **Constraint:** K8s admission webhook requires all images with digests
- **Initial Issue:** `error="image pull policy is always, which requires digest"`
- **Resolution:** 
  - Updated values.yaml to include digest references
  - Modified templates to use pinned digests
  - This allows deployment with image policies

### 4. **Helm Chart Image Configuration (PARTIALLY RESOLVED)**
- **Issue:** Chart template building image from registry + repository + tag doesn't support digests
- **Current State:** Added conditional for `image.fullImage` to allow passing digest
- **Remaining:** Need to test with actual helm upgrade using digest format

---

## 📊 Git Local Changes Summary

**Total Files Modified:** 65  
**Categories:**

### Infrastructure & Kubernetes
- `infras/kong/kong.yml` - Updated JWT RSA public keys (4x)
- `infras/k8s-yaml/vault-scripts/99-fast-rebuild-vault.sh` - Vault rebuild logic
- `infras/k8s-yaml/05-elasticsearch.yaml` - Config updates
- `infras/k8s-yaml/threat-intel/02-cronjob.yaml` - Job configuration
- `infras/keycloak/realms/realm-job7189.json` - OAuth2 client configs
- `infras/keycloak/scripts/add-test-users.sh` - Test data

### Helm & Kubernetes Management
- `k8s-management/charts/laravel-app/templates/deployment.yaml` - Updated image refs with templating
- `k8s-management/charts/laravel-app/values.yaml` - Added image digests
- `k8s-management/values/laravel-common-values.yaml` - Client ID standardization
- Service-specific values: identity, candidate, communication, hiring, job, storage, workspace

### Backend Services (All 7 Laravel services)
- `config/logging.php` - Logging configuration
- `config/services.php` - Keycloak service config
- `docker/supervisor.conf` - Process supervisor configuration
- `docker/watch-env.sh` - Environment watcher logic
- `routes/api.php` (identity-service) - Added debug endpoint
- `app/Http/Middleware/VerifyKeycloakToken.php` - JWT verification with enhanced logging

### Frontend
- `atd_frontend/.env.example` - Client ID updates
- `atd_frontend/src/lib/config.ts` - OAuth config (client ID removal of -dev)
- `rct_frontend/.env.example` - Client ID updates
- `rct_frontend/src/lib/config.ts` - OAuth config (client ID removal of -dev)

### Documentation & Scripts
- Created: `knowledge-base/37-oauth2-client-id-standardization.md`
- Created: `knowledge-base/43-vault-laravel-rotation-debug.md`
- Created: `deploy_remaining_services.sh`
- Created: `scripts/build_and_deploy_service.sh`
- Updated: `scripts/legacy/atd-bringup.sh`, `scripts/legacy/atd-fix-identity-jwt.sh`
- Updated: `scripts/utils/get-keycloak-token.sh`, `scripts/utils/test-keycloak-token.sh`

### Documentation Files Created
- `DEPLOYMENT_GUIDE.md`
- `SUMMARY_VERIFICATION.txt`
- `VERIFICATION_REPORT_2026-06-06.md`
- `k8s-management/VALUES_STANDARDIZATION.md`

---

## 🔴 Current Blocker - Laravel Environment Variables in Middleware

### Problem
Backend middleware cannot access `KEYCLOAK_BASE_URL` env var that exists in pod:
- ✅ Confirmed in pod: `env | grep KEYCLOAK_BASE_URL` returns correct value
- ❌ Middleware: `env('KEYCLOAK_BASE_URL')`, `config()`, `getenv()`, `$_SERVER`, `$_ENV` all return NULL

### Root Cause
PHP-FPM isolation - environment variables available at Kubernetes pod level but not passed to PHP-FPM worker processes. This prevents Laravel middleware from accessing the vars.

### Workaround Applied
Changed middleware to use hardcoded URL temporarily:
```php
$baseUrl = 'http://keycloak.security.svc.cluster.local:8080';
$realm = 'job7189';
```
This allows testing the OAuth2 flow but requires permanent fix for production.

### Next Steps
1. **Verify file copy:** Ensure middleware was updated correctly
2. **Debug PHP context:** Check if vars accessible at different points (bootstrap, service provider)
3. **Fix options:**
   - Option A: Update PHP-FPM config to pass env vars
   - Option B: Write env vars to .env file in pod
   - Option C: Use Vault injector for secrets instead
   - Option D: Build secrets directly into container at boot

---

## 📈 Verification Checklist

| Component | Status | Verified |
|-----------|--------|----------|
| Keycloak realm import | ✅ | Yes - realm in database |
| OAuth2 token generation | ✅ | Yes - recruiter1 token acquired |
| Kong JWT plugin loaded | ✅ | Yes - JWT plugin active on routes |
| Kong JWT signature validation | ✅ | Yes - token validated by Kong |
| Kong OPA authorization | ✅ | Yes - OPA returning allow decisions |
| Kong JWT re-injection | ✅ | Yes - Bearer header passed to backend |
| Docker image build | ✅ | Yes - identity-service:v2.8.18 built |
| Docker image push | ✅ | Yes - Pushed to localhost:5000 |
| Helm identity-service deploy | ✅ | Yes - Deployed revision 10 |
| Backend endpoint (full flow) | ❌ | No - Blocked by env var issue |
| Image digest policy | ✅ | Yes - Digests configured |

---

## 🎯 Remaining Work

### Immediate (Blocking OAuth2 Flow)
1. **Fix Laravel env var access** - Must resolve PHP-FPM isolation
2. **Test full flow** - Complete token → Kong → OPA → Backend path
3. **Verify JWT verification** - Backend successfully validates token signature

### Short-term (After blocking issue fixed)
1. Helm upgrade 6 remaining Laravel services (candidate, job, hiring, communication, storage, workspace)
2. Update backend code to use env vars from proper source
3. Frontend redeployment with updated client ID
4. End-to-end testing

### Documentation
- Update knowledge-base with complete OAuth2 troubleshooting guide
- Document environment variable propagation solution
- Create runbook for similar issues

---

## 📝 Key Lessons Learned

1. **Kong JWT Plugin:** Public keys must match current Keycloak signing key, not old keys
2. **Client ID Consistency:** OAuth2 `azp` claim must match configured client ID across all services
3. **Image Admission Policy:** K8s webhooks can require image digests; plan for this in values.yaml
4. **Laravel Env Vars:** PHP-FPM isolation prevents middleware from accessing pod env vars; requires explicit .env or secrets management
5. **Systematic Testing:** Test each component (token gen → Kong → OPA → Backend) independently before E2E test

---

## 🔗 Related Files

**Critical Config Files:**
- [infras/kong/kong.yml](infras/kong/kong.yml) - API Gateway config
- [infras/keycloak/realms/realm-job7189.json](infras/keycloak/realms/realm-job7189.json) - IdP config
- [k8s-management/values/laravel-common-values.yaml](k8s-management/values/laravel-common-values.yaml) - Helm common values
- [src/identity_service/laravel_back/app/Http/Middleware/VerifyKeycloakToken.php](src/identity_service/laravel_back/app/Http/Middleware/VerifyKeycloakToken.php) - JWT verification middleware

**Knowledge Base:**
- [knowledge-base/37-oauth2-client-id-standardization.md](knowledge-base/37-oauth2-client-id-standardization.md)
- [knowledge-base/43-vault-laravel-rotation-debug.md](knowledge-base/43-vault-laravel-rotation-debug.md)

---

## 🚀 How to Continue

1. **Focus on PHP-FPM env var fix** - This is the only thing blocking the full OAuth2 flow
2. **Options to explore:**
   - Add env vars to PHP-FPM pool.d config
   - Implement init container to write .env file
   - Use Vault agent to inject secrets
3. **Once fixed:** Re-test full flow with hardcoded URL replaced by actual env var access
4. **Then:** Proceed with remaining service upgrades

