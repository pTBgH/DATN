# Project DOAN2 - Deployment Guide

## New 3-Part Deployment System

Your deployment has been split into **3 independent, testable parts**:

### Structure

```
rebuild.sh (Main Orchestrator - Menu-driven)
  ├── 01-setup-cluster.sh       (Part 1: Cluster Setup)
  ├── 02-deploy-infrastructure.sh (Part 2: Infrastructure Services)
  └── 03-deploy-microservices.sh  (Part 3: Microservices & Ingress)
```

## Quick Start

### Option 1: Full Automated Deployment (All 3 Parts)
```bash
bash rebuild.sh
# Select option 1
```

### Option 2: Manual Step-by-Step (Recommended for Testing)

**Step 1: Setup Cluster**
```bash
bash 01-setup-cluster.sh
# Wait for completion (~2-3 minutes)
```

**Step 2: Deploy Infrastructure**
```bash
bash 02-deploy-infrastructure.sh
# Wait for completion (~5-10 minutes)
```

**Step 3: Deploy Microservices**
```bash
bash 03-deploy-microservices.sh
# Wait for completion (~5-10 minutes)
```

### Option 3: Run Individual Parts via Main Script
```bash
bash rebuild.sh
# Then select:
# 2 = Phase 1 only
# 3 = Phase 2 only
# 4 = Phase 3 only
# 5 = Phases 2 & 3 (skip cluster)
# 6 = Clean up cluster
```

## What Each Part Does

### 01-setup-cluster.sh (Phase 1: ~2-3 minutes)
- Deletes old Kind cluster
- Creates new Kind cluster
- Adds Helm repositories
- Installs Gateway API v1.1.0
- **Installs Cilium CNI** (the critical part that was failing)
- Creates namespaces
- Installs cert-manager
- Installs Nginx Ingress Controller

**Status Check After Phase 1:**
```bash
kubectl get pod -n kube-system | grep cilium
# Should show: 1/1 Running (not CrashLoopBackOff)

kubectl get pod -n ingress-nginx
# Should show controller: 1/1 Running
```

### 02-deploy-infrastructure.sh (Phase 2: ~5-10 minutes)
- Deploys MySQL & phpMyAdmin
- Deploys Keycloak
- Deploys Kafka
- Deploys Kong
- Deploys cert-manager issuer
- Deploys Vault
- Runs all Vault configuration scripts
- Installs Vault injector

**Status Check After Phase 2:**
```bash
kubectl get pod -A | grep -E "(mysql|keycloak|kafka|kong|vault)"
# Services should be starting or running
```

### 03-deploy-microservices.sh (Phase 3: ~5-10 minutes)
- Deploys Ingress routes
- Deploys microservices via Helmfile
- Displays final system status

**Status Check After Phase 3:**
```bash
kubectl get pod -A
# All services should be deployed

kubectl get ingress -A
# Should show configured ingress routes
```

## Benefits of This Split

✅ **Test Each Part Independently**
- If Part 1 fails, you haven't wasted time on Parts 2 & 3
- Debug issues in isolation

✅ **Better Error Visibility**
- Each part has its own timing summary
- See exactly where it fails

✅ **Resumable Deploys**
- If Part 2 times out, just run it again
- Done't need to restart from Part 1

✅ **Faster Development**
- Modify Phase 2 without regenerating cluster
- Test infrastructure changes without full redeploy

## Expected Timeline

| Phase | Duration | Purpose |
|-------|----------|---------|
| Phase 1 | 2-3 min | Cluster & CNI setup |
| Phase 2 | 5-10 min | Infrastructure services |
| Phase 3 | 5-10 min | Microservices |
| **TOTAL** | **15-25 min** | Full system |

## Monitoring During Deployment

In a separate terminal, watch pods:
```bash
# Watch all pods
kubectl get pod -A -w

# Watch specific namespace
kubectl get pod -n job7189-apps -w

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check Cilium specifically (critical)
kubectl get pod -n kube-system -l k8s-app=cilium -w
```

## Troubleshooting

### Cilium stuck on CrashLoopBackOff (Phase 1)
```bash
# Check Cilium operator logs
kubectl logs -n kube-system -l app=cilium-operator --tail=50

# This should now work with the v1.1.0 fix
```

### Pods stuck on Pending (Phase 2)
```bash
# Check node resources
kubectl describe nodes

# Check pod details
kubectl describe pod -n <namespace> <pod-name>
```

### Helmfile apply fails (Phase 3)
```bash
# Check if dependencies are ready
kubectl get pod -A | grep -E "(mysql|kafka|vault)"

# Try running Phase 2 again or wait longer
```

## Clean Up

To delete everything and start over:
```bash
bash rebuild.sh
# Select option 6
# Or manually:
kind delete cluster --name job7189
```

## Advanced Usage

### Run only Phase 2 (infrastructure):
```bash
bash rebuild.sh
# Select option 3
# (Assumes Phase 1 already completed)
```

### Run only Phase 3 (microservices):
```bash
bash rebuild.sh
# Select option 4
# (Assumes Phases 1 & 2 already completed)
```

### Skip cluster setup (already exists):
```bash
bash rebuild.sh
# Select option 5 (Phases 2 & 3 only)
```

## Key Technology Versions

- **Kubernetes**: v1.35.0 (Kind)
- **CNI**: Cilium 1.19.1
- **Gateway API**: v1.1.0 (compatible with Cilium 1.19.1)
- **Ingress**: Nginx v1.15.0
- **Cert Manager**: Latest
- **Vault**: Latest

## Files Modified

- **rebuild.sh** - New orchestrator menu
- **01-setup-cluster.sh** - NEW (extracted from original)
- **02-deploy-infrastructure.sh** - NEW (extracted from original)
- **03-deploy-microservices.sh** - NEW (extracted from original)
- **CILIUM_FIX.md** - Documentation of Cilium v1.1.0 fix

## Next Steps

1. Test Phase 1 first: `bash 01-setup-cluster.sh`
2. Monitor with: `kubectl get pod -A -w`
3. Once Phase 1 succeeds, run Phase 2: `bash 02-deploy-infrastructure.sh`
4. Finally run Phase 3: `bash 03-deploy-microservices.sh`

**Happy deploying! 🚀**
