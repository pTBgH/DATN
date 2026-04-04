# 🔍 Backend Connectivity & Issue Debugging

## Current Status

### ✅ Recruiter Portal (Port 3002)
- **Status**: FIXED - No more 404 errors!
- **Fix Applied**: Moved `router.push()` into `useEffect` hook instead of render
- **Access**: http://localhost:3002

### 🔄 Candidate Portal (Port 3001)  
- **Status**: Loading (shows login) - needs auth hydration
- **Issue**: Auth store not hydrated with saved session on page load
- **Solution**: Need to implement persistent session or guest mode

---

## Issue 1: Candidate Portal Shows Login Instead of Jobs

**Why it happens**:
```
1. isAuthenticated = false (initial state)
2. Browser loads → Auth store hydrates from cookie
3. But page already rendered as login screen
4. Auth hydration happens after render
```

**Solution Options**:

### Option A: Show Jobs Without Login (Recommended)
```tsx
// Remove auth check from home page
// Allow public access to job listings
// Only require auth for: Apply, Profile, Dashboard
```

### Option B: Wait for Hydration
```tsx
// Show loading state while hydrating
// Then show jobs if auth exists
```

---

## Issue 2: Backend Connectivity

**Check if backend is responding**:

```bash
# Test Kong API Gateway
curl http://kong.api:8000/health

# Test Job service directly
curl http://localhost:8000/jobs

# Check environment variables in container
docker exec fe-candidate env | grep -i api

# View container logs
docker logs fe-candidate
docker logs fe-recruiter
```

---

## Environment Configuration with HashiCorp Vault

### Setup Vault for Frontend (If needed)

```bash
# Set environment variables for Vault
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=your-token
export NEXT_PUBLIC_VAULT_URI=http://localhost:8200
export NEXT_PUBLIC_VAULT_SECRET_PATH=secret/data/job7189/frontend

# Vault secret structure:
# secret/data/job7189/frontend
# ├── API_BASE_URL: http://kong:8000
# ├── KEYCLOAK_URL: http://keycloak:8080
# ├── KEYCLOAK_REALM: job7189
# └── KEYCLOAK_CLIENT_ID: fe-candidate
```

### Update docker-compose.yml for Vault

```yaml
environment:
  - VAULT_ADDR=http://vault:8200
  - VAULT_TOKEN=${VAULT_TOKEN}
  - NEXT_PUBLIC_VAULT_URI=http://vault:8200
  - NEXT_PUBLIC_VAULT_SECRET_PATH=secret/data/job7189/frontend
```

---

## Testing Backend Connectivity

### From Container Console

```bash
docker exec fe-candidate npm run test:connectivity
```

### Manually in Browser Console

```javascript
// Test API connectivity
fetch('http://localhost:8000/health')
  .then(r => r.json())
  .then(d => console.log('✅ Backend healthy:', d))
  .catch(e => console.error('❌ Backend error:', e))

// Test jobs endpoint
fetch('http://localhost:8000/jobs')
  .then(r => r.json())
  .then(d => console.log('✅ Jobs:', d))
  .catch(e => console.error('❌ Jobs error:', e))
```

---

## Keycloak Configuration Check

```bash
# Check Keycloak is running
curl http://localhost:8080/health/ready

# Check realm exists
curl http://localhost:8080/admin/realms/job7189

# Keycloak OAuth2 Discovery
curl http://localhost:8080/realms/job7189/.well-known/openid-configuration
```

---

## Frontend API Logging

All requests/responses are logged to browser console:

```
[API] Request: GET http://localhost:8000/jobs
[API] Response: 200 http://localhost:8000/jobs
[API] 404 Not Found - /jobs
```

**Check browser DevTools → Console** for detailed logs.

---

## Fix the Candidate Portal NOW

The simplest fix - make home page accessible without login:

```tsx
// src/fe_candidate/src/app/page.tsx

// BEFORE: Requires login to see jobs
if (!isAuthenticated) {
  return <LoginPage />;
}

// AFTER: Show jobs to everyone
// Jobs are public, auth only for Apply button
return <JobListings />;
```

---

## Quick Diagnostics Script

Run this in browser console while on http://localhost:3001:

```javascript
// Check auth state
console.log('Auth Store:', useAuthStore.getState());

// Check local storage
console.log('Cookies:', document.cookie);

// Test API
fetch('http://localhost:8000/jobs')
  .then(r => r.json())
  .then(d => console.log('✅ API works:', d.length, 'jobs'))
  .catch(e => console.error('❌ API failed:', e));
```

---

## Environment Files Location

```
src/fe_candidate/.env.example
src/fe_candidate/.env.local

src/fe_recruiter/.env.example
src/fe_recruiter/.env.local

k8s-management/values/fe-candidate-values.yaml
k8s-management/values/fe-recruiter-values.yaml
```

---

## Next Steps

1. **Quick Fix** (recommended):
   - Allow public job listing access
   - Only auth for Apply, Profile, Favorites

2. **Backend Check**:
   - Verify Kong is running: `curl http://localhost:8000/health`
   - Verify jobs endpoint: `curl http://localhost:8000/jobs`

3. **Vault Setup**:
   - Configure if using Vault for secrets
   - Or use environment variables directly

4. **Check Logs**:
   - Browser console: API logs
   - Container logs: `docker logs fe-candidate`
   - Backend logs: Depends on your backend setup

---

## Commands to Help Debug

```bash
# Restart and see logs
docker-compose -f docker-compose.frontends.yml down
docker-compose -f docker-compose.frontends.yml up -d

# Watch logs real-time
docker logs -f fe-candidate
docker logs -f fe-recruiter

# Check environment in containers
docker exec fe-candidate env | grep -E "(API|KEYCLOAK|NODE_ENV)"

# Test from inside container
docker exec fe-candidate curl http://localhost:8000/jobs

# Rebuild without cache
docker-compose -f docker-compose.frontends.yml up --build --no-cache -d
```

---

**Status Summary**:
- ✅ Recruiter portal fixed (routing issue resolved)
- 🔄 Candidate portal needs auth handling refactor
- 🔧 API client has logging for debugging
- 📝 Environment/Vault setup ready for production

Next: Implement guest/public job access for candidate portal!
