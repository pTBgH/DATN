# ZTA Rebuild Summary — 20260501_133513

Cluster: kind-job7189
Started: 2026-05-01T13:35:13Z
Ended:   2026-05-01T13:58:11Z
Total:   1378 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 0s | 00-prep.log |
| 01-cluster | OK | 330s | 01-cluster.log |
| 02-infra | OK | 668s | 02-infra.log |
| 03-microservices | FAIL(0) | 379s | 03-microservices.log |

## Cluster snapshot at end

```
Total pods: 58

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
