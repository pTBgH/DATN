# 02. Target Architecture — Topology mới

## 1. Sơ đồ vật lý + logic

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Internet (DERP relay của Tailscale)                                    │
│         ▲                          ▲                                    │
│         │ tailscale (WG)           │ tailscale (WG)                     │
│         │                          │                                    │
│  ┌──────┴───────────────────┐   ┌──┴───────────────────────────────┐    │
│  │ Host 1: Windows (16 GB)  │   │ Host 2: Ubuntu desktop (8 GB)    │    │
│  │  - VMware Workstation    │   │  - VMware Workstation            │    │
│  │  - Tailscale on host?    │   │  - Tailscale on host?            │    │
│  │     (no — chỉ trong VM)  │   │     (no — chỉ trong VM)          │    │
│  │                          │   │                                  │    │
│  │  ┌─VMnet8 (NAT) 192.168.X/24─┐ │ ┌─VMnet8 (NAT) 192.168.Y/24──┐  │    │
│  │  │                          │ │ │                            │  │    │
│  │  │  cp1 VM (Debian 12)      │ │ │  w-obs VM (Debian 12)      │  │    │
│  │  │  ┌──────────────────┐    │ │ │  ┌──────────────────┐      │  │    │
│  │  │  │ ens33 (NAT)      │    │ │ │  │ ens33 (NAT)      │      │  │    │
│  │  │  │ tailscale0 100.64.10.1   │ │  │ tailscale0 100.64.10.4   │      │
│  │  │  │ kubelet, etcd,   │    │ │ │  │ kubelet, ELK,    │      │  │    │
│  │  │  │ apiserver, ctrl  │    │ │ │  │ Tetragon, SPIRE, │      │  │    │
│  │  │  │ scheduler, cilium│    │ │ │  │ Gatekeeper, PDP, │      │  │    │
│  │  │  └──────────────────┘    │ │ │  │ Hubble export    │      │  │    │
│  │  │                          │ │ │  └──────────────────┘      │  │    │
│  │  │  w-data VM (Debian 12)   │ │ │                            │  │    │
│  │  │  ┌──────────────────┐    │ │ │                            │  │    │
│  │  │  │ tailscale0 100.64.10.2   │ │  │                          │  │    │
│  │  │  │ MySQL, Vault,    │    │ │ │                            │  │    │
│  │  │  │ Keycloak, Kafka  │    │ │ │                            │  │    │
│  │  │  └──────────────────┘    │ │ │                            │  │    │
│  │  │                          │ │ │                            │  │    │
│  │  │  w-apps VM (Debian 12)   │ │ │                            │  │    │
│  │  │  ┌──────────────────┐    │ │ │                            │  │    │
│  │  │  │ tailscale0 100.64.10.3   │ │  │                          │  │    │
│  │  │  │ 7 Laravel,       │    │ │ │                            │  │    │
│  │  │  │ Kong, Redis,     │    │ │ │                            │  │    │
│  │  │  │ ingress-nginx,   │    │ │ │                            │  │    │
│  │  │  │ in-cluster reg.  │    │ │ │                            │  │    │
│  │  │  └──────────────────┘    │ │ │                            │  │    │
│  │  └──────────────────────────┘ │ └────────────────────────────┘  │    │
│  └──────────────────────────────┘ └─────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

> Tailscale IP `100.64.10.x` là placeholder. Tailscale tự cấp; bạn ghi
> chú lại thật trong `/etc/hosts` hoặc set MagicDNS hostname.

## 2. Vai trò từng VM

### `cp1` — Control Plane

| Pod | NS | RAM req / lim |
|-----|-----|---------------|
| kube-apiserver | kube-system | 700/1024 Mi |
| etcd | kube-system | 256/512 Mi |
| kube-controller-manager | kube-system | 256/384 Mi |
| kube-scheduler | kube-system | 192/256 Mi |
| coredns × 2 | kube-system | 70/170 Mi |
| metrics-server | kube-system | 50/100 Mi |
| cilium-operator | kube-system | 128/256 Mi |
| cilium-agent (DS, mỗi node) | kube-system | 128/256 Mi |
| **Subtotal** | | **~1.7 / 2.9 GiB** |

