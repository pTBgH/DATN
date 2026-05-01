# ZTA Rebuild Summary — 20260501_153604

Cluster: kind-job7189
Started: 2026-05-01T15:36:04Z
Ended:   2026-05-01T15:56:35Z
Total:   1231 seconds

| Step | Status | Elapsed | Log |
|------|--------|---------|-----|
| 22-cosign-sign | OK | 46s | 22-cosign-sign.log |
| 23-policy-controller | OK | 102s | 23-policy-controller.log |
| 24-hubble-export | FAIL(1) | 792s | 24-hubble-export.log |

## Cluster snapshot at end

```
Total pods: 87
cert-manager         cert-manager-cainjector-5ddf6799cc-ht574        0/1   Error              0               138m
cosign-system        policy-controller-webhook-76f9d45bf4-hbgcd      1/1   Running            3 (6m59s ago)   19m
job7189-apps         candidate-service-759b577984-zch4n              0/4   Init:0/3           0               20m
job7189-apps         candidate-service-7c9f674f69-z87h5              4/4   Running            1 (95m ago)     121m
job7189-apps         communication-service-67947dd588-8flln          0/4   Init:0/3           0               20m
job7189-apps         communication-service-f4cc9fbb-gbrjl            4/4   Running            1 (95m ago)     121m
job7189-apps         hiring-service-59dbffb9c5-tzxss                 0/4   Init:0/3           0               20m
job7189-apps         hiring-service-784c85b555-8fdjm                 4/4   Running            1 (95m ago)     121m
job7189-apps         identity-service-5ddbc9cf66-s57wp               0/4   Init:0/3           0               20m
job7189-apps         identity-service-dc76c68c7-xrvm7                4/4   Running            1 (96m ago)     121m
job7189-apps         job-service-54b4c6db8c-rmrz7                    0/4   Init:0/3           0               20m
job7189-apps         job-service-5f5947c4-8x7bl                      4/4   Running            1 (95m ago)     121m
job7189-apps         storage-service-74679bbf59-sh6w4                4/4   Running            1 (94m ago)     121m
job7189-apps         storage-service-7c5dbcf785-rsjql                0/4   Init:0/3           0               20m
job7189-apps         workspace-service-74ff856ff5-pjhbj              0/4   Init:0/3           0               19m
job7189-apps         workspace-service-74ff96c877-fs6wb              4/4   Running            1 (95m ago)     121m
kube-system          cilium-operator-788c799db4-cv2c4                0/1   CrashLoopBackOff   4 (82s ago)     140m
kube-system          hubble-ui-67d8bff4c4-lpdpk                      2/2   Running            1 (3m45s ago)   140m
kube-system          kube-controller-manager-job7189-control-plane   0/1   Running            3 (35s ago)     141m
kube-system          kube-scheduler-job7189-control-plane            0/1   CrashLoopBackOff   2 (29s ago)     141m

Lease transitions (control-plane):
NAME                            T
kube-controller-manager         2
kube-scheduler                  2
cilium-operator-resource-lock   4
```
