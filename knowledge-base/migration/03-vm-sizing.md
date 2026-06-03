# 03 — VM sizing

> **State as of 2026-05-13** — the data-tier node `7189srv04` (Ubuntu host
> on libvirt **NAT**) has been replaced by `7189srv05` (Ubuntu 24.04 LTS
> on libvirt **bridge**) because the libvirt default-NAT inside ISP CGNAT
> caused Tailscale `MappingVariesByDestIP=true` → no direct P2P → DERP
> relay saturation → cluster instability. See
> [transition-srv04-to-srv05.md](transition-srv04-to-srv05.md) and
> [incident-srv04-tailscale-derp-2026-05-13.md](incident-srv04-tailscale-derp-2026-05-13.md)
> for the full story. Below `7189srv04` mentions have been updated to
> `7189srv05` where they describe **current** state; historical
> references inside incident reports keep `7189srv04` as evidence.


## 1. Ngân sách host

| Host | Total | Allocatable cho VMs | Lý do giảm |
|------|-------|---------------------|-------------|
| Windows (16 GB / 6 core) | 16 GB / 6 vCPU | **12.8 GB / 5 vCPU** | 3.2 GB cho Windows + VMware overhead, giữ 1 core cho host UI |
| Ubuntu (8 GB / 4 core, DDR3) | 8 GB / 4 vCPU | **4.0 GB / 2 vCPU** | User cần ≥4 GB cho host (browser, IDE, các app khác) — chỉ allocate 4 GB cho VM. Giảm 3→2 vCPU vì CPU cũ. |

Tổng ngân sách: 16.8 GB / 7 vCPU dành cho VM. Plan dưới đây dùng
**15.5 GB / 7 vCPU** (headroom 1.3 GB).

> **Cập nhật 2026-05-10**: srv04 giảm từ 6 GB → 4 GB theo yêu cầu user
> (Ubuntu host cần thêm RAM cho app khác). Workload trên srv04 trim
> tương ứng — xem §3 dưới.

---

## 2. Sizing chi tiết

| VM | Host | RAM | vCPU | Disk | Vai trò |
|----|------|-----|------|------|---------|
| `7189srv01` | Windows | **2.0 GB** | 1 | 40 GB ext4 | control-plane only |
| `7189srv02` | Windows | **4.5 GB** | 2 | 50 GB ext4 | generic worker |
| `7189srv03` | Windows | **5.0 GB** | 2 | 50 GB ext4 | generic worker |
| `7189srv05` | Ubuntu  | **4.0 GB** | 2 | 60 GB ext4 | data tier always-on (RAM-trimmed) |
| **Sum** |  | **15.5 GB** | **7** | **200 GB** | |

> **Disk thin-provisioned** (VMware tùy chọn `Allocate all disk space now=No`).
> Giúp 4 VM tổng 220 GB GHI THỰC TẾ chỉ ~50 GB ban đầu.

---

## 3. Workload RAM estimate per VM

### 7189srv01 (2.0 GB)

| Component | req | limit |
|-----------|-----|-------|
| etcd | 100 Mi | 200 Mi |
| kube-apiserver | 256 Mi | 512 Mi |
| kube-scheduler | 50 Mi | 128 Mi |
| kube-controller-manager | 100 Mi | 256 Mi |
| coredns | 70 Mi | 170 Mi |
| cilium-agent (DS) | 128 Mi | 256 Mi |
| kubelet/containerd reserved | 200 Mi | — |
| OS Debian 13 reserved | ~250 Mi | — |
| **Total** | **~1.15 GB** | **~1.55 GB** |

Headroom 850 MB cho spike (etcd compaction, leader election storm).

### 7189srv02 (4.5 GB)

K8s scheduler tự đặt — ước tính chiếm:

| Component | req | limit |
|-----------|-----|-------|
| Cilium agent (DS) | 128 Mi | 256 Mi |
| Tetragon (DS) | 256 Mi | 384 Mi |
| Filebeat (DS) | 100 Mi | 200 Mi |
| spire-agent (DS) | 64 Mi | 128 Mi |
| spiffe-csi-driver (DS) | 64 Mi | 128 Mi |
| node-exporter (DS) | 32 Mi | 64 Mi |
| 3-4 Laravel apps | ~600 Mi | ~1.6 GB |
| Kong + ingress + cert-manager | ~400 Mi | ~800 Mi |
| Kibana hoặc Grafana hoặc Hubble Relay | ~256 Mi | ~512 Mi |
| Cilium operator hoặc Gatekeeper hoặc PDP | ~128 Mi | ~256 Mi |
| OS Debian 13 reserved | ~300 Mi | — |
| **Total** | **~2.3 GB** | **~4.2 GB** |

Headroom 300 MB. Bookkeep: K8s scheduler dùng request, không limit.

### 7189srv03 (5.0 GB)

Tương tự srv02, có thể chứa thêm 3-4 Laravel + Keycloak (~512 Mi) hoặc
Hubble UI + Gatekeeper. Tổng ~2.6 GB req / ~4.6 GB limit. Headroom
400 MB.

### 7189srv05 (4.0 GB, Ubuntu 24.04 LTS, libvirt **bridge**) — **RAM-trimmed profile**

> Vì chỉ 4 GB nên Elasticsearch + Prometheus được MOVE sang srv02/03
> (chạy với emptyDir, accept restart data loss như user đã chấp
> thuận — "PVC khi restart có mất đâu nên không cần phải nhồi vào đó").

| Component | req | limit | Notes |
|-----------|-----|-------|-------|
| vault-dev (RAM-only) | 96 Mi | 192 Mi | Trim từ 128/256 |
| vault-prod | 192 Mi | 384 Mi | Trim từ 256/512 |
| MySQL | 256 Mi | 512 Mi | Giữ — DB chính |
| Kafka | 192 Mi | 384 Mi | Giảm heap broker |
| ~~Elasticsearch~~ | — | — | **MOVE → srv02/03** với heap 256 Mi, emptyDir |
| ~~Prometheus~~ | — | — | **MOVE → srv02/03** với retention 6h, emptyDir |
| SPIRE server | 192 Mi | 384 Mi | sqlite nhẹ |
| docker-registry | 128 Mi | 256 Mi | pull-only |
| Cilium agent (DS) | 128 Mi | 256 Mi | giữ |
| ~~Tetragon (DS)~~ | — | — | **SKIP srv05** (toleration: not on data tier) |
| Filebeat (DS) | 64 Mi | 128 Mi | giảm |
| spire-agent + spiffe-csi (DS) | 96 Mi | 192 Mi | giảm |
| node-exporter (DS) | 32 Mi | 64 Mi | giữ |
| OS Ubuntu 24.04 reserved + system-reserved + kube-reserved | ~512 Mi | — | |
| **Total** | **~1.9 GB** | **~3.2 GB** | |

Headroom 800 MB cho spike (vault-prod startup, MySQL buffer pool, OS
cache). Đủ cho 4 GB VM.

**Hậu quả**:
- ES + Prometheus pod sẽ chạy trên srv02 hoặc srv03 (K8s scheduler tự
  chọn). Không có nodeAffinity vì dùng emptyDir.
- Khi pod ES/Prom restart → mất data. Hubble flow log tích lũy trong ES
  bị reset. Prometheus TSDB mất history. Cho thesis demo (chạy ngắn,
  capture screenshot ngay) OK.
- Trade-off ngược: nếu cần persist log >6h, bump srv05 lên 5-6 GB và
  revert ES + Prom về srv05 (xem §8 fallback).

---

## 4. CPU pinning (gợi ý — VMware)

Windows host (6 core total):
- 1 core riêng cho Windows host (ưu tiên cho desktop UI)
- 1 core cho `7189srv01`
- 2 core cho `7189srv02`
- 2 core cho `7189srv03`

Ubuntu host (4 core total):
- 1 core riêng cho Ubuntu host + VMware
- 2 core cho `7189srv05`
- (1 core dự phòng — đừng dùng để tránh thrashing)

VMware Workstation Pro `Edit virtual machine settings → Processors →
Virtualize CPU performance counters: OFF` để tiết kiệm ~5% CPU.

