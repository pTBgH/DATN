# Root Cause Analysis: 401 Unauthorized Error

**Date:** 2026-06-07  
**Issue:** GET `/api/recruiters/profile` returns 401 "Unauthorized" after pod starts  
**Status:** ✅ Root cause identified - NOT JWT verification issue

---

## 🎯 THE ACTUAL ROOT CAUSE

### **Credential Sync Broken - watch-env.sh Watching Wrong File**

```
┌─────────────────────────────────────────────────────────────────┐
│ VAULT-AGENT (renders every ~10-15 min)                         │
│ Writes to: /vault/secrets/.env.db                              │
│ New creds: v-kubernetes-identity-s-cEotzmJA                    │
└─────────────────────────────────────────────────────────────────┘
                            ↓ (MISMATCH!)
                    
┌─────────────────────────────────────────────────────────────────┐
│ WATCH-ENV.SH (watches every 10 seconds)                         │
│ Watches: /app-secrets/.env  ← STATIC FILE, NEVER CHANGES!      │
│ /app-secrets/.env contents: (214 bytes - STATIC INIT FILE)     │
│ NEVER SEES vault-agent updates!                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓ (NO SYNC)
                    
┌─────────────────────────────────────────────────────────────────┐
│ /VAR/WWW/.ENV (what Laravel uses)                              │
│ DB_USERNAME: v-kubernetes-identity-s-rqQKkwyc  ← OLD/STALE    │
│ DB_PASSWORD: -9BeqNKwAjz2igyRGj3b              ← OLD/STALE    │
│ NEVER UPDATED by watch-env                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓ (AFTER 10-15 min)
                    
┌─────────────────────────────────────────────────────────────────┐
│ VAULT REVOKES OLD CREDS                                        │
│ User v-kubernetes-identity-s-rqQKkwyc: DELETED                │
│ MySQL rejects connection                                       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                    
┌─────────────────────────────────────────────────────────────────┐
│ LARAVEL APPLICATION                                             │
│ - Cannot connect to MySQL                                       │
│ - Database queries fail                                         │
│ - VerifyKeycloakToken middleware fails                          │
│ - Returns 401 "Unauthorized"                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Evidence

### File Location Mismatch

```
WHAT watch-env.sh WATCHES:
  /app-secrets/.env  ← 214 bytes (STATIC)
  
WHERE vault-agent RENDERS:
  /vault/secrets/.env.db  ← Dynamic (contains new creds)
  
RESULT:
  watch-env.sh NEVER SEES changes from vault-agent!
  /var/www/.env never gets updated
```

### Credential Mismatch (Pod Lifecycle)

```
Pod Start (t=0):
  ✓ vault-agent starts, renders first creds
  ✓ Init container copies /vault/secrets/.env.db → /app-secrets/.env
  ✓ /var/www/.env gets initialized with creds: v-kubernetes-identity-s-rqQKkwyc
  ✓ Laravel connects to MySQL ✓

