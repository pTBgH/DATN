# ZTA Rebuild Summary — 20260501_143744

Cluster: kind-job7189
Started: 2026-05-01T14:37:44Z
Ended:   2026-05-01T14:40:25Z
Total:   161 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 20-spire | OK | 153s | 20-spire.log |
| 21-cosign-keygen | OK | 1s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 2s | 22-cosign-sign.log |
| 23-policy-controller | FAIL(1) | 3s | 23-policy-controller.log |

## Cluster snapshot at end

```
Total pods: 75
job7189-apps         candidate-service-7c9f674f69-z87h5              4/4   Running   1 (19m ago)     45m
job7189-apps         communication-service-f4cc9fbb-gbrjl            4/4   Running   1 (19m ago)     45m
job7189-apps         hiring-service-784c85b555-8fdjm                 4/4   Running   1 (19m ago)     45m
job7189-apps         identity-service-dc76c68c7-xrvm7                4/4   Running   1 (19m ago)     45m
job7189-apps         job-service-5f5947c4-8x7bl                      4/4   Running   1 (19m ago)     45m
job7189-apps         storage-service-74679bbf59-sh6w4                4/4   Running   1 (18m ago)     45m
job7189-apps         workspace-service-74ff96c877-fs6wb              4/4   Running   1 (19m ago)     45m
kube-system          tetragon-6hgpv                                  2/2   Running   1 (3m51s ago)   27m
kube-system          tetragon-q45zl                                  2/2   Running   1 (2m29s ago)   27m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
