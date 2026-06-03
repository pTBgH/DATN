# 27. SPIRE Workload Attestation (PR #17)

> **Status:** Step 2.3.8 — Phase 4 ZTA. Issues short-lived cryptographic identities (SVIDs) to every ZTA-labeled workload, replacing long-lived ServiceAccount tokens.

## 1. Mục đích

Thay **ServiceAccount tokens** (long-lived, không cryptographic, dễ leak) bằng **SPIFFE Verifiable Identity Documents (SVIDs)** — X.509 certificates ngắn hạn (15 phút – 1 giờ) gắn unique SPIFFE ID cho từng workload.

CISA ZTMM Devices pillar:
- Trước PR #17: **Initial** — host-based identity, không có MDM/EDR
- Sau PR #17: **Advanced** — workload-level cryptographic attestation, identity rotates tự động, không có shared secret

## 2. Threat model — vấn đề SA token

| Attack | SA token weakness | SPIRE mitigation |
|---|---|---|
| Token leak qua log | SA token là JWT có lifespan vô hạn (until pod delete) | SVID rotate 15-60 min, leaked SVID hết hạn ngay |
| Container compromise | Attacker đọc `/var/run/secrets/kubernetes.io/serviceaccount/token` → call apiserver | SVID requires Workload API socket call, attestation kiểm node + pod metadata |
| Lateral movement với token | 1 token → many APIs | SVID gắn cụ thể `spiffe://<td>/ns/<ns>/sa/<sa>`, downstream service kiểm SAN matching policy |
| Token replay sau bị evict | SA token vẫn valid sau khi pod chết | SVID renewal phải re-attest, fail nếu pod biến mất |

## 3. SPIFFE concepts

| Term | Định nghĩa |
|---|---|
| **SPIFFE ID** | URI dạng `spiffe://<trust-domain>/<path>` — unique cho từng workload |
| **SVID** | X.509 cert (X509-SVID) hoặc JWT (JWT-SVID) signed bởi spire-server |
| **Trust Domain** | Tên duy nhất của 1 cluster/realm: `zta.job7189` |
| **Workload Attestation** | spire-agent verify pod metadata (UID, labels, SA, image digest) trước khi cấp SVID |

## 4. Trust domain & SPIFFE ID schema

| Workload tier | SPIFFE ID template | TTL |
|---|---|---|
| **Default (T2)** | `spiffe://zta.job7189/ns/<ns>/sa/<sa>` | Helm default ~30 min |
| **T1 sensitive** (vault, security) | `spiffe://zta.job7189/tier1/ns/<ns>/sa/<sa>` | 60 min (less churn) |
| **T3 internet-exposed** (gateway, frontend) | `spiffe://zta.job7189/tier3/ns/<ns>/sa/<sa>` | 15 min (rotate fast = small blast radius) |

## 5. Kiến trúc

```
                  ┌──────────────────────────────────────┐
                  │         spire-server (StatefulSet)   │
                  │  - CA cho trust domain zta.job7189   │
                  │  - SQLite trust bundle on PVC        │
                  │  - gRPC API :8081 (intra-cluster)    │
                  └──────────────────┬───────────────────┘
                                     │ attest + sign SVID
                  ┌──────────────────┼───────────────────┐
                  │                  │                   │
        ┌─────────▼────┐  ┌──────────▼─────┐  ┌──────────▼─────┐
        │ Node 1       │  │ Node 2         │  │ Node 4         │
        │ spire-agent  │  │ spire-agent    │  │ spire-agent    │
        │  Workload    │  │  Workload      │  │  Workload      │
        │  API socket  │  │  API socket    │  │  API socket    │
        │  (hostPath)  │  │  (hostPath)    │  │  (hostPath)    │
        └─────┬────────┘  └────────┬───────┘  └────────┬───────┘
              │                    │                   │
       ┌──────▼─────┐      ┌───────▼──────┐    ┌───────▼──────┐
       │ pod A      │      │ pod B        │    │ pod C        │
       │ identity-  │      │ vault-agent  │    │ kong-proxy   │
       │ service    │      │              │    │              │
       │ ↑ SVID     │      │ ↑ SVID       │    │ ↑ SVID       │
       └────────────┘      └──────────────┘    └──────────────┘
       
                  ┌────────────────────────────────────┐
                  │ spire-controller-manager           │
                  │  - watch ClusterSPIFFEID CRD       │
                  │  - watch Pod resources             │
                  │  - register entries với spire-svr  │
                  └────────────────────────────────────┘
```

## 6. Cách triển khai

