# ZTA Rebuild Summary — 20260505_080551

Cluster: kind-job7189
Started: 2026-05-05T08:05:51Z
Ended:   2026-05-05T08:15:28Z
Total:   577 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 26-gatekeeper | FAIL(1) | 290s | 26-gatekeeper.log |

## Cluster snapshot at end

```
Total pods: 76
cert-manager         cert-manager-5779d6596f-zz6qr                   1/1   Running   1 (87m ago)      4h45m
cert-manager         cert-manager-cainjector-5ddf6799cc-4zs2p        1/1   Running   3                4h45m
cert-manager         cert-manager-webhook-5d4dc79c59-jknln           1/1   Running   5 (3m58s ago)    4h45m
cosign-system        policy-controller-webhook-76f9d45bf4-6brfq      1/1   Running   18 (81s ago)     4h11m
ingress-nginx        ingress-nginx-controller-7fbf5b4d96-jqb8s       1/1   Running   3 (2m5s ago)     4h45m
kube-system          cilium-operator-788c799db4-85tlj                1/1   Running   14 (4m17s ago)   4h48m
kube-system          hubble-ui-67d8bff4c4-lrq8k                      2/2   Running   1 (4m12s ago)    4h48m
kube-system          kube-apiserver-job7189-control-plane            1/1   Running   1 (87m ago)      4h49m
kube-system          kube-controller-manager-job7189-control-plane   1/1   Running   6 (66m ago)      4h49m
kube-system          kube-scheduler-job7189-control-plane            1/1   Running   7                4h49m
kube-system          metrics-server-5445fc4c89-8vvws                 1/1   Running   2 (2m52s ago)    25m
spire                spire-agent-5h9rt                               1/1   Running   1                4h15m
spire                spire-agent-k24kp                               1/1   Running   1                4h15m
spire                spire-agent-xfnvd                               1/1   Running   1                4h15m
spire                spire-agent-zbpwt                               1/1   Running   2 (3m35s ago)    4h15m
spire                spire-server-0                                  2/2   Running   11 (3m38s ago)   4h15m
vault                vault-agent-agent-injector-59999f8dd-sjpxb      1/1   Running   10 (3m31s ago)   4h17m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         6
kube-scheduler                  7
cilium-operator-resource-lock   10
```
