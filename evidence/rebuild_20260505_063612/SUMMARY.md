# ZTA Rebuild Summary — 20260505_063612

Cluster: kind-job7189
Started: 2026-05-05T06:36:12Z
Ended:   2026-05-05T06:36:14Z
Total:   2 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 25-falco | FAIL(1) | 0s | 25-falco.log |

## Cluster snapshot at end

```
Total pods: 76
cosign-system        policy-controller-webhook-76f9d45bf4-6brfq      1/1   Running   3 (109m ago)   152m
kube-system          cilium-operator-788c799db4-85tlj                1/1   Running   2 (39m ago)    3h9m
kube-system          tetragon-8zd2r                                  2/2   Running   9 (17m ago)    156m
kube-system          tetragon-l9tmt                                  2/2   Running   9 (12m ago)    156m
kube-system          tetragon-vjtjr                                  2/2   Running   8 (6m8s ago)   156m
spire                spire-server-0                                  2/2   Running   2 (39m ago)    155m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   2
```
