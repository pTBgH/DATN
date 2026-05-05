# ZTA Rebuild Summary — 20260505_114551

Cluster: kind-job7189
Started: 2026-05-05T11:45:52Z
Ended:   2026-05-05T13:01:54Z
Total:   4562 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 1s | 00-prep.log |
| 01-cluster | OK | 873s | 01-cluster.log |
| 02-infra | OK | 1146s | 02-infra.log |
| 03-microservices | OK | 580s | 03-microservices.log |
| 05-seed | OK | 36s | 05-seed.log |
| 07-monitoring | OK | 70s | 07-monitoring.log |
| 08-harden | OK | 385s | 08-harden.log |
| 10-tetragon | OK | 61s | 10-tetragon.log |
| 20-spire | OK | 287s | 20-spire.log |
| 21-cosign-keygen | OK | 2s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 59s | 22-cosign-sign.log |
| 23-policy-controller | OK | 339s | 23-policy-controller.log |
| 24-hubble-export | OK | 721s | 24-hubble-export.log |

## Cluster snapshot at end

```
Total pods: 80
cosign-system        policy-controller-webhook-76f9d45bf4-t29fn      1/1   Running   1 (13m ago)     16m
kube-system          cilium-operator-788c799db4-rt887                1/1   Running   1 (3m7s ago)    72m
kube-system          kube-controller-manager-job7189-control-plane   1/1   Running   1 (3m2s ago)    73m
kube-system          metrics-server-94d8f7d95-7nqp4                  1/1   Running   1 (17m ago)     65m
kube-system          tetragon-bjr8h                                  2/2   Running   1 (14m ago)     24m
monitoring           kube-state-metrics-856b75dfd5-gxcv7             1/1   Running   1 (7m3s ago)    25m
spire                spire-server-0                                  2/2   Running   1 (3m10s ago)   23m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         1
kube-scheduler                  0
cilium-operator-resource-lock   1
```
