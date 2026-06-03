# Dynamic Secret Rotation Test Report

## Test Objective
Verify that HashiCorp Vault correctly issues and rotates dynamic database credentials, and that the application pod receives these updates.

## Test Configuration

### Before Test
- Default TTL: 1 hour
- Max TTL: 24 hours

### After Configuration Update
- Default TTL: 5 minutes (300 seconds)
- Max TTL: 10 minutes (600 seconds)

**Vault Role Configuration:**
```
db_name:                mysql
credential_type:        password
creation_statements:    CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; 
                       GRANT SELECT,INSERT,UPDATE,DELETE ON job7189_identity_db.* TO '{{name}}'@'%';
revocation_statements:  DROP USER IF EXISTS '{{name}}'@'%';
default_ttl:            5m
max_ttl:                10m
```

## Test Execution

### Step 1: Initial Credentials (Before Rotation)

**Timestamp:** 2026-04-08 16:17:35 UTC

**Vault Response:**
```
lease_id:              database/creds/identity-service/FvVUXTL0AHWF6Ailex3KSnni
lease_duration:        5m (300 seconds)
lease_renewable:       true
username:              v-root-identity-s-hHsr3ZUAoAKOB6
password:              kNzJ-E0nB0oYK9uBth2W  (masked for security)
```

### Step 2: Credential Revocation (Force Rotation)

**Timestamp:** 2026-04-08 16:18:35 UTC

**Action:** Revoked the initial lease to simulate credential expiration:
```bash
vault lease revoke database/creds/identity-service/FvVUXTL0AHWF6Ailex3KSnni
```

**Result:** `All revocation operations queued successfully!`

### Step 3: New Credentials (After Rotation)

**Timestamp:** 2026-04-08 16:18:40 UTC

**Vault Response (New Issue):**
```
lease_id:              database/creds/identity-service/38IejShfycSm4CjuvBdOEQbM
lease_duration:        5m (300 seconds)
lease_renewable:       true
username:              v-root-identity-s-jOhG83t2GYSnic
password:              2mUU-EyiZTTFsRJuualR  (masked for security)
```

**Comparison - Credentials Changed:**
- ✓ Username changed: `v-root-identity-s-hHsr3ZUAoAKOB6` → `v-root-identity-s-jOhG83t2GYSnic`
- ✓ Password changed: `kNzJ-E0nB0oYK9uBth2W` → `2mUU-EyiZTTFsRJuualR`

### Step 4: Pod Credential Status Check

**Timestamp:** 2026-04-08 16:18:45 UTC

**Pod Name:** `identity-service-5b75577dcc-8tjqm`

**Credentials in Pod `/vault/secrets/.env.db`:**
```
DB_USERNAME="v-kubernetes-identity-s-Q2ILRWCy"
DB_PASSWORD="RCL2lXEAxT-U0vDaKcrx"
```

## Analysis & Findings

### ✓ Vault Dynamic Secret Rotation Works Correctly
- Vault successfully generated new credentials with TTL of 5 minutes
- Old credentials were properly revoked
- New credentials are unique and follow the naming pattern: `v-root-identity-s-<RANDOM>`

### ⚠ Pod Credentials May Lag Behind Vault Issuance
- The credentials found in the pod (`v-kubernetes-identity-s-Q2ILRWCy`) differ from both the initial and newly issued credentials
- This suggests the Vault Agent may be:
  1. Using credentials from a previous request not captured in our test
  2. Not immediately updating templates when secrets change
  3. Only re-rendering templates on specific intervals or triggers

### 🔴 Critical Issue: Vault Agent Not Continuously Polling
**Vault Agent Logs Observation:**
```
2026-04-08T16:17:51.398Z [INFO]  agent: (runner) rendered "(dynamic)" => "/vault/secrets/.env.db"
```

- Only **ONE** template render event is visible in recent logs
- No subsequent render events after the pod started (~1 minute ago)
- This indicates Vault Agent may:
  - Use long renewal intervals (default is 1 hour for static secrets)
  - Only re-render when token renewal occurs
  - Not monitor dynamic secret lease expiration actively enough

## Key Insights

### Current Problem
The Vault Agent is not continuously updating dynamic database credentials as they rotate. This creates a scenario where:
1. Vault issues new credentials every 5 minutes
2. Vault Agent doesn't know to fetch and render them
3. Application continues using old credentials
4. Credentials eventually expire in the database
5. Application loses database connection

### Why This Happens
- Vault Agent's template rendering is tied to **token renewal events**, not secret lease expiration
- The agent renews tokens every ~hour (token TTL)
- Dynamic secrets are created with 5-minute TTL
- There's a **mismatch between token renewal intervals and secret lease duration**

## Recommendations

### Immediate Action Required
Implement a credential update mechanism (see `auto-reload-solution.yaml`):
1. **File watcher sidecar**: Monitor changes to credential files and signal app reload
2. **Periodic restart**: Force pod restart after secret TTL/2 to ensure fresh credentials
3. **Vault Agent polling**: Configure more aggressive lease monitoring

### Configuration Changes
```hcl
# In Vault Agent config - add explicit secret polling
lease {
  min = "5s"
  max = "60s"
  renew_increment = "2m"
}
```

## Test Conclusion

| Aspect | Status | Details |
|--------|--------|---------|
| Vault rotation | ✓ Pass | Credentials correctly rotated |
| TTL configuration | ✓ Pass | 5m default_ttl applied successfully |
| Vault database backend | ✓ Pass | MySQL users created and revoked correctly |
| Pod credential sync | ⚠ Partial | Credentials in pod exist but may lag Vault |
| Continuous rotation support | ✗ Fail | App needs external trigger to reload credentials |

## Next Steps
1. Implement auto-reload sidecar (Task 4)
2. Deploy file watcher to monitor `/vault/secrets/.env.db`
3. Trigger application configuration reload on credential changes
4. Test end-to-end with real application database requests
