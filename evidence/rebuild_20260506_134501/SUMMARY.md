# ZTA Rebuild Summary — 20260506_134501

Cluster: kind-job7189
Started: 2026-05-06T13:45:02Z
Ended:   2026-05-06T14:40:58Z
Total:   3356 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 01-cluster | OK | 732s | 01-cluster.log |
| 02-infra | OK | 748s | 02-infra.log |
| 03-microservices | OK | 427s | 03-microservices.log |
| 05-seed | OK | 24s | 05-seed.log |
| 07-monitoring | OK | 60s | 07-monitoring.log |
| 08-harden | OK | 262s | 08-harden.log |
| 10-tetragon | OK | 52s | 10-tetragon.log |
| 20-spire | OK | 267s | 20-spire.log |
| 21-cosign-keygen | OK | 0s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 28s | 22-cosign-sign.log |
| 23-policy-controller | OK | 125s | 23-policy-controller.log |
| 24-hubble-export | OK | 622s | 24-hubble-export.log |
| 26-gatekeeper | FAIL(1) | 0s | 26-gatekeeper.log |

## Cluster snapshot at end

```
Total pods: 80

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
