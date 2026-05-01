# ZTA Rebuild Summary — 20260501_140823

Cluster: kind-job7189
Started: 2026-05-01T14:08:23Z
Ended:   2026-05-01T14:13:51Z
Total:   328 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 05-seed | OK | 15s | 05-seed.log |
| 07-monitoring | OK | 37s | 07-monitoring.log |
| 08-harden | OK | 228s | 08-harden.log |
| 10-tetragon | OK | 41s | 10-tetragon.log |
| 20-spire | FAIL(1) | 4s | 20-spire.log |

## Cluster snapshot at end

```
Total pods: 67

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
