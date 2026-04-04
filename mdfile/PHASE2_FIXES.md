# Phase 2 (Infrastructure) - Fixes & Improvements

## Issues Fixed

### 1. **Keycloak realm-infra.json not imported** ❌→✅

**Problem**: 
- Dockerfile was missing `COPY realm-infra.json`
- Deployment had volumeMount expecting ConfigMap that wasn't created
- Keycloak couldn't load realm configuration

**Solution**:
- ✅ Added `COPY ./realm-infra.json /opt/keycloak/data/import/realm-infra.json` to Dockerfile
- ✅ Added `RUN mkdir -p /opt/keycloak/data/import` to ensure directory exists
- ✅ Removed volumeMount from deployment (file now in image)
- ✅ Keycloak will find and auto-import realm via `--import-realm` flag

**File**: `infras/keycloak/Dockerfile`

---

### 2. **Keycloak and oauth2-proxy pods never reached "Ready" state** ❌→✅

**Problem**:
- Phase 2 just deployed them and continued without waiting
- No verification that they actually started
- Subsequent phases failed because Keycloak wasn't ready

**Solution**:
- ✅ Added `kubectl wait --for=condition=Ready=True pod` with 300s timeout for Keycloak
- ✅ Added proper wait logic for Kafka (240s) and Kong (240s)
- ✅ Added comprehensive pod status checks at end of Phase 2
- ✅ Each service now waits for actual Ready condition before continuing

**Files**: `02-deploy-infrastructure.sh`

---

### 3. **oauth2-proxy wasn't being deployed** ❌→✅

**Problem**:
- oauth2-proxy YAML was in `ingress/04_oauth2_proxy.yaml` but not called in Phase 2
- Ingress depends on oauth2-proxy being available
- oauth2-proxy needs Keycloak IP for hostname aliasing

**Solution**:
- ✅ Created `infras/k8s-yaml/ingress/00_setup_oauth2_proxy.sh` setup script
- ✅ Script dynamically fetches Keycloak service IP and patches deployment
- ✅ Added oauth2-proxy deployment to Phase 2 (Step 2, after Keycloak ready)
- ✅ Waits for oauth2-proxy pods to be Ready before continuing

**Files**: 
- Created: `infras/k8s-yaml/ingress/00_setup_oauth2_proxy.sh`
- Modified: `02-deploy-infrastructure.sh`

---

### 4. **Kong ConfigMap wasn't being created** ❌→✅

**Already fixed previously** ✅

---

### 5. **kubectl wait condition was incorrect in all scripts** ❌→✅

**Already fixed previously** ✅
- Changed from `--for=condition=ready` (wrong - checks if key exists)
- To `--for=condition=Ready=True` (correct - checks actual Ready status)

**Files**: `01-setup-cluster.sh`, `02-deploy-infrastructure.sh`

---

## Phase 2 Now Includes (in order):

### Step 1: Base Infrastructure
1. 00-setup.yaml
2. MySQL + phpMyAdmin (with wait)
3. Keycloak (build image → load to Kind → deploy → WAIT)
4. Kafka (deploy → WAIT)
5. Kong (setup ConfigMap → deploy → WAIT)

### Step 2: Authentication (NEW)
1. oauth2-proxy (setup script → deploy → WAIT)

### Step 3: Certificate Management
1. Cert-Manager Issuer

### Step 4: Vault Infrastructure
1. Vault deployment

### Step 5: Vault Configuration Scripts
1. 01_setup_vault_dev.sh
2. 02_init_vault_prod.sh
3. 03_setup_vault_prod.sh
4. 04_push_static_secrets.sh
5. 05_setup_dynamic_db.sh
6. 06_setup_policies.sh
7. 07_install_injector.sh

### Step 6: Comprehensive Validation (NEW)
1. Check Keycloak pods status
2. Check oauth2-proxy pods status
3. Check Kafka pods status
4. Check Kong pods status
5. Check Vault pods status
6. Check MySQL pods status
7. Check Certificate Issuers
8. Display pod counts and status

---

## New Files Created

1. **`infras/keycloak/01_setup_realm_config.sh`** (optional, not used anymore)
   - Creates ConfigMap from realm-infra.json
   - Kept for future use if dynamic realm updates needed

2. **`infras/kong/01_setup_kong_config.sh`** ✅
   - Creates ConfigMap from kong.yml before Kong deployment

3. **`infras/k8s-yaml/ingress/00_setup_oauth2_proxy.sh`** ✅
   - Fetches Keycloak IP dynamically
   - Applies oauth2-proxy YAML with updated hostAliases
   - Ensures Keycloak hostname resolves correctly

---

## Test Commands

```bash
# Phase 1: Cluster setup (should complete in ~6 minutes)
bash 01-setup-cluster.sh

# Phase 2: Infrastructure + Keycloak + oauth2-proxy (should complete in ~10-15 minutes)
bash 02-deploy-infrastructure.sh

# Check Keycloak is ready
kubectl get pod -n security -l app=keycloak -o wide
kubectl logs -n security -l app=keycloak --tail=50

# Check oauth2-proxy is ready
kubectl get pod -n security -l app=oauth2-proxy -o wide
kubectl logs -n security -l app=oauth2-proxy --tail=50

# Phase 3: Microservices (should complete in ~5-10 minutes)
bash 03-deploy-microservices.sh
```

---

## Expected Results After Phase 2

```
? KEYCLOAK STATUS:
NAME                 READY   STATUS    
keycloak-xxxxxxxxxx  1/1     Running   

? OAUTH2-PROXY STATUS:
NAME                      READY   STATUS    
oauth2-proxy-xxxxxxxxxxx  1/1     Running   

? KAFKA STATUS:
NAME        READY   STATUS    
kafka-pod   1/1     Running   

? KONG STATUS:
NAME                  READY   STATUS    
kong-gateway-xxxxxx   1/1     Running   

? VAULT STATUS:
NAME          READY   STATUS    
vault-0       1/1     Running   
```

---

## Critical Changes in 02-deploy-infrastructure.sh

1. **Keycloak building** - MUST happen before kubectl apply
2. **Keycloak waiting** - NOW MANDATORY (300s timeout)
3. **Kafka waiting** - NOW MANDATORY (240s timeout)
4. **Kong waiting** - NOW MANDATORY (240s timeout)
5. **oauth2-proxy** - NOW DEPLOYED (depends on Keycloak ready)
6. **Final validation** - Shows status of ALL services

---

## If oauth2-proxy still fails to start:

1. Check Keycloak is actually running:
   ```bash
   kubectl get pod -n security -l app=keycloak
   kubectl logs -n security -l app=keycloak --tail=100
   ```

2. Check oauth2-proxy logs:
   ```bash
   kubectl logs -n security -l app=oauth2-proxy
   ```

3. Check if it's waiting for Keycloak discovery:
   ```bash
   kubectl describe pod -n security -l app=oauth2-proxy
   ```

4. Verify Keycloak service has IP:
   ```bash
   kubectl get svc keycloak -n security
   ```

---

## Migration Notes

- **Dockerfile change**: realm-infra.json now built into image (no ConfigMap override)
- **Deployment change**: Removed volumeMounts for realm config
- **Setup logic**: oauth2-proxy now has its own setup script with dynamic IP injection
- **Wait logic**: All services now MUST reach Ready state before phase continues
- **Validation**: Phase 2 ends with comprehensive pod status report

