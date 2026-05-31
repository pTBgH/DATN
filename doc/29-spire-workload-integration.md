# 29. SPIRE Workload Integration — consume SVID via Workload API

PR #20 — Step 2.3.10. Lifts CISA ZTMM **Devices: Advanced → Optimal**.

## 1. Bối cảnh

PR #17 đã cài SPIRE và **issue** SVIDs (44 entries). Nhưng workload vẫn xài long-lived ServiceAccount tokens chứ chưa consume SVID. Identity-as-trust mới chỉ là 1 phần — phần còn lại là phải có pod thực sự dùng SVID.

PR #20 demo workload integration thực: 1 pod mount `csi.spiffe.io` ephemeral volume, gọi Workload API qua Unix socket, nhận SVID PEM, log ra stdout. Đó là chu trình end-to-end **node attestation → workload attestation → SVID consumption**.

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ Node-A (kind-job7189-worker)                                         │
│                                                                      │
│  ┌────────────────────┐  hostPath socket  ┌──────────────────────┐  │
│  │ spire-agent (DS)   ◄───────────────────│ spiffe-csi-driver    │  │
│  │ - node attestation │   /run/spire/    │ - mounts socket as    │  │
│  │ - workload attest. │    agent.sock     │   ephemeral CSI vol   │  │
│  │ - SVID issuer      │                   │   into target pod     │  │
│  └────────────────────┘                   └──────────┬───────────┘  │
│         ▲                                            │ csi.spiffe.io│
│         │ workload API gRPC                          │              │
│         │                                            ▼              │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Pod: spire-demo-workload                                    │   │
│  │   container: spiffe-helper                                   │   │
│  │     mount: /spiffe-workload-api  (csi: csi.spiffe.io)        │   │
│  │     image: ghcr.io/spiffe/spiffe-helper:0.8.0                │   │
│  │     daemon watches Workload API + writes PEM files:          │   │
│  │       /svids/svid.crt    (X.509 cert PEM)                    │   │
│  │       /svids/svid.key    (private key PEM)                   │   │
│  │       /svids/bundle.crt  (trust bundle PEM)                  │   │
│  │     SPIFFE ID issued:                                        │   │
│  │       spiffe://zta.job7189/ns/security/sa/                   │   │
│  │                                spire-demo-workload           │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## 3. Workload attestation flow

1. Pod khởi động, kubelet binds CSI volume (host: `/run/spire/agent-sockets/<node>` → pod: `/spiffe-workload-api`).
2. spiffe-helper daemon mở Workload API socket `/spiffe-workload-api/spire-agent.sock` và subscribe `WatchX509SVID` gRPC stream.
3. spire-agent (CSI side) attest **caller** bằng selectors:
   - `k8s:pod-uid:<UID>`
   - `k8s:ns:<namespace>`
   - `k8s:sa:<service-account>`
   - `k8s:pod-label:app=spire-demo-workload`
4. spire-agent forward request lên spire-server với selectors.
5. spire-server tra entry có matching selectors → issue X.509 SVID + chain.
6. spire-agent push SVID về spiffe-helper qua stream.
7. spiffe-helper write `/svids/svid.crt`, `/svids/svid.key`, `/svids/bundle.crt` + log line.

## 4. ClusterSPIFFEID rule

```yaml
apiVersion: spire.spiffe.io/v1alpha1
kind: ClusterSPIFFEID
metadata:
  name: zta-spire-demo-workload
spec:
  spiffeIDTemplate: "spiffe://zta.job7189/ns/{{ .PodMeta.Namespace }}/sa/{{ .PodSpec.ServiceAccountName }}"
  podSelector:
    matchLabels:
      app: spire-demo-workload
  namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: security
```

spire-controller-manager watches this rule, sees demo pod, register entry với spire-server. Quy trình tự động — không cần `spire-server entry create` thủ công.

## 5. Pod spec (key parts)

