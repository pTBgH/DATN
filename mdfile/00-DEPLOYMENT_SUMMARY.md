# ✅ Deployment Scripts Refactored - Summary

## What Was Done

Your monolithic `rebuild.sh` has been split into **3 independent, testable scripts** plus a menu-driven orchestrator:

### New Files Created

```
01-setup-cluster.sh            (6.6 KB) - Phase 1: Cluster & CNI setup
02-deploy-infrastructure.sh    (8.3 KB) - Phase 2: Infrastructure services
03-deploy-microservices.sh     (6.9 KB) - Phase 3: Microservices & Ingress
rebuild.sh                     (7.1 KB) - UPDATED: Menu-driven orchestrator
DEPLOYMENT_GUIDE.md            (4.0 KB) - Usage guide & troubleshooting
```

### Old vs New Approach

#### Before (All-In-One)
```
rebuild.sh (long monolithic script)
└─ 200+ lines, all phases mixed together
   ❌ Hard to debug
   ❌ Restart from beginning on failure
   ❌ Waste time if early phase fails
```

#### After (3-Part Modular)
```
rebuild.sh (Menu orchestrator)
├── 01-setup-cluster.sh        (80 lines, focused)
├── 02-deploy-infrastructure.sh (120 lines, focused)
└── 03-deploy-microservices.sh  (110 lines, focused)
   ✅ Test independently
   ✅ Resume from where failed
   ✅ Better error visibility
```

## Usage Guide

### Quick Start - Full Deployment
```bash
bash rebuild.sh
# Select option: 1
# [Automatic - Wait ~15-25 minutes]
```

### Recommended - Step-by-Step Testing
```bash
# Test Phase 1 (Cluster setup)
bash 01-setup-cluster.sh
# [Monitor] kubectl get pod -n kube-system | grep cilium

# Test Phase 2 (Infrastructure)
bash 02-deploy-infrastructure.sh
# [Monitor] kubectl get pod -n data | grep mysql

# Test Phase 3 (Microservices)
bash 03-deploy-microservices.sh
# [Monitor] kubectl get pod -A
```

### Via Menu System
```bash
bash rebuild.sh
# Options:
# 1 = All phases sequential
# 2 = Phase 1 only
# 3 = Phase 2 only
# 4 = Phase 3 only
# 5 = Phases 2 & 3 (skip cluster)
# 6 = Clean up cluster
# 0 = Exit
```

## Phase Breakdown

### Phase 1: Cluster Setup (~2-3 min)
**File:** `01-setup-cluster.sh`

What it does:
- Delete old Kind cluster
- Create new Kind cluster
- Add Helm repositories
- Install Gateway API v1.1.0 (the Cilium fix!)
- **Install Cilium CNI** ← This was failing before
- Create namespaces
- Install cert-manager
- Install Nginx Ingress Controller

**Status check:**
```bash
kubectl get pod -n kube-system -l k8s-app=cilium
# Should show: 1/1 Running (not CrashLoopBackOff)
```

### Phase 2: Infrastructure (~5-10 min)
**File:** `02-deploy-infrastructure.sh`

What it does:
- Deploy MySQL & phpMyAdmin
- Deploy Keycloak
- Deploy Kafka
- Deploy Kong
- Deploy cert-manager issuer
- Deploy Vault infrastructure
- Run Vault configuration scripts
- Install Vault injector

**Status check:**
```bash
kubectl get pod -A | grep -E "(mysql|keycloak|kafka|kong)"
```

### Phase 3: Microservices (~5-10 min)
**File:** `03-deploy-microservices.sh`

What it does:
- Deploy Ingress routes
- Deploy microservices via Helmfile
- Display final system status

**Status check:**
```bash
kubectl get pod -n job7189-apps
kubectl get ingress -A
```

## Key Fixes & Improvements

✅ **Fixed:** Cilium v1.1.0 compatibility issue (was failing in original)
✅ **Fixed:** Duplicate shebang breaking scripts
✅ **Added:** Individual phase timing summaries
✅ **Added:** Pre-flight checks before each phase
✅ **Added:** Better error messages with color coding
✅ **Added:** Non-blocking error handling (continues on warnings)
✅ **Added:** Helpful next steps after each phase
✅ **Added:** Monitoring commands for troubleshooting

## Timeline Estimate

| Phase | Time | Status |
|-------|------|--------|
| Phase 1 | 2-3 min | Cluster setup |
| Phase 2 | 5-10 min | Infrastructure |
| Phase 3 | 5-10 min | Microservices |
| **TOTAL** | **15-25 min** | Full system ready |

## Most Important: Test Phase 1 First!

Phase 1 includes the critical Cilium CNI setup that was causing crashes:

```bash
# Test it immediately:
bash 01-setup-cluster.sh

# Monitor Cilium (should NOT crash):
watch kubectl get pod -n kube-system -l k8s-app=cilium
```

If Cilium shows `1/1 Running` instead of `CrashLoopBackOff`, the v1.1.0 fix is working!

## Next Steps

1. **Read:** `DEPLOYMENT_GUIDE.md` for detailed usage
2. **Test:** `bash 01-setup-cluster.sh` to verify cluster setup
3. **Monitor:** `kubectl get pod -A -w` in another terminal
4. **Continue:** `bash 02-deploy-infrastructure.sh` once Phase 1 completes
5. **Finish:** `bash 03-deploy-microservices.sh` once Phase 2 completes

## File Structure

```
/home/ptb/project/DOAN2/
├── rebuild.sh                        (Main menu orchestrator)
├── 01-setup-cluster.sh               (PHASE 1 - NEW)
├── 02-deploy-infrastructure.sh       (PHASE 2 - NEW)
├── 03-deploy-microservices.sh        (PHASE 3 - NEW)
├── DEPLOYMENT_GUIDE.md               (Usage guide - NEW)
├── THIS_FILE.md                      (This summary)
├── CILIUM_FIX.md                     (Cilium fix details)
├── infras/                           (Infrastructure configs)
├── k8s-management/                   (Helm values & configs)
└── [other project files]
```

## Verification Commands

```bash
# List all new scripts
ls -lh *setup*.sh *deploy*.sh rebuild.sh

# Check for syntax errors
bash -n 01-setup-cluster.sh
bash -n 02-deploy-infrastructure.sh
bash -n 03-deploy-microservices.sh
bash -n rebuild.sh

# Test Phase 1
bash 01-setup-cluster.sh

# Monitor progress
watch kubectl get pod -A

# Check Cilium specifically (critical)
kubectl get pod -n kube-system | grep cilium
```

## Support

If you encounter issues:

1. **Cilium CrashLoopBackOff?**
   - See `CILIUM_FIX.md` for detailed diagnosis
   - Check: `kubectl logs -n kube-system -l app=cilium-operator`

2. **Pods stuck on Pending?**
   - Check node resources: `kubectl describe nodes`
   - Check specific pod: `kubectl describe pod -n <ns> <pod>`

3. **Helmfile apply fails?**
   - Ensure infrastructure is ready
   - Wait longer for dependencies
   - Check: `kubectl get pod -A | grep -v Running`

See `DEPLOYMENT_GUIDE.md` for complete troubleshooting guide.

---

**Status: ✅ READY FOR TESTING**

All scripts have passed syntax validation and are ready to use!