VM size: **2.0 GB** RAM (sát nhưng sẽ tune kubelet `--system-reserved`
+ `--kube-reserved` để eviction conservative). Nếu quá sát → bump lên
2.5 GB và giảm `w-data` xuống 4.5 GB.

NoSchedule taint: `node-role.kubernetes.io/control-plane:NoSchedule`
giữ nguyên — chỉ apiserver/etcd/scheduler chạy ở đây.

### `w-data` — Data tier

| Pod | NS | RAM req / lim |
|-----|-----|---------------|
| MySQL | data | 256/512 Mi |
| Kafka (single broker) | data | 256/512 Mi |
| Vault prod | vault | 256/512 Mi |
| Vault dev (transit) | vault | 128/256 Mi |
| Vault agent injector | vault | 64/128 Mi |
| Keycloak | security | 512/1024 Mi |
| cilium-agent | kube-system | 128/256 Mi |
| filebeat (DS) | monitoring | 100/200 Mi |
| **Subtotal** | | **~1.7 / 3.4 GiB** |

VM size: **5.0 GB** RAM (limits có thể bù trên swap nhưng nên đủ).

Pinning: PVC của MySQL/Vault/Kafka neo vào VM này qua local-path-provisioner
(xem `05-storage-and-registry.md`). NodeSelector + nodeAffinity bằng label
`zta.workload.tier=data`.

### `w-apps` — Application tier

| Pod | NS | RAM req / lim |
|-----|-----|---------------|
| 7 Laravel × 4 container/pod | job7189-apps | 1.3/3.9 GiB |
| Redis (shared) | job7189-apps | 64/192 Mi |
| Kong DB-less | gateway | 128/256 Mi |
| oauth2-proxy | security | 32/64 Mi |
| ingress-nginx | ingress-nginx | 90/256 Mi |
| In-cluster docker-registry | registry | 256/512 Mi |
| cert-manager × 3 | cert-manager | 64×3 / 128×3 Mi |
| cilium-agent | kube-system | 128/256 Mi |
| filebeat (DS) | monitoring | 100/200 Mi |
| **Subtotal** | | **~2.4 / 5.7 GiB** |

VM size: **4.5 GB** RAM. Nếu Laravel limits căng hơn dự kiến (PHP-FPM hot
runs, OPcache), tăng lên 5.0 GB và bù bằng cách giảm `cp1` headroom.

### `w-obs` — Observability + Security tier (Ubuntu host)

| Pod | NS | RAM req / lim |
|-----|-----|---------------|
| Elasticsearch single-node | monitoring | 384/768 Mi |
| Kibana | monitoring | 256/512 Mi |
| Prometheus | monitoring | 256/512 Mi |
| Grafana | monitoring | 256/512 Mi |
| node-exporter (DS) | monitoring | 32/64 Mi |
| kube-state-metrics | monitoring | 32/64 Mi |
| Tetragon DS | kube-system | 256/384 Mi |
| Tetragon-operator | kube-system | 64/128 Mi |
| Gatekeeper controller-manager | gatekeeper-system | 256/384 Mi |
| Gatekeeper audit | gatekeeper-system | 256/384 Mi |
| SPIRE server | spire | 256/512 Mi |
| SPIRE controller-manager | spire | 192/256 Mi |
| SPIRE agent (DS) | spire | 128/256 Mi |
| spiffe-csi-driver (DS) | spire | 64/128 Mi |
| sigstore policy-controller | cosign-system | 192/256 Mi |
| PDP controller | security | 128/256 Mi |
| Hubble exporter shipper | kube-system | 100/200 Mi |
| cilium-agent | kube-system | 128/256 Mi |
| filebeat (DS) | monitoring | 100/200 Mi |
| **Subtotal** | | **~3.3 / 6.0 GiB** |

VM size: **6.0 GB** RAM. Đây là VM nặng nhất — ELK + 2 eBPF stack
(Cilium agent + Tetragon DS) + Gatekeeper + SPIRE.

