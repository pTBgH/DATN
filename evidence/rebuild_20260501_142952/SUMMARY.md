# ZTA Rebuild Summary — 20260501_142952

Cluster: kind-job7189
Started: 2026-05-01T14:29:52Z
Ended:   2026-05-01T14:29:57Z
Total:   5 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 20-spire | FAIL(1) | 3s | 20-spire.log |

## Cluster snapshot at end

```
Total pods: 67
job7189-apps         candidate-service-7c9f674f69-z87h5              4/4   Running   1 (8m55s ago)   34m
job7189-apps         communication-service-f4cc9fbb-gbrjl            4/4   Running   1 (9m3s ago)    34m
job7189-apps         hiring-service-784c85b555-8fdjm                 4/4   Running   1 (8m48s ago)   34m
job7189-apps         identity-service-dc76c68c7-xrvm7                4/4   Running   1 (9m31s ago)   34m
job7189-apps         job-service-5f5947c4-8x7bl                      4/4   Running   1 (8m38s ago)   34m
job7189-apps         storage-service-74679bbf59-sh6w4                4/4   Running   1 (8m11s ago)   34m
job7189-apps         workspace-service-74ff96c877-fs6wb              4/4   Running   1 (8m40s ago)   34m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
