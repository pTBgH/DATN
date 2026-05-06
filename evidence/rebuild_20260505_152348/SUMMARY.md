# ZTA Rebuild Summary — 20260505_152348

Cluster: kind-job7189
Started: 2026-05-05T15:23:49Z
Ended:   2026-05-05T16:11:38Z
Total:   2869 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 1s | 00-prep.log |
| 01-cluster | OK | 594s | 01-cluster.log |
| 02-infra | OK | 676s | 02-infra.log |
| 03-microservices | OK | 305s | 03-microservices.log |
| 05-seed | OK | 21s | 05-seed.log |
| 07-monitoring | OK | 65s | 07-monitoring.log |
| 08-harden | OK | 265s | 08-harden.log |
| 10-tetragon | OK | 52s | 10-tetragon.log |
| 20-spire | OK | 263s | 20-spire.log |
| 21-cosign-keygen | OK | 1s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 25s | 22-cosign-sign.log |
| 23-policy-controller | OK | 101s | 23-policy-controller.log |
| 24-hubble-export | OK | 302s | 24-hubble-export.log |
| 26-gatekeeper | FAIL(1) | 115s | 26-gatekeeper.log |

## Cluster snapshot at end

```
Total pods: 80
monitoring           kube-state-metrics-856b75dfd5-v2cbs             1/1   Running   1 (5m2s ago)   16m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
