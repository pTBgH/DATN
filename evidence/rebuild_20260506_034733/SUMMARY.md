# ZTA Rebuild Summary — 20260506_034733

Cluster: kind-job7189
Started: 2026-05-06T03:47:36Z
Ended:   2026-05-06T04:27:09Z
Total:   2373 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 1s | 00-prep.log |
| 01-cluster | OK | 599s | 01-cluster.log |
| 02-infra | OK | 739s | 02-infra.log |
| 03-microservices | OK | 402s | 03-microservices.log |
| 05-seed | OK | 21s | 05-seed.log |
| 07-monitoring | OK | 58s | 07-monitoring.log |
| 08-harden | OK | 253s | 08-harden.log |
| 10-tetragon | OK | 40s | 10-tetragon.log |
| 20-spire | OK | 259s | 20-spire.log |
| 21-cosign-keygen | OK | 1s | 21-cosign-keygen.log |

## Cluster snapshot at end

```
Total pods: 75

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
