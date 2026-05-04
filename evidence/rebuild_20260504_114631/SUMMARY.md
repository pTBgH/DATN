# ZTA Rebuild Summary — 20260504_114631

Cluster: kind-job7189
Started: 2026-05-04T11:46:34Z
Ended:   2026-05-04T12:46:00Z
Total:   3566 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 00-prep | OK | 3s | 00-prep.log |
| 01-cluster | OK | 508s | 01-cluster.log |
| 02-infra | OK | 1239s | 02-infra.log |
| 03-microservices | TIMEOUT | 1800s | 03-microservices.log |

## Cluster snapshot at end

```
Total pods: 58
job7189-apps         identity-service-dc76c68c7-fmd9h                0/4   PodInitializing   0     4m4s
job7189-apps         workspace-service-74ff96c877-hn26x              0/4   PodInitializing   0     4m6s

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
