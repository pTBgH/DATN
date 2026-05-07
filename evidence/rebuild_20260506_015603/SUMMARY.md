# ZTA Rebuild Summary — 20260506_015603

Cluster: kind-job7189
Started: 2026-05-06T01:56:04Z
Ended:   2026-05-06T02:34:05Z
Total:   2281 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 1s | 00-prep.log |
| 01-cluster | OK | 580s | 01-cluster.log |
| 02-infra | OK | 701s | 02-infra.log |
| 03-microservices | OK | 402s | 03-microservices.log |
| 05-seed | OK | 20s | 05-seed.log |
| 07-monitoring | OK | 59s | 07-monitoring.log |
| 08-harden | OK | 228s | 08-harden.log |
| 10-tetragon | OK | 34s | 10-tetragon.log |
| 20-spire | OK | 255s | 20-spire.log |
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