```bash
# 1. (Optional) Free RAM trước nếu cluster đang chật
bash scripts/free-ram-for-tetragon.sh

# 2. Deploy SPIRE
bash scripts/zta-deploy-spire.sh

# 3. Verify
kubectl -n spire get pod
kubectl get clusterspiffeid

# 4. Liệt kê SVIDs đã cấp
kubectl -n spire exec statefulset/spire-server -c spire-server -- \
  /opt/spire/bin/spire-server entry show \
  -socketPath /tmp/spire-server/private/api.sock

# 5. Test mounting Workload API socket vào 1 pod (qua spiffe-csi-driver)
# spec.volumes:
# - name: spiffe-workload-api
#   csi:
#     driver: csi.spiffe.io
#     readOnly: true
# spec.containers[*].volumeMounts:
# - name: spiffe-workload-api
#   mountPath: /spiffe-workload-api
#   readOnly: true
```

## 7. Verify (Test 4i)

```bash
bash 09-verify-zta.sh | grep "Test 4i" -A 12
```

Mong đợi:
```
   ✅ PASS: spire-server StatefulSet Ready (1/1)
   ✅ PASS: spire-agent DaemonSet covers all nodes (4/4)
   ✅ PASS: ClusterSPIFFEID rules registered (3 total)
   ✅ PASS: SPIRE entries issued (10+ SVIDs registered for ZTA workloads)
   ✅ PASS: SPIRE trustDomain = 'zta.job7189' (matches knowledge-base/27)
```

## 8. Resource budget (4-node Kind)

| Component | CPU req/limit | RAM req/limit | Replicas | Total RAM |
|---|---|---|---|---|
| spire-server | 100m / 300m | 192Mi / 384Mi | 1 | 192-384Mi |
| spire-agent | 50m / 200m | 96Mi / 192Mi | 4 (DS) | 384-768Mi |
| spire-controller-manager | 50m / 200m | 96Mi / **256Mi** | 1 | 96-256Mi |
| spiffe-csi-driver | 20m / 100m | 32Mi / 64Mi | 4 (DS) | 128-256Mi |
| **Tổng** | ~400m / ~1.4 | ~800Mi / ~1.7Gi | — | **~800Mi-1.7Gi** |

> Cập nhật PR #24: `controllerManager.resources.limits.memory` đã được nâng từ
> 192Mi → 256Mi vì controller bị OOM-killed khi reconcile 11+ ClusterSPIFFEID
> ở thời điểm boot. Đồng thời nới `livenessProbe.initialDelaySeconds` 30→60s
> và `readinessProbe.initialDelaySeconds` 10→20s để chart không flap pods
> trước khi controller xây xong cache.
>
> Pre-flight cluster: `scripts/zta-deploy-spire.sh` từ chối install nếu node
> nào có <450Mi free RAM. Bypass: `ZTA_RAM_CHECK_FATAL=0` hoặc set
> `SPIRE_REQUIRED_NODE_MI=200`.
>
> Recovery: `bash scripts/zta-deploy-spire.sh --reset` (deployed-but-broken)
> hoặc `--uninstall && deploy lại` (orphan pod / PVC corrupt). Xem `32`.

## 9. CISA ZTMM mapping

| Pillar | Function | Trước PR #17 | Sau PR #17 |
|---|---|---|---|
| **Devices** | Authentication | Initial — host-based, no cert mgmt | **Advanced** — workload-level X.509 SVID, auto-rotated |
| Identity | Continuous evaluation | Optimal (PDP PR #15) | unchanged |
| Networks | Microsegmentation | Advanced+ (Cilium) | unchanged |
| Applications | Continuous deployment | Advanced (PR #16 image trust) | unchanged |
| Data | At-rest protection | Advanced (Vault tmpfs) | unchanged |

## 10. Limitations & roadmap

- **Workload code chưa dùng SVID**: PR #17 chỉ cấp SVID, chưa modify code microservice để consume Workload API. Future PR:
  - Sidecar pattern: spiffe-helper hoặc go-spiffe library
  - Service mesh: Istio integration với SPIRE (replace Citadel CA)
- **mTLS handshake**: Cilium mTLS hiện dùng identity của Cilium chứ không phải SPIFFE. Future: Cilium Hubble + SPIRE Federation.
- **Federation**: Multi-cluster SPIFFE trust bundle exchange chưa setup. Single-cluster only.
- **OIDC**: spiffe-oidc-discovery-provider disabled — turn on khi cần JWT-SVID cho external services (e.g. AWS IAM).
- **No CNP**: namespace `spire` chưa có default-deny CNP. Để consistent với 7 ZTA ns, future PR thêm:
  - default-deny-spire
  - allow-spire-internal (agent ↔ server)
  - allow-spire-apiserver-egress (controller-manager → apiserver)

## 11. Tham chiếu

- SPIFFE/SPIRE: https://spiffe.io/docs/latest/
- Helm charts hardened: https://github.com/spiffe/helm-charts-hardened
- ClusterSPIFFEID CRD: https://github.com/spiffe/spire-controller-manager/blob/main/docs/clusterspiffeid-crd.md
- CISA ZTMM 2.0 — Devices pillar
- NIST SP 800-204D — workload identity in zero-trust architectures