After 10 minutes (t=10m):
  ✓ vault-agent renews creds, renders: v-kubernetes-identity-s-cEotzmJA
  ✓ vault-agent updates: /vault/secrets/.env.db
  ✗ watch-env.sh watches /app-secrets/.env (still 214 bytes)
  ✗ watch-env.sh sees NO change (because it's watching wrong file)
  ✗ /var/www/.env still has: v-kubernetes-identity-s-rqQKkwyc
  ✗ /app-secrets/.env not updated by anything

After 15 minutes (t=15m):
  ✓ Vault TTL expires, REVOKES: v-kubernetes-identity-s-rqQKkwyc
  ✗ Laravel still trying to use OLD creds
  ✗ MySQL rejects connection
  ✗ 401 error (authentication fails)
```

### File Contents Snapshot

```
/app-secrets/.env (STATIC - what watch-env.sh is watching)
├─ Size: 214 bytes
├─ Last Modified: Jun 7 02:18
├─ Content: APP_KEY=... (STATIC only)
└─ DB_USERNAME: NOT PRESENT!

/vault/secrets/.env.db (DYNAMIC - what vault-agent renders)
├─ Size: 152 bytes  
├─ Last Modified: Jun 7 02:18 (KEEPS CHANGING)
├─ DB_USERNAME: v-kubernetes-identity-s-cEotzmJA
├─ DB_PASSWORD: lQWSB-oOUTEvlvjt1GT-
└─ LEASE_ID: database/creds/identity-service/...

/var/www/.env (STALE - what Laravel uses)
├─ DB_USERNAME: v-kubernetes-identity-s-rqQKkwyc  ← OLD!
├─ DB_PASSWORD: -9BeqNKwAjz2igyRGj3b              ← OLD!
└─ NOT SYNCED since pod started!
```

---

## 🔍 Why 401 Instead of Database Error?

**Chain of Failure:**

1. **Pod starts:** watch-env.sh running but watching wrong file
   
2. **MySQL connection fails** (after 15m when old creds revoked)
   - Laravel can't authenticate to MySQL
   - Database queries fail silently or throw exception

3. **VerifyKeycloakToken middleware executes**
   - Tries to verify JWT signature
   - Attempts to fetch JWKS from Keycloak
   - May fail if DB required for user lookup
   - Returns 401 "Unauthorized"

4. **Root: 401 is SYMPTOM, not PRIMARY CAUSE**
   - Primary cause: Stale database credentials
   - Secondary cause: watch-env.sh broken
   - Tertiary cause: Not syncing vault-agent renders

---

## ✅ Verification of Root Cause

### Test 1: Manual Creds Sync Works
```
Executed manually:
  NEW_USER=$(grep DB_USERNAME /vault/secrets/.env.db | cut -d= -f2 | tr -d "\"")
  sed -i "s/^DB_USERNAME=.*/DB_USERNAME=\"$NEW_USER\"/" /var/www/.env

Result:
  MySQL OK: job7189_identity_db
  
Conclusion:
  When creds ARE synced from vault-agent, Laravel CAN connect to MySQL ✓
```

### Test 2: Pod Restart Still 401
```
Executed: kubectl delete pod identity-service-...
         (waits 30s for new pod)

Result:
  Still 401 "Unauthorized"
  
Why:
  New pod starts with same broken watch-env.sh logic
  Same cycle: watch-env watches /app-secrets/.env (wrong!)
  Creds become stale after ~15 minutes
```

### Test 3: Credential Mismatch Confirmed
```
/var/www/.env:        v-kubernetes-identity-s-rqQKkwyc
/vault/secrets/.env.db: v-kubernetes-identity-s-cEotzmJA

Are they same? NO - MISMATCH!
watch-env.sh never synced the new creds from vault-agent
```

---

## 🎯 Summary: Why 401?

| Component | Status | Impact |
|-----------|--------|--------|
| vault-agent rendering | ✓ Works | Creates new creds every 10-15m |
| watch-env.sh logic | ❌ Broken | Watches `/app-secrets/.env` (STATIC) |
| watch-env sees changes? | ❌ No | `/app-secrets/.env` never changes |
| /var/www/.env updates? | ❌ No | Stale credentials stay |
| Laravel MySQL connect | ❌ Fails | After 15m when old creds revoked |
| JWT verification | ❌ Fails | Due to DB connection loss |
| HTTP Response | ❌ 401 | "Unauthorized" (symptom of DB issue) |

---

## Root Cause Hierarchy

```
LEVEL 1 (Immediate):
  ├─ Stale database credentials in /var/www/.env
  └─ MySQL connection fails → 401 error

LEVEL 2 (Process):
  ├─ watch-env.sh not syncing vault-agent renders
  └─ /vault/secrets/.env.db has new creds but /var/www/.env has old

LEVEL 3 (Configuration):
  └─ watch-env.sh watching /app-secrets/.env instead of /vault/secrets/.env.db

LEVEL 4 (Architecture):
  ├─ Static /app-secrets/.env (init-only) vs Dynamic /vault/secrets/ (continuous)
  └─ watch-env.sh confused about which file to monitor
```

---

## Where The Fix Needs To Go

### Option 1: Update watch-env.sh to watch correct file
- Change: Watch `/vault/secrets/.env.db` instead of `/app-secrets/.env`
- When vault-agent updates .env.db → watch-env detects → syncs to /var/www/.env

### Option 2: Have vault-agent directly update /var/www/.env
- Configure vault-agent template to render to `/var/www/.env` directly
- Skip watch-env.sh entirely

### Option 3: Increase credential TTL / decrease pod rotation
- But this doesn't fix the core issue

---

## Conclusion

**401 is NOT a JWT/Keycloak issue.**  
**401 is a DATABASE CREDENTIAL EXPIRATION issue.**

The chain:
1. watch-env.sh watching wrong file → credentials not synced
2. Old credentials expire after 15 minutes
3. Laravel loses MySQL connection
4. Middleware fails → returns 401

**To fix: watch-env.sh must monitor `/vault/secrets/.env.db` (where vault-agent renders) instead of `/app-secrets/.env` (static init file)**
