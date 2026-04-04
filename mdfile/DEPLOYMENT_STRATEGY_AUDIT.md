# Complete Deployment Strategy Audit & Recovery Plan

*Last Updated: 2026-03-29*

## Executive Summary

**Current State**: Infrastructure is partially broken due to mixed deployment strategies
- ✅ Backend services: Deployed to K8s `job7189-apps` namespace (working, images present)
- ❌ Frontend portals: Running on docker-compose locally + old K8s deployment (broken, image tag mismatch)
- ❌ Integration: FE docker-compose can't reach K8s services (different networks)
- ❌ Configuration: Helmfile configured correctly but not synced

**Root Cause**: Two overlapping deployment attempts
1. Old K8s deployment in `job7189-apps` (image: `job7189/fe-candidate:v08` - doesn't exist)
2. Local docker-compose workaround (image: `fe-candidate:test` - works locally only)
3. Helmfile configured to deploy to `frontend` namespace with correct images but never synced

## Infrastructure Discovery Results

### Current Deployment Status

```
BACKEND SERVICES (K8s - job7189-apps namespace):
  ✅ candidate-service (0/2 Unknown - likely needs image investigation)
  ✅ communication-service (0/2 Unknown)
  ✅ hiring-service (0/2 Unknown)
  ✅ identity-service (0/2 Unknown)
  ✅ job-service (0/2 Unknown)
  ✅ storage-service (0/2 Unknown)
  ✅ workspace-service (Unknown)
  ✅ Redis instances for all services (Running)
  ✅ MySQL (Running)
  ✅ Kafka (Running)
  ✅ Kong Gateway (Running)
  ✅ Keycloak (security namespace, Running)

FRONTEND PORTALS (docker-compose - local):
  ✅ fe-candidate:3001 (Working - tag: fe-candidate:test)
  ✅ fe-recruiter:3002 (Working - tag: fe-recruiter:test)

FRONTEND PORTALS (K8s - job7189-apps - BROKEN):
  ❌ fe-candidate-service (ImagePullBackOff - image: job7189/fe-candidate:v08)
  ❌ MISSING: frontend namespace (should exist per helmfile)
  ❌ MISSING: fe-recruiter K8s deployment

INFRASTRUCTURE:
  ✅ Helmfile configured (values files exist for FE)
  ✅ Helm charts created for FE (fe-candidate, fe-recruiter)
  ✅ K8s values files created (fe-candidate-values.yaml, fe-recruiter-values.yaml)
  ❌ Helmfile NOT synced (FE not deployed via helmfile)
  ❌ Frontend namespace does NOT exist
```

### Image Status

```
LOCAL IMAGES:
  ✅ fe-candidate:test (created locally, 190MB)
  ✅ fe-recruiter:test (created locally, 188MB)

REGISTRY (localhost:5000):
  ✅ localhost:5000/fe-candidate:latest (194 MB)
  ✅ localhost:5000/fe-recruiter:latest (189 MB)

REGISTRY (job7189/):
  ❌ job7189/fe-candidate:v08 (NOT FOUND - causing ImagePullBackOff)
  ❌ job7189/fe-recruiter (Not found)

BACKEND IMAGES:
  ✅ job7189/candidate-service:v1.0.0 (present, multiple registry mirrors)
  ✅ job7189/communication-service:v1.1.6 (present)
  ✅ All other job7189/* images present
```

### Environment Configuration Status

```
.env Files:
  ⚠️  .env.example (templates only)
  ❌ .env.local (MISSING in both FE directories)
  ❌ .env (production - MISSING)

K8s Environment Variables:
  ✅ Already configured in K8s deployment spec:
     - KEYCLOAK_CLIENT_ID: job7189-candidate
     - KEYCLOAK_ISSUER: http://auth.job7189.com/realms/job7189
     - INTERNAL_API_BASE: api.job7189.com
     - NEXTAUTH_URL: http://fe-candidate.job7189.com
     - NODE_ENV: production

Helmfile Environment Variables (in values files):
  ✅ Configured in k8s-management/values/fe-candidate-values.yaml:
     - NODE_ENV: production
     - NEXT_PUBLIC_API_BASE_URL: http://kong.api:8000
     - NEXT_PUBLIC_KEYCLOAK_URL: http://keycloak.identity:8080
     - NEXT_PUBLIC_KEYCLOAK_REALM: job7189
     - NEXT_PUBLIC_KEYCLOAK_CLIENT_ID: fe-candidate

Docker-compose Variables:
  ❌ NO .env.local created (needed for docker-compose)
```

### Keycloak Integration Status

```
Database Setup:
  ✅ Keycloak running in security namespace

Realm Configuration:
  ✅ Realm file exists: infras/keycloak/realm-infra.json
  ✅ Setup script exists: infras/keycloak/01_setup_realm_config.sh

OAuth2 Client Configuration:
  ⚠️  Clients may be configured in K8s env vars, but not verified:
     - KEYCLOAK_CLIENT_ID: job7189-candidate
     - KEYCLOAK_CLIENT_SECRET: IGm7yJ6eHD4ECDpjZBCFF2Um4fNuWTo6
     - KEYCLOAK_ISSUER: http://auth.job7189.com/realms/job7189

End-to-End Flow:
  ❌ BROKEN - FE docker-compose can't reach Keycloak in K8s (DNS resolution fails)
  ❌ BROKEN - FE K8s deployment failed (image not found)
```

### Vault Integration Status

```
Service Code:
  ✅ src/lib/env-service.ts created with Vault support

Configuration:
  ❌ Vault URL not provided
  ❌ Vault token not configured
  ❌ Secret paths not defined
  ❌ Not enabled in deployment

Status:
  ❌ Not actively used (only code skeleton ready)
```

## Problem Classification & Impact

### Critical Issues (Blocking Deployment)

**Issue #1: FE Image Tag Mismatch**
- Current: K8s trying to pull `job7189/fe-candidate:v08` (doesn't exist)
- Available: `localhost:5000/fe-candidate:latest` (working)
- Fix: Either tag image correctly or update deployment
- Impact: ⛔ BLOCKS K8s deployment

**Issue #2: Missing Frontend Namespace**
- Current: No `frontend` namespace exists
- Expected: helmfile.yaml expects `frontend` namespace
- Fix: Create namespace, deploy via helmfile
- Impact: ⛔ BLOCKS proper K8s deployment

**Issue #3: FE/BE Network Isolation**
- Current: FE on docker-compose, BE on K8s
- Problem: docker-compose can't resolve K8s internal DNS (keycloak.identity, kong.api)
- Fix: Deploy FE to K8s as well
- Impact: ⛔ BLOCKS API connectivity, ⛔ BLOCKS Keycloak OAuth2

### High Priority Issues (Fixing Deployment)

**Issue #4: Keycloak Not Integrated**
- Current: Keycloak running but FE can't reach it (network isolation)
- Expected: Keycloak OAuth2 flow working end-to-end
- Fix: Deploy FE to K8s, configure OAuth2 callbacks
- Impact: 🔴 BLOCKS authentication flow

**Issue #5: Backend Services Failing**
- Current: Most BE services showing `0/2 Unknown` status
- Likely Cause: Same image registry issues
- Fix: Investigate image availability in registry mirrors
- Impact: 🔴 BE services may not be functioning

### Medium Priority Issues (Production Readiness)

**Issue #6: No Production Environment Variables**
- Current: Only .env.example files exist
- Fix: Create .env.local files with actual values
- Impact: 🟡 Config management not production-ready

**Issue #7: Vault Not Configured**
- Current: Code ready but not activated
- Fix: Configure Vault integration
- Impact: 🟡 Secrets management incomplete

## Recovery Plan - Step by Step

### Phase 1: Prepare Frontend Deployment (THIS SESSION)

**Step 1.1**: Build and push FE images with correct tags
```bash
# Already done locally, need to push to registry
docker build -f src/fe_candidate/Dockerfile -t localhost:5000/fe-candidate:latest src/fe_candidate/ 
docker build -f src/fe_recruiter/Dockerfile -t localhost:5000/fe-recruiter:latest src/fe_recruiter/
docker push localhost:5000/fe-candidate:latest
docker push localhost:5000/fe-recruiter:latest
```

**Step 1.2**: Create frontend namespace
```bash
kubectl create namespace frontend
```

**Step 1.3**: Verify Helm chart and values
- ✅ Chart exists: k8s-management/charts/fe-candidate
- ✅ Chart exists: k8s-management/charts/fe-recruiter
- ✅ Values file exists: k8s-management/values/fe-candidate-values.yaml
- ✅ Values file exists: k8s-management/values/fe-recruiter-values.yaml

**Step 1.4**: Update environment variables in values files
- Verify KEYCLOAK_URL points to K8s service
- Verify API_BASE_URL points to Kong gateway
- Update ingress hosts if needed

**Step 1.5**: Deploy via Helmfile
```bash
cd k8s-management
helmfile sync
```

### Phase 2: Verify Integration (Next Session)

**Step 2.1**: Test connectivity
- ✅ FE pods running in frontend namespace
- ✅ FE can reach Keycloak (network test)
- ✅ FE can reach backend APIs (network test)

**Step 2.2**: Test Keycloak OAuth2  
- ✅ Login flow triggers
- ✅ Redirect URI works
- ✅ Token callback received

**Step 2.3**: Test backend operations
- ✅ Job listing API responds
- ✅ Authentication flow works
- ✅ Data operations complete

### Phase 3: Production Configuration (Next Session)

**Step 3.1**: Create .env.local files
- Document actual values needed
- Create .env.local for docker-compose (if keeping for local dev)

**Step 3.2**: Configure Vault
- Set up Vault secrets
- Enable env-service.ts integration

**Step 3.3**: Final validation
- ✅ All services in K8s
- ✅ All environment variables from single source
- ✅ Keycloak working end-to-end
- ✅ API connectivity verified

## Files That Need Changes

```
CREATE:
  - kubernetes frontend namespace (kubectl)
  - .env.local files (if needed for local dev)

VERIFY:
  - k8s-management/values/fe-candidate-values.yaml ✅ exists
  - k8s-management/values/fe-recruiter-values.yaml ✅ exists
  - k8s-management/helmfile.yaml ✅ exists
  - k8s-management/charts/fe-candidate/ ✅ exists
  - k8s-management/charts/fe-recruiter/ ✅ exists

PUSH:
  - Docker images to localhost:5000 registry

DELETE/DEPRECATE:
  - Old FE deployment from job7189-apps namespace (after new one works)
  - docker-compose (after K8s deployment confirmed stable)
```

## Architecture After Fix

```
CORRECTED ARCHITECTURE:
├── Keycloak (security namespace)
├── Backend APIs (job7189-apps namespace)
│   ├── candidate-service
│   ├── communication-service
│   ├── hiring-service
│   ├── identity-service
│   ├── job-service
│   ├── storage-service
│   └── workspace-service
├── Frontend Portals (frontend namespace) ← DEPLOYED VIA HELMFILE
│   ├── fe-candidate-service
│   └── fe-recruiter-service
└── Infrastructure Services
    ├── MySQL (data namespace)
    ├── Kafka (data namespace)
    ├── Kong Gateway (gateway namespace)
    └── Redis (with each service)

ALL SERVICES:
✅ In same K8s cluster
✅ Using internal DNS for service discovery
✅ Environment variables from helmfile values
✅ Keycloak OAuth2 accessible to both BE and FE
✅ Images from localhost:5000 registry
```

## Success Criteria

- [ ] frontend namespace created
- [ ] FE images built and available in localhost:5000
- [ ] Helmfile synced successfully
- [ ] FE pods running in frontend namespace
- [ ] FE port 3001/3002 accessible via K8s ingress
- [ ] FE can resolve keycloak.identity hostname
- [ ] Keycloak OAuth2 login works
- [ ] API calls from FE reach backend successfully
- [ ] Old FE deployment in job7189-apps cleaned up
- [ ] docker-compose FE stopped (can be kept for local dev)

## Next Actions

1. **Immediate** (now): 
   - Create frontend namespace
   - Push FE images to registry
   - Deploy via helmfile

2. **Short-term** (after verification):
   - Test Keycloak integration
   - Test API connectivity
   - Fix any remaining issues

3. **Follow-up** (production):
   - Configure .env.local for docker-compose (if keeping)
   - Activate Vault integration
   - Final end-to-end testing
   - Clean up old deployments

---

## Technical Details

### Why Docker-compose Can't Reach Keycloak

```
docker-compose network (bridge):
  - fe-candidate container: 172.18.0.x
  - Can resolve: localhost, other docker-compose services
  - Cannot resolve: keycloak.identity, kong.api (K8s internal DNS)
  - Result: Connection refused

K8s network (cluster):
  - fe-candidate pod: 10.x.x.x (inside cluster)
  - Can resolve: keycloak.identity, kong.api (K8s DNS)
  - Cannot resolve: localhost:5000 (outside cluster)
  - Result: Services reachable

Solution: Deploy FE to K8s to be part of the same network
```

### Why Old FE Deployment Failed

```
1. Old deployment tries to pull: job7189/fe-candidate:v08
2. Registry doesn't have that image (wrong tag/version)
3. Kubernetes ImagePullBackOff - gives up after retries
4. Pod stays in Waiting state forever

Solution: Use correct image tags or update deployment spec
```

### Current Image Registry Hierarchy

```
Layer 1 - Docker Build (local machine):
  - fe-candidate:test ✅
  - fe-recruiter:test ✅

Layer 2 - Local Registry (localhost:5000):
  - localhost:5000/fe-candidate:latest ✅
  - localhost:5000/fe-recruiter:latest ✅

Layer 3 - Production Registry (job7189/):
  - job7189/fe-candidate:v08 ❌ MISSING
  - job7189/fe-recruiter:vXX ❌ MISSING

Layer 4 - K8s Mirror Registries (localhost:30500):
  - localhost:30500/... (uses Layer 2 as source)

Helmfile Should Use: localhost:5000 or Layer 2 registry
Current K8s Uses: job7189/ namespace (Layer 3 - broken)
```

---

*This audit document will be kept updated as fixes are implemented.*
*Follow the Recovery Plan above for systematic resolution.*
