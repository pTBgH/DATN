# 02 — Kiến trúc mục tiêu

## 1. Sơ đồ topology

```
┌────────────────────── Windows host (16 GB / 6 core) ──────────────────────┐
│                                                                            │
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────┐                 │
│  │  7189srv01  │  │   7189srv02     │  │   7189srv03     │                 │
│  │ (cp/master) │  │ (worker, 4.5 G) │  │ (worker, 5.0 G) │                 │
│  │  2.0 G/1c   │  │       2c        │  │       2c        │                 │
│  │             │  │                 │  │                 │                 │
│  │ tailscale0  │  │ tailscale0      │  │ tailscale0      │                 │
│  │ 100.64.10.1 │  │ 100.64.10.2     │  │ 100.64.10.3     │                 │
│  │ ens33 (NAT) │  │ ens33 (NAT)     │  │ ens33 (NAT)     │                 │
│  └──────┬──────┘  └─────────┬───────┘  └─────────┬───────┘                 │
│         │                   │                    │                         │
│         └───────────VMnet8 (NAT) ────────────────┘                         │
│                          │                                                  │
│                          v                                                  │
│                    Internet (image pull)                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                          │
                  Tailscale WireGuard (E2E encrypt)
                  100.64.0.0/10 — DERP relay khi cần
                          │
┌─────────────────────────v───────────────────────────────────────────────────┐
│                  Ubuntu host (8 GB / 4 core, DDR3)                          │
│                                                                             │
│            ┌──────────────────────────────────────┐                         │
│            │              7189srv04               │                         │
│            │       (worker, 6.0 G, 2 vCPU)        │                         │
│            │     "always-on" data + stateful      │                         │
│            │                                      │                         │
│            │   tailscale0  100.64.10.4            │                         │
│            │   ens33 (VMware NAT trên Ubuntu)     │                         │
│            └──────────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘

K8s plane: PodCIDR 10.244.0.0/16 (Cilium VXLAN tunnel qua tailscale0)
            ServiceCIDR 10.96.0.0/12
            apiserver advertise = 100.64.10.1 (Tailscale IP của srv01)
```

---

## 2. Vai trò từng VM

### 7189srv01 — control-plane

- **Pods**: kube-apiserver, etcd, kube-scheduler, kube-controller-manager,
  cilium-agent (DS), kube-proxy/cilium-DSR, coredns (1 trên 2 replica)
- **KHÔNG chạy**: workload thường (taint
  `node-role.kubernetes.io/control-plane:NoSchedule` giữ nguyên — không
  remove taint như kind setup). Tetragon DS có thể skip `7189srv01` (xem
  `10`).
- **Resource**: 2.0 GB / 1 vCPU. Có thể tăng lên 2.5 GB nếu etcd compaction
  hay bị memory pressure (xem `12-runbook-recovery.md`).

### 7189srv02 / 7189srv03 — generic worker (Windows)

- **Pods**: 7 Laravel apps (identity, workspace, job, hiring, candidate,
  communication, storage), Kong, Redis, ingress-nginx, oauth2-proxy,
  cert-manager (3), Keycloak (Deployment H2-in-memory, stateless),
  Grafana, Kibana, Hubble Relay/UI, Gatekeeper (2), sigstore
  policy-controller, PDP controller, Hubble shipper, kube-state-metrics,
  metrics-server, Cilium operator, coredns (replica 2).
- **Phân bổ**: K8s scheduler tự cân — KHÔNG nodeAffinity.
- **DS chạy trên cả 2**: cilium-agent, tetragon, spire-agent, filebeat,
  spiffe-csi-driver, node-exporter.

### 7189srv04 — data tier always-on (Ubuntu)

- **Pin nodeAffinity `kubernetes.io/hostname=7189srv04`**:
  - `vault-dev` (Transit engine, RAM-only — KHÔNG được restart)
  - `vault-prod` (StatefulSet, PVC 2 Gi)
  - MySQL (StatefulSet, PVC ~10 Gi)
  - Kafka (StatefulSet, PVC ~5 Gi)
  - Elasticsearch (StatefulSet, PVC ~25 Gi)
  - Prometheus (Deployment, PVC ~8 Gi)
  - SPIRE server (StatefulSet, PVC ~1 Gi)
  - in-cluster docker-registry (Deployment, PVC ~8 Gi)
- **DS chạy đầy đủ**: cilium-agent, tetragon, spire-agent, filebeat,
  spiffe-csi-driver, node-exporter.
- **Không pin** Hubble shipper / Filebeat shipper sink — DS tự đặt.

> **Lý do co-locate vault-dev + vault-prod**: vault-dev chạy `-dev mode`
> RAM-only và phục vụ Transit engine cho auto-unseal vault-prod
> (`doc/03-identity-layer.md` mục "Dual-Vault Architecture"). Pod restart
> = mất Transit key = vault-prod không tự unseal được. Đặt cả hai trên
> srv04 (always-on host) tối ưu uptime + giảm latency unseal call.

---

## 3. Workload placement matrix

