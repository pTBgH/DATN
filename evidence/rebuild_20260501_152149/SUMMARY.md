# ZTA Rebuild Summary — 20260501_152149

Cluster: kind-job7189
Started: 2026-05-01T15:21:49Z
Ended:   2026-05-01T15:26:50Z
Total:   301 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 22-cosign-sign | TIMEOUT | 300s | 22-cosign-sign.log |

## Cluster snapshot at end

```
Total pods: 75
job7189-apps         candidate-service-7c9f674f69-z87h5              4/4   Running   1 (65m ago)   91m
job7189-apps         communication-service-f4cc9fbb-gbrjl            4/4   Running   1 (65m ago)   91m
job7189-apps         hiring-service-784c85b555-8fdjm                 4/4   Running   1 (65m ago)   91m
job7189-apps         identity-service-dc76c68c7-xrvm7                4/4   Running   1 (66m ago)   91m
job7189-apps         job-service-5f5947c4-8x7bl                      4/4   Running   1 (65m ago)   91m
job7189-apps         storage-service-74679bbf59-sh6w4                4/4   Running   1 (65m ago)   91m
job7189-apps         workspace-service-74ff96c877-fs6wb              4/4   Running   1 (65m ago)   91m
kube-system          tetragon-6hgpv                                  2/2   Running   3 (12m ago)   73m
kube-system          tetragon-q45zl                                  2/2   Running   3 (12m ago)   73m
kube-system          tetragon-v4c6l                                  2/2   Running   2 (22m ago)   73m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