## 3. Pod placement strategy

Không dùng nodeSelector cứng cho mọi pod (chế độ hard-affinity dễ làm
scheduler bí). Thay vào đó:

1. **Label node** sau khi join:
   ```
   kubectl label node cp1     zta.workload.tier=control-plane
   kubectl label node w-data  zta.workload.tier=data
   kubectl label node w-apps  zta.workload.tier=apps
   kubectl label node w-obs   zta.workload.tier=observability
   ```
2. **Soft preferred affinity** trong manifest của workload:
   - MySQL/Vault/Kafka/Keycloak → prefer `tier=data`
   - 7 Laravel + Kong → prefer `tier=apps`
   - ELK/Tetragon/SPIRE/Gatekeeper → prefer `tier=observability`
3. **DaemonSet (cilium, filebeat, node-exporter, tetragon, spire-agent,
   spiffe-csi-driver)** chạy trên **mọi worker** (loại trừ cp1 bằng
   tolerations chỉ cho node có taint role).

## 4. Map sang ZTA layer (xem `doc/02-architecture-layers.md`)

| Lớp ZTA | Component chính | VM |
|---------|----------------|----|
| L1 Identity (User) | Keycloak | w-data |
| L1 Identity (Workload) | SPIRE + Cilium mesh-auth | w-obs (server), all workers (agent) |
| L2 Posture | Trivy, Threat Intel | w-obs |
| L3 PEP North-South | Kong + Nginx | w-apps |
| L3 PEP East-West | Cilium | tất cả |
| L3 PEP Runtime | Tetragon | w-obs (DS chạy ở cả 4 nhưng "owner" là w-obs) |
| L3 Admission | Gatekeeper, sigstore | w-obs |
| L4 Secrets | Vault dual | w-data |
| L5 Logs | Elasticsearch + Kibana + Filebeat | w-obs |
| L5 Metrics | Prometheus + Grafana | w-obs |
| L5 Network flows | Hubble Relay/UI + exporter | tất cả (Relay), w-obs (exporter sink) |

## 5. Failover behavior

| Sự cố | Triệu chứng | Ảnh hưởng | Recovery |
|-------|-------------|-----------|----------|
| VM `cp1` chết | apiserver unreachable | Toàn bộ kubectl fail. Pod đang chạy vẫn OK, không reschedule được. | Khởi động lại VM. etcd self-heal sau khi up. |
| VM `w-data` chết | MySQL/Vault offline | App layer 5xx. | Khởi động lại VM. PVC re-mount, app retry. |
| VM `w-apps` chết | Frontend/API 502 | Demo down. | Khởi động lại. |
| VM `w-obs` chết | Mất logs + alerts. Tetragon TracingPolicy không enforce trên các node? | Cilium mesh-auth vẫn OK (agent local). Tetragon agent local trên các node khác vẫn bắt syscall, chỉ mất pod tetragon-operator + log sink. | Khởi động lại. |
| Tailscale rớt giữa 2 host | cross-host pod-to-pod 100% drop | Pod cùng host vẫn OK. Hubble drop count tăng. | `tailscale up --reset` trên VM mất kết nối. |
| Cả Windows host crash | 3 VM (cp1 + w-data + w-apps) chết | Cluster mất quorum. | Reboot Windows host, các VM auto-start nếu set "Power on this VM when the host starts". |

## 6. Câu hỏi mở liên quan

- **HA cho cp1?** Hiện chỉ 1 control-plane. Single-point-of-failure.
  Để HA cần thêm 2 cp nữa (3 etcd) và LB ảo (kube-vip) — quá nặng cho
  20.8 GB ngân sách. Chấp nhận single cp, viết plan recovery khi cp chết
  (xem `12-runbook-recovery.md`).
- **Cilium ClusterMesh hoặc kube-vip?** Không cần ở giai đoạn này.
- **Có cần MetalLB không?** Hiện đang publish service qua NodePort + map
  Tailscale Funnel/Serve cho external access. Nếu user cần `LoadBalancer`
  type Service tự động cấp IP, thêm MetalLB vào w-apps về sau.