| Workload | NS | NodeAffinity | Lý do |
|----------|-----|--------------|--------|
| etcd, apiserver, scheduler, ctrl-mgr | kube-system | control-plane (auto) | static pod trên srv01 |
| coredns | kube-system | (anywhere) | 2 replicas, K8s tự đặt |
| cilium-agent | kube-system | DS (mọi node) | — |
| cilium-operator | kube-system | (anywhere) | 1 replica, K8s tự đặt |
| metrics-server | kube-system | (anywhere) | — |
| cert-manager (3) | cert-manager | (anywhere) | — |
| ingress-nginx | ingress-nginx | (anywhere, ≥1) | NodePort 30001/30003 — Tailscale IP của node nào nhận thì client tới đó |
| **vault-dev** | **vault** | **`hostname=7189srv04`** | always-on, không restart |
| **vault-prod** | **vault** | **`hostname=7189srv04`** | PVC + co-locate vault-dev |
| **MySQL** | **data** | **`hostname=7189srv04`** | PVC stateful |
| **Kafka** | **data** | **`hostname=7189srv04`** | PVC stateful |
| Keycloak | security | (anywhere) | Deployment H2-in-memory, stateless |
| 7 Laravel apps | job7189-apps | (anywhere) | stateless |
| Kong | job7189-apps | (anywhere) | DB-less |
| Redis | job7189-apps | (anywhere) | session cache, có thể mất |
| oauth2-proxy | job7189-apps | (anywhere) | stateless |
| **Elasticsearch** | **monitoring** | **`hostname=7189srv04`** | PVC ~25 Gi |
| Kibana | monitoring | (anywhere) | stateless, gọi ES qua Service |
| **Prometheus** | **monitoring** | **`hostname=7189srv04`** | PVC TSDB |
| Grafana | monitoring | (anywhere) | stateless DB sqlite emptyDir |
| node-exporter | monitoring | DS | — |
| kube-state-metrics | monitoring | (anywhere) | stateless |
| Filebeat | monitoring | DS | đọc /var/log của node |
| Hubble Relay | kube-system | (anywhere) | stateless |
| Hubble UI | kube-system | (anywhere) | stateless |
| Hubble shipper (filebeat→ES) | monitoring | (anywhere) | gọi ES qua Service trên srv04 |
| **SPIRE server** | **spire** | **`hostname=7189srv04`** | sqlite PVC |
| SPIRE controller-manager | spire | (anywhere) | stateless |
| spire-agent | spire | DS | — |
| spiffe-csi-driver | spire | DS | — |
| Tetragon | kube-system | DS (skip srv01 — option) | eBPF kernel hooks |
| Gatekeeper (2) | gatekeeper-system | (anywhere) | webhook stateless |
| sigstore policy-controller | cosign-system | (anywhere) | webhook stateless |
| PDP controller | zta-pdp | (anywhere) | Python kopf, stateless |
| **docker-registry** | **registry** | **`hostname=7189srv04`** | PVC images |

---

## 4. Failover behavior

| Sự kiện | Tác động |
|---------|----------|
| `7189srv01` chết | Cluster control-plane DOWN. Workload pods vẫn chạy nhưng không scale, không reschedule, kubectl không respond. Recover: power-on lại, hoặc restore từ etcd snapshot. |
| `7189srv02` chết | K8s scheduler reschedule các stateless pod sang srv03 / srv04. Stateful pod (nếu vô tình nằm srv02 — không nên xảy ra) sẽ Pending. |
| `7189srv03` chết | Tương tự srv02. |
| `7189srv04` chết | **Cụm mất tất cả data**: vault-prod sealed, MySQL down, Kafka down, ES down, registry down → 7 Laravel apps fail healthcheck. Recover: power-on srv04, vault-prod auto-unseal khi vault-dev sống, MySQL/Kafka/ES tự bind lại PVC. |
| Tailscale rớt | Tất cả node mất kết nối — apiserver bind 100.64.10.1 không reach được. K8s restart liên tục. Recover: `tailscale up --auth-key=...` lại. |
| Windows host crash | 3 VM (srv01-03) đồng thời chết → cluster control-plane DOWN. srv04 (Ubuntu) vẫn sống nhưng vô dụng. |
| Ubuntu host crash | srv04 chết → mất data (xem trên). |

---

## 5. Rationale các quyết định lớn

1. **Tách control-plane ra `7189srv01` riêng**: tránh trường hợp Kind cũ
   nơi etcd + apiserver + workload chung 1 kernel → Tetragon eBPF buffer
   ăn RAM kéo etcd OOM (incident #1).
2. **Giữ workload stateless trên Windows host**: Windows host có RAM
   nhiều hơn (16 GB), CPU nhiều hơn (6 core) — phù hợp chạy 7 Laravel +
   Kong + Tetragon DS.
3. **Pin tất cả stateful lên Ubuntu host**: Ubuntu host được user ít tắt
   → data tier có uptime cao nhất. Trade-off: nếu Ubuntu host crash thì
   mất tất cả data, nhưng đó là rủi ro chấp nhận được cho thesis env.
4. **Không tier-based affinity cho stateless**: K8s scheduler đã đủ
   thông minh (LeastAllocated, NodeResourcesFit). Affinity thừa chỉ làm
   khó scheduler — và khi srv02 chết, các pod stateless sẽ pile-up trên
   srv03 / srv04 thay vì stuck Pending.

---

## 6. Open questions

1. HA control-plane? — KHÔNG (tài nguyên không đủ cho 3 cp). Single cp +
   etcd snapshot daily là đủ.
2. ClusterMesh (cilium multi-cluster)? — KHÔNG. Đây là 1 cluster duy
   nhất, multi-VM.
3. MetalLB? — KHÔNG. ingress-nginx NodePort 30001/30003 là đủ. Khi cần
   external IP, dùng Tailscale IP của bất kỳ worker nào (Funnel optional).
