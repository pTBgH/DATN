# ZTA Rebuild Summary — 20260504_125242

Cluster: kind-job7189
Started: 2026-05-04T12:52:44Z
Ended:   2026-05-04T13:22:12Z
Total:   1768 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 07-monitoring | OK | 53s | 07-monitoring.log |
| 08-harden | OK | 433s | 08-harden.log |
| 10-tetragon | OK | 67s | 10-tetragon.log |
| 20-spire | OK | 211s | 20-spire.log |
| 21-cosign-keygen | OK | 2s | 21-cosign-keygen.log |
| 22-cosign-sign | OK | 47s | 22-cosign-sign.log |
| 23-policy-controller | OK | 126s | 23-policy-controller.log |
| 24-hubble-export | OK | 783s | 24-hubble-export.log |
| 25-falco | FAIL(1) | 2s | 25-falco.log |

## Cluster snapshot at end

```
Total pods: 87
cosign-system        policy-controller-webhook-76f9d45bf4-lzjk7      1/1   Running    1 (5m29s ago)   15m
job7189-apps         candidate-service-6b9b46b97c-4flqc              0/4   Init:0/3   0               16m
job7189-apps         candidate-service-7c9f674f69-42zwq              4/4   Running    1 (11m ago)     40m
job7189-apps         communication-service-76dbf9f97f-gff62          0/4   Init:0/3   0               16m
job7189-apps         communication-service-f4cc9fbb-6kfgc            4/4   Running    1 (11m ago)     40m
job7189-apps         hiring-service-784c85b555-qcgb2                 4/4   Running    1 (12m ago)     40m
job7189-apps         hiring-service-c59bdb6b8-gvcrp                  0/4   Init:0/3   0               16m
job7189-apps         identity-service-7798fb5dfd-wf67s               0/4   Init:0/3   0               16m
job7189-apps         identity-service-dc76c68c7-fmd9h                4/4   Running    1 (11m ago)     40m
job7189-apps         job-service-5f5947c4-x4n6g                      4/4   Running    1 (11m ago)     40m
job7189-apps         job-service-975d9c798-s54cx                     0/4   Init:0/3   0               16m
job7189-apps         storage-service-74679bbf59-cvb2l                4/4   Running    1 (12m ago)     40m
job7189-apps         storage-service-8668c67687-ns54z                0/4   Init:0/3   0               16m
job7189-apps         workspace-service-74ff96c877-hn26x              4/4   Running    1 (10m ago)     40m
job7189-apps         workspace-service-dbccb8858-h8qqj               0/4   Init:0/3   0               16m
kube-system          cilium-operator-788c799db4-h7n9q                1/1   Running    1 (4m18s ago)   94m
kube-system          metrics-server-94d8f7d95-gfwvd                  0/1   Running    5 (47s ago)     88m
kube-system          tetragon-5lcqm                                  2/2   Running    3 (63s ago)     21m
kube-system          tetragon-rd8vk                                  2/2   Running    2 (10m ago)     21m
kube-system          tetragon-vt4xr                                  2/2   Running    1 (56s ago)     21m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         0
kube-scheduler                  0
cilium-operator-resource-lock   1
```
