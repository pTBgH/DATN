# ZTA Rebuild Summary — 20260505_171921

Cluster: kind-job7189
Started: 2026-05-05T17:19:21Z
Ended:   2026-05-05T17:25:55Z
Total:   394 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 26-gatekeeper | OK | 52s | 26-gatekeeper.log |
| 27-pdp | OK | 133s | 27-pdp.log |
| 90-verify | OK | 208s | 90-verify.log |

## Cluster snapshot at end

```
Total pods: 78
job7189-apps         candidate-service-redis-8dbc4444-vvgz2          1/1   Running   1 (3m15s ago)   98m
job7189-apps         communication-service-redis-848bb44985-2kq5m    1/1   Running   1 (3m18s ago)   98m
job7189-apps         hiring-service-7bdd44fd8f-xjbcd                 4/4   Running   4 (2m23s ago)   84m
job7189-apps         hiring-service-redis-66467986cb-sr67l           1/1   Running   1 (3m14s ago)   98m
job7189-apps         identity-service-redis-58bc5b5fdf-l2l2r         1/1   Running   1 (3m18s ago)   98m
job7189-apps         job-service-75454fb866-w4pkf                    4/4   Running   4 (112s ago)    84m
job7189-apps         job-service-redis-7d978bf878-hw9gf              1/1   Running   1 (3m19s ago)   98m
job7189-apps         storage-service-745bc86fb6-dh4h5                4/4   Running   4 (96s ago)     84m
job7189-apps         storage-service-redis-67999f7dd-kmt9d           1/1   Running   1 (3m14s ago)   98m
job7189-apps         workspace-service-65fbcdfcc4-9dcc4              4/4   Running   4 (72s ago)     84m
job7189-apps         workspace-service-redis-76b9bf6b4d-mdvp8        1/1   Running   1 (3m18s ago)   98m
monitoring           kube-state-metrics-856b75dfd5-v2cbs             1/1   Running   1 (79m ago)     90m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   0
```
