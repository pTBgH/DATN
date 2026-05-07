# ZTA Rebuild Summary — 20260506_000259

Cluster: kind-job7189
Started: 2026-05-06T00:02:59Z
Ended:   2026-05-06T00:49:53Z
Total:   2814 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 2s | 00-prep.log |
| 01-cluster | OK | 627s | 01-cluster.log |
| 02-infra | OK | 759s | 02-infra.log |
| 03-microservices | OK | 321s | 03-microservices.log |
| 05-seed | OK | 18s | 05-seed.log |
| 07-monitoring | OK | 58s | 07-monitoring.log |
| 08-harden | OK | 220s | 08-harden.log |
| 10-tetragon | OK | 31s | 10-tetragon.log |
| 20-spire | OK | 255s | 20-spire.log |
| 21-cosign-keygen | OK | 1s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 19s | 22-cosign-sign.log |
| 23-policy-controller | OK | 92s | 23-policy-controller.log |
| 24-hubble-export | OK | 320s | 24-hubble-export.log |
| 26-gatekeeper | FAIL(1) | 78s | 26-gatekeeper.log |

## Cluster snapshot at end

```
Total pods: 80

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
