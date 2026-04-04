# 🚀 Quick Reference Card

## Fastest Way to Deploy Everything

```bash
cd /home/ptb/project/DOAN2

# Option A: Fully automated (23 minutes)
bash rebuild.sh
# Then select: 1

# Option B: Step by step (recommended for testing)
bash 01-setup-cluster.sh           # 2-3 min
bash 02-deploy-infrastructure.sh   # 5-10 min
bash 03-deploy-microservices.sh    # 5-10 min
```

## Monitor Progress (In Another Terminal)

```bash
# Watch all pods
watch kubectl get pod -A

# Watch just Cilium (critical!)
watch kubectl get pod -n kube-system -l k8s-app=cilium

# Watch your apps
watch kubectl get pod -n job7189-apps

# Watch events
kubectl get events -A --sort-by='.lastTimestamp' -w
```

## What to Expect

### Phase 1 (Cluster Setup)
```
✅ Kind cluster created
✅ Cilium installed (1/1 Running - NOT CrashLoopBackOff!)
✅ cert-manager installed
✅ Nginx Ingress ready
```

### Phase 2 (Infrastructure)
```
✅ MySQL running
✅ Kafka running
✅ Kong running
✅ Vault deployed
```

### Phase 3 (Microservices)
```
✅ Ingress routes configured
✅ All microservices deployed
✅ System ready!
```

## Key Metrics

| Metric | Value |
|--------|-------|
| Total Time | 15-25 minutes |
| Kubernetes Version | 1.35.0 |
| Cilium Version | 1.19.1 |
| Gateway API | v1.1.0 |
| Ingress Nginx | v1.15.0 |

## Critical Success Indicator

After Phase 1 completes, check this:

```bash
kubectl get pod -n kube-system -l k8s-app=cilium
```

**Should see:**
```
NAME           READY   STATUS    RESTARTS   AGE
cilium-xxxxx   1/1     Running   0          2m
cilium-xxxxx   1/1     Running   0          2m
...
```

**NOT:**
```
NAME           READY   STATUS            RESTARTS   AGE
cilium-xxxxx   0/1     CrashLoopBackOff  5          2m
```

If you see CrashLoopBackOff → That's the old bug (now fixed!)

## Troubleshooting Quick Links

- **Cilium issues?** → See `CILIUM_FIX.md`
- **Full usage guide?** → See `DEPLOYMENT_GUIDE.md`
- **Detailed changes?** → See `00-DEPLOYMENT_SUMMARY.md`
- **How to use rebuild.sh?** → Menu has 6 options

## Testing Individual Parts

```bash
# Just test Phase 1
bash 01-setup-cluster.sh

# Just update infrastructure
bash 02-deploy-infrastructure.sh

# Just deploy new microservices
bash 03-deploy-microservices.sh

# Or use menu for more options
bash rebuild.sh
# Options 2-5 let you pick specific phases
```

## Clean Up & Restart

```bash
# Delete cluster and start over
bash rebuild.sh
# Select: 6

# Or manually
kind delete cluster --name job7189
```

## Status After Full Deployment

```bash
# Check cluster
kubectl get nodes
# Should show: job7189-control-plane, worker, worker2, worker3

# Check all namespaces
kubectl get ns
# Should show: kube-system, job7189-apps, management, data, gateway, etc.

# Check services
kubectl get svc -A | head -20

# Check ingress
kubectl get ingress -A
```

## Most Important Commands

```bash
# Watch cluster come up
watch kubectl get pod -A

# Check Cilium (the fix!)
kubectl get pod -n kube-system | grep cilium

# Check infrastructure
kubectl get pod -n data
kubectl get pod -n management
kubectl get pod -n gateway

# Check microservices
kubectl get pod -n job7189-apps

# Get pod details
kubectl describe pod -n <namespace> <pod-name>

# View logs
kubectl logs -n <namespace> <pod-name> --tail=50

# Port forward to test
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

## Files Reference

| File | Purpose |
|------|---------|
| `01-setup-cluster.sh` | Phase 1: Cluster setup |
| `02-deploy-infrastructure.sh` | Phase 2: Infrastructure services |
| `03-deploy-microservices.sh` | Phase 3: Microservices |
| `rebuild.sh` | Menu orchestrator |
| `DEPLOYMENT_GUIDE.md` | Complete usage guide |
| `CILIUM_FIX.md` | Cilium v1.1.0 fix details |
| `00-DEPLOYMENT_SUMMARY.md` | What was done summary |

## Remember

✅ All scripts have 3 parts that can be tested independently
✅ Each part reports its own timing
✅ Non-blocking errors (continue on warnings)
✅ Cilium uses v1.1.0 (compatible with Cilium 1.19.1)
✅ Monitor with `watch kubectl get pod -A`

**Start Phase 1:**
```bash
bash 01-setup-cluster.sh
```
