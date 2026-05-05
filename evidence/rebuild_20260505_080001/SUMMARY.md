# ZTA Rebuild Summary — 20260505_080001

Cluster: kind-job7189
Started: 2026-05-05T08:00:02Z
Ended:   2026-05-05T08:03:42Z
Total:   220 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 26-gatekeeper | FAIL(1) | 160s | 26-gatekeeper.log |

## Cluster snapshot at end

```
Total pods: 76
cert-manager         cert-manager-5779d6596f-zz6qr                   1/1   Running   1 (75m ago)    4h33m
cert-manager         cert-manager-cainjector-5ddf6799cc-4zs2p        1/1   Running   3              4h33m
cert-manager         cert-manager-webhook-5d4dc79c59-jknln           1/1   Running   4 (69m ago)    4h33m
cosign-system        policy-controller-webhook-76f9d45bf4-6brfq      1/1   Running   16 (53m ago)   3h59m
ingress-nginx        ingress-nginx-controller-7fbf5b4d96-jqb8s       1/1   Running   2 (74m ago)    4h33m
kube-system          cilium-operator-788c799db4-85tlj                1/1   Running   11 (54m ago)   4h37m
kube-system          kube-apiserver-job7189-control-plane            1/1   Running   1 (75m ago)    4h37m
kube-system          kube-controller-manager-job7189-control-plane   1/1   Running   6 (54m ago)    4h37m
kube-system          kube-scheduler-job7189-control-plane            1/1   Running   6 (54m ago)    4h37m
spire                spire-agent-k24kp                               1/1   Running   1              4h3m
spire                spire-agent-xfnvd                               1/1   Running   1              4h3m
spire                spire-agent-zbpwt                               1/1   Running   1 (78m ago)    4h3m
spire                spire-server-0                                  2/2   Running   9              4h3m
vault                vault-agent-agent-injector-59999f8dd-sjpxb      1/1   Running   8 (60m ago)    4h5m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         6
kube-scheduler                  6
cilium-operator-resource-lock   8
```
