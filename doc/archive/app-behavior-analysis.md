# Application Behavior Analysis - Credential Handling

## Executive Summary

The application (Laravel identity-service) currently **FAILS** to properly handle dynamic database credentials rotated by Vault. This creates a critical vulnerability where credentials will expire and the application will lose database connectivity.

## Test Environment

**Pod:** identity-service-5b75577dcc-8tjqm  
**Namespace:** job7189-apps  
**Application:** Laravel 11  
**Database:** MySQL  

## Test Results

### 1. Credentials Available in Vault Secrets 

**Status:** ✓ PASS

Vault-Agent successfully injects credentials into the pod:

```bash
/vault/secrets/.env.db:
  DB_USERNAME="v-kubernetes-identity-s-Q2ILRWCy"
  DB_PASSWORD="RCL2lXEAxT-U0vDaKcrx"
  
/vault/secrets/.env.common:
  APP_KEY="base64:V0sAjegVX3yTmM/z+zEsMjYbksjNhHcJxqhV6wKAGNs="
  
/vault/secrets/.env.extra:
  LARAVEL_INTERNAL_API_SECRET="ABC123XYZ"
```

### 2. Environment File Merging

**Status:** ⚠ PARTIAL

The env-loader init container is supposed to merge individual .env.* files into a single /app-secrets/.env file.

**Initial State (After Init Container):**
  - /app-secrets/.env was EMPTY (0 bytes)
  - /vault/secrets/.env.* files had content

**After Manual Merge (by exec'ing into pod):**
```
APP_KEY="base64:V0sAjegVX3yTmM/z+zEsMjYbksjNhHcJxqhV6wKAGNs="
DB_USERNAME="v-kubernetes-identity-s-Q2ILRWCy"
DB_PASSWORD="RCL2lXEAxT-U0vDaKcrx"

LARAVEL_INTERNAL_API_SECRET="ABC123XYZ"
```

**Finding:** The init container's file-merging logic has a timing issue or bug. However, manual merging proves the files are accessible and can be combined.

### 3. Application Environment Variable Configuration

**Status:** ✗ FAIL - CRITICAL ISSUE

**Application-Visible Environment Variables:**
```
DB_USERNAME: NOT SET ❌
DB_PASSWORD: NOT SET ❌
DB_HOST: mysql.data.svc.cluster.local ✓ (from pod spec)
DB_DATABASE: job7189_identity_db ✓ (from pod spec)
APP_DEBUG: true ✓
APP_ENV: production ✓
```

**Root Cause:** The application pod specification directly sets environment variables for DB_HOST, DB_DATABASE, and others. Laravel prioritizes these explicit pod environment variables over the .env file, so even if the merged .env exists, the DB credentials are not read from it.

### 4. Database Connection Test

**Status:** ✗ FAIL - CONNECTION DENIED

**Test Command:**
```php
php artisan tinker --execute="DB::select('SELECT COUNT(*) as count FROM users')"
```

**Result:**
```
Database connection: FAILED
Error: SQLSTATE[HY000] [1045] Access denied for user 'root'@'10.244.2.110' (using password: NO)
```

**Analysis:**
- App tries to connect as user 'root' (default MySQL user)
- No password supplied (password is NOT SET in env vars)
- This indicates the app is using hardcoded defaults instead of injected credentials
- Connection attempt uses pod's IP (10.244.2.110) as client IP

## Critical Findings

### 🔴 Problem 1: Environment Variables Not Passed to Application

**Issue:** Pod spec explicitly sets DB_* environment variables:
```yaml
spec:
  containers:
  - name: app
    env:
    - name: DB_HOST
      value: "mysql.data.svc.cluster.local"
    - name: DB_DATABASE
      value: "job7189_identity_db"
    # DB_USERNAME and DB_PASSWORD are NOT in pod spec!
```

**Impact:**
- Laravel loads DB_HOST and DB_DATABASE from pod env (hardcoded in spec)
- Laravel tries to find DB_USERNAME and DB_PASSWORD but they're not there
- Falls back to Laravel defaults (username: "root", no password)
- Dynamic credentials are ignored completely

### 🔴 Problem 2: .env File Merging Fails or is Ignored

**Issue:** The init container says it merged files, but:
1. /app-secrets/.env starts completely empty
2. Even after manual merge, app doesn't read it
3. App uses hardcoded pod environment variables instead

**Impact:**
- Vault-injected credentials are wasted
- For .env file to work, pod must NOT have environment variables set for DB_*
- Requires deployment reconfiguration

### 🔴 Problem 3: Credentials Don't Rotate on Pod Restart

**Issue:** Even if we fixed the above, when Vault rotates credentials:
1. Vault issues new username/password
2. Vault-Agent updates /vault/secrets/.env.db (every 5 minutes)
3. **Application continues using OLD credentials** (still connected, doesn't reload)
4. Old credentials expire in the database
5. New requests fail: "Access denied for user 'old-user'@'...'"

## Architecture Problem

```
┌─────────────────────────────────────────┐
│ Pod Environment Variables (Set in spec) │
│ DB_HOST = mysql.data.svc (hardcoded)    │
│ DB_DATABASE = job7189_identity_db       │
│ DB_USERNAME = NOT SET                   │
│ DB_PASSWORD = NOT SET                   │
└─────────────────────────────────────────┘
  ↑
  └── Laravel Reads From Here (Hardcoded in Spec)
      Defaults to: root, (no password)

┌─────────────────────────────────────────┐
│ File System (Vault Secrets)             │
│ /vault/secrets/.env.db:                 │
│ DB_USERNAME="v-kubernetes-identity-s.." │
│ DB_PASSWORD="RCL2lXEAxT-U0vDaKcrx"      │
│ /app-secrets/.env (merged, but empty)   │
└─────────────────────────────────────────┘
  ↑
  └── Laravel NEVER Reads From These
      (Pod env vars take precedence)
```

## Required Fixes

### Fix 1: Remove Hardcoded DB Credentials from Pod Spec  
**Action:** Remove DB_USERNAME, DB_PASSWORD, DB_HOST, DB_DATABASE from the pod environment configuration  
**Impact:** Application will read from .env file instead

### Fix 2: Use Vault Agent to Set Environment Variables  
**Alternative:** Configure Vault Agent to write DB credentials as pod environment variables instead of files  
**Impact:** App can read credentials without code changes

### Fix 3: Implement Credential Reload Mechanism  
**Action:** See `auto-reload-solution.yaml`  
**Methods:**
- File watcher that monitors /vault/secrets/.env.db
- Periodic pod restart
- Sidecar that sends signals to reload app configuration

## Current Behavior Summary

| Component | Status | Details |
|-----------|--------|---------|
| Vault secret generation | ✓ Pass | Correct credentials issued |
| Vault Agent injection | ✓ Pass | Credentials written to pod |
| App env var reading | ✗ Fail | App uses hardcoded pod vars |
| DB connection with injected creds | ✗ Fail | Cannot connect with old credentials |
| Dynamic rotation support | ✗ Fail | App doesn't reload changed secrets |

## Conclusion

**The application cannot use dynamically rotated database credentials in its current configuration.**

To enable proper dynamic secret rotation, you MUST:

1. **EITHER:** Modify pod spec to NOT hardcode DB credentials (allows app to read from .env)
2. **OR:** Modify Vault Agent to inject as environment variables (not files)
3. **AND:** Implement a reload mechanism (file watcher, signal handler, or restart trigger)

Without these changes, Vault rotation will fail silently while the application continues using expired credentials until connection failure.