---

## 5. Kubelet system-reserved (mỗi VM)

```yaml
# /var/lib/kubelet/config.yaml
systemReserved:
  cpu: "100m"
  memory: "256Mi"
  ephemeral-storage: "1Gi"
kubeReserved:
  cpu: "100m"
  memory: "256Mi"
  ephemeral-storage: "1Gi"
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
  imagefs.available: "10%"
```

Mục đích: bảo vệ kubelet + containerd khi pod xài hết RAM (nguyên nhân
gốc của incident #1 — cascade OOM kill metrics-server 137 lần).

---

## 6. Swap policy

Debian 13 mặc định có swapfile 1 GB (`/swap.img`). Cluster k8s 1.30 hỗ
trợ swap (beta) qua flag `failSwapOn=false` + `KubeletConfiguration:
{ memorySwap: { swapBehavior: LimitedSwap } }`.

Trong môi trường này:
- `vm.swappiness = 10` (giảm xu hướng swap vì swap chậm hơn RAM)
- `failSwapOn = false` (kubeadm cho phép node có swap)
- KHÔNG bật swap aggressive — chỉ làm safety net khi RAM gần hết

Apply trong `06-debian-base-prep.md` § sysctl.

---

## 7. Bảng config VMware (copy-paste khi tạo VM)

| Field | 7189srv01 | 7189srv02 | 7189srv03 | 7189srv05 |
|-------|-----------|-----------|-----------|-----------|
| Memory (MB) | 2048 | 4608 | 5120 | **4096** |
| Processors → Number of cores | 1 | 2 | 2 | 2 |
| Hard disk (GB) | 40 | 50 | 50 | **60** |
| Network adapter | NAT (VMnet8) | NAT (VMnet8) | NAT (VMnet8) | libvirt **bridge** |
| Guest OS | Debian 12.x 64-bit (VMware) | Debian 12.x 64-bit (VMware) | Debian 12.x 64-bit (VMware) | Ubuntu 24.04 LTS (libvirt) |
| Hypervisor host | Windows | Windows | Windows | Ubuntu |

> VMware chưa có preset "Debian 13" — chọn "Debian 12.x 64-bit" cũng
> work, kernel + userspace là 13 sau khi cài. srv05 chạy trên libvirt/KVM
> (Ubuntu host) với `virt-install --os-variant ubuntu24.04` — xem
> `transition-srv04-to-srv05.md` cho đúng cú pháp.

---

## 8. Fallback nếu host bị over-allocated

### Windows host (12.8 GB allocated)

| Option | Action | Tác động |
|--------|--------|----------|
| A | Giảm srv02 RAM 4.5 → 4.0 GB | Tetragon có thể OOMKill — chỉnh request xuống |
| B | Move ingress-nginx + Kong xuống srv05 | srv05 thêm tải, srv02/03 nhẹ hơn |
| C | Tắt Hubble UI / Kibana | Tiết kiệm ~512 Mi |
| D | Thêm `--full-enforcement=false` | Không chạy SPIRE + sigstore + Tetragon TracingPolicy phase 2 |

### Ubuntu host (4 GB allocated cho VM, 4 GB còn cho host)

| Option | Action | Tác động |
|--------|--------|----------|
| E | Bump srv05 lên 5-6 GB | Cần đảm bảo Ubuntu host còn ≥3 GB cho app khác (browser, IDE) |
| F | Move MySQL → emptyDir | Mất data nhanh hơn, không recommended |
| G | Drop Kafka (skip Filebeat→Kafka pipeline) | Giảm 384 Mi limit, ES phải đọc trực tiếp |
| H | Drop docker-registry trong cluster, build trên admin và `nerdctl save \| ssh load` | Giảm 256 Mi |

### Khi run pipeline

Set env var `RESOURCE_PROFILE=tight` khi chạy script
`05-cluster-services.sh` để áp dụng các trim trong bảng §3 ở trên.
`RESOURCE_PROFILE=normal` (default) áp dụng giá trị cũ (giả định srv05
6 GB).
