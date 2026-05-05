# ZTA Rebuild Summary — 20260504_151833

Cluster: kind-job7189
Started: 2026-05-04T15:18:36Z
Ended:   2026-05-04T15:42:19Z
Total:   1423 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 1s | 00-prep.log |
| 01-cluster | OK | 348s | 01-cluster.log |
| 02-infra | OK | 710s | 02-infra.log |
| 03-microservices | FAIL(1) | 361s | 03-microservices.log |

## Cluster snapshot at end

```
Total pods: 58

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
