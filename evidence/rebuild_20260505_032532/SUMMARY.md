# ZTA Rebuild Summary — 20260505_032532

Cluster: kind-job7189
Started: 2026-05-05T03:25:35Z
Ended:   2026-05-05T04:05:04Z
Total:   2369 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 1s | 00-prep.log |
| 01-cluster | OK | 383s | 01-cluster.log |
| 02-infra | OK | 841s | 02-infra.log |
| 03-microservices | OK | 431s | 03-microservices.log |
| 05-seed | OK | 18s | 05-seed.log |
| 07-monitoring | OK | 43s | 07-monitoring.log |
| 08-harden | OK | 298s | 08-harden.log |
| 10-tetragon | OK | 62s | 10-tetragon.log |
| 20-spire | OK | 170s | 20-spire.log |
| 21-cosign-keygen | OK | 1s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 33s | 22-cosign-sign.log |
| 23-policy-controller | OK | 87s | 23-policy-controller.log |

## Cluster snapshot at end

```
Total pods: 83
job7189-apps         candidate-service-6dc5ccc4c9-95vlk              0/4   Init:0/3   0               114s
job7189-apps         communication-service-5967c8855f-94phl          0/4   Init:0/3   0               113s
job7189-apps         hiring-service-6565957bd9-t9672                 0/4   Init:0/3   0               111s
job7189-apps         identity-service-868bc947c4-2mqgs               0/4   Init:0/3   0               106s
job7189-apps         job-service-7978d77d7d-rld4c                    0/4   Init:0/3   0               102s
job7189-apps         storage-service-b9fd8bb4b-px8gc                 0/4   Init:0/3   0               97s
job7189-apps         workspace-service-5cf9658d89-nm7bp              0/4   Init:0/3   0               94s
kube-system          tetragon-8zd2r                                  2/2   Running    1 (3m38s ago)   5m44s

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