```yaml
spec:
  serviceAccountName: spire-demo-workload
  automountServiceAccountToken: false   # không dùng SA token — chỉ SVID
  containers:
  - name: spiffe-helper
    image: ghcr.io/spiffe/spiffe-helper:0.8.0
    args: ["-config", "/etc/spiffe-helper/helper.conf"]
    volumeMounts:
    - name: spiffe-workload-api
      mountPath: /spiffe-workload-api
      readOnly: true
    - name: svids
      mountPath: /svids                # SVID PEM files written here
  volumes:
  - name: spiffe-workload-api
    csi:
      driver: csi.spiffe.io            # provided by spiffe-csi-driver DS (PR #17)
      readOnly: true
  - name: svids
    emptyDir: {}
```

Lưu ý:
- `automountServiceAccountToken: false` chứng minh pod không cần SA token để authenticate — **toàn bộ identity nằm ở SVID**.
- Image **distroless** `ghcr.io/spiffe/spire-agent` không có `/bin/sh`, nên ta dùng [`spiffe-helper`](https://github.com/spiffe/spiffe-helper) — daemon chính thức của SPIFFE để consume SVID, có shell + helper logic + auto-rotate.

## 6. SVID rotation

X.509 SVIDs expire (default 1h, có thể tune trong helm values). spire-agent tự động push SVID mới qua stream khi 50% TTL còn lại. spiffe-helper observe và overwrite các file PEM. Logs:

```
time=...  msg="X.509 SVID updated"  spiffe_id="spiffe://zta.job7189/ns/security/sa/spire-demo-workload"
time=...  msg="SVID file written"   path=/svids/svid.crt
```

Verify rotation by inspecting cert lifetime in pod:
```bash
kubectl -n security exec deploy/spire-demo-workload -- \
  cat /svids/svid.crt | openssl x509 -text -noout | grep -E "Not (Before|After)|Subject:"
# Subject sẽ chứa URI:spiffe://zta.job7189/ns/security/sa/spire-demo-workload
```

## 7. Triển khai

```bash
# Prerequisite: PR #17 (SPIRE) deployed
bash scripts/zta-spire-onboard-demo.sh

# Verify
kubectl -n security logs deploy/spire-demo-workload --tail=10 | grep -i svid
kubectl -n security exec deploy/spire-demo-workload -- ls -la /svids/

# Inspect SPIRE entry
kubectl -n spire exec statefulset/spire-server -c spire-server -- \
  /opt/spire/bin/spire-server entry show \
  -socketPath /tmp/spire-server/private/api.sock 2>&1 \
  | grep -A3 "sa/spire-demo-workload"

# Run Test 4k
bash 09-verify-zta.sh | grep "Test 4k" -A 12
```

## 8. CISA ZTMM mapping

| Devices stage | Trước (PR #17) | Sau (PR #20) |
|---|---|---|
| Initial | ❌ | ❌ |
| Traditional | issue SVID via SPIRE | ✅ |
| Advanced | controller-manager auto-register pods | ✅ |
| **Optimal** | workload thực sự **consume** SVID via Workload API + automountServiceAccountToken=false | ✅ |

## 9. Resource budget

| Component | RAM req/limit | CPU req/limit | Replicas |
|---|---|---|---|
| spire-demo-workload | 24/64 Mi | 10m/50m | 1 |

Negligible — chỉ là demo workload.

## 10. Roadmap mở rộng

PR #20 chỉ deploy demo. Production roadmap:
- **PR #20a**: Onboard PDP Controller (PR #15) — thay SA token với SVID, dùng SPIRE OIDC discovery provider để Vault accept SVID JWT.
- **PR #20b**: Onboard Kong Gateway — verify upstream client SVID instead of mTLS PSK.
- **PR #20c**: Onboard ZTA microservices (job7189-apps) — apps gọi internal services qua spiffe-helper sidecar, switch from SA token → SVID.

Mỗi onboarding cần code change phía app (sử dụng spiffe-go SDK hoặc spiffe-helper). Đó là công việc nhiều PR sau, không phải scope PR #20.

## 11. Limitations

- Demo pod chỉ fetch SVID, không sử dụng cho mTLS thực. mTLS use-case đòi hỏi SPIRE SDK trong app code.
- ClusterSPIFFEID rule trong PR #17 đã cover `security` ns, demo rule là dư redundant — có vì bằng chứng PR-isolation.
- SVID JWT chưa demo (chỉ X.509). JWT-SVID hữu ích cho HTTP authn — sẽ làm trong PR onboarding cụ thể.
