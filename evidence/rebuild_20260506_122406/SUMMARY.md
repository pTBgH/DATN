# ZTA Rebuild Summary — 20260506_122406

Cluster: kind-job7189
Started: 2026-05-06T12:24:06Z
Ended:   2026-05-06T13:03:02Z
Total:   2336 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 01-cluster | OK | 647s | 01-cluster.log |
| 02-infra | OK | 702s | 02-infra.log |
| 03-microservices | OK | 351s | 03-microservices.log |
| 05-seed | OK | 18s | 05-seed.log |
| 07-monitoring | OK | 57s | 07-monitoring.log |
| 08-harden | OK | 248s | 08-harden.log |
| 10-tetragon | FAIL(1) | 306s | 10-tetragon.log |

## Cluster snapshot at end

```
Total pods: 67
kube-system          tetragon-fhzk4                                  0/2   ContainerCreating   0     5m8s
kube-system          tetragon-n2fjq                                  0/2   ContainerCreating   0     5m8s
kube-system          tetragon-rqtrw                                  1/2   ErrImagePull        0     5m8s

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
