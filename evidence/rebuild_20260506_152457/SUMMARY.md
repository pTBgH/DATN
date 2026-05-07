# ZTA Rebuild Summary — 20260506_152457

Cluster: kind-job7189
Started: 2026-05-06T15:24:58Z
Ended:   2026-05-06T15:37:30Z
Total:   752 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 26-gatekeeper | OK | 58s | 26-gatekeeper.log |
| 27-pdp | OK | 134s | 27-pdp.log |
| 90-verify | FAIL(2) | 548s | 90-verify.log |

## Cluster snapshot at end

```
Total pods: 79
cosign-system        policy-controller-webhook-76f9d45bf4-7sndb      1/1   Running   2 (118s ago)    68m
job7189-apps         candidate-service-redis-8dbc4444-plkdc          1/1   Running   1 (9m11s ago)   83m
job7189-apps         communication-service-redis-848bb44985-gm29d    1/1   Running   1 (9m11s ago)   83m
job7189-apps         hiring-service-7d477c57bc-hm62t                 4/4   Running   4 (8m16s ago)   69m
job7189-apps         hiring-service-redis-66467986cb-6gqbg           1/1   Running   1 (9m11s ago)   83m
job7189-apps         identity-service-79bbf6c76d-ljqt6               4/4   Running   4 (8m9s ago)    69m
job7189-apps         identity-service-redis-58bc5b5fdf-6cz9h         1/1   Running   1 (9m10s ago)   83m
job7189-apps         job-service-55c6d86596-n5dl8                    4/4   Running   4 (7m52s ago)   69m
job7189-apps         job-service-redis-7d978bf878-tnsms              1/1   Running   1 (9m11s ago)   83m
job7189-apps         storage-service-566dd9c75c-mrtkk                4/4   Running   4 (7m34s ago)   69m
job7189-apps         storage-service-redis-67999f7dd-qzm6z           1/1   Running   1 (9m11s ago)   83m
job7189-apps         workspace-service-redis-76b9bf6b4d-5sh8f        1/1   Running   1 (9m10s ago)   83m
kube-system          cilium-operator-788c799db4-dshrc                1/1   Running   1 (2m21s ago)   111m
kube-system          kube-controller-manager-job7189-control-plane   1/1   Running   1 (99s ago)     112m
kube-system          kube-scheduler-job7189-control-plane            1/1   Running   1 (89s ago)     112m
kube-system          metrics-server-94d8f7d95-hdt9v                  0/1   Running   5               104m
spire                spire-server-0                                  2/2   Running   2 (108s ago)    74m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         1
kube-scheduler                  1
cilium-operator-resource-lock   1
```
