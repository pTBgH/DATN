# 03 — VM sizing

## 1. Ngân sách host

| Host | Total | Allocatable cho VMs | Lý do giảm |
|------|-------|---------------------|-------------|
| Windows (16 GB / 6 core) | 16 GB / 6 vCPU | **12.8 GB / 5 vCPU** | 3.2 GB cho Windows + VMware overhead, giữ 1 core cho host UI |
| Ubuntu (8 GB / 4 core, DDR3) | 8 GB / 4 vCPU | **6.0 GB / 2 vCPU** | 2.0 GB cho Ubuntu + VMware overhead; giảm 3→2 vCPU vì CPU cũ |

Tổng ngân sách: 18.8 GB / 7 vCPU. Plan dưới đây dùng 17.5 GB / 7 vCPU
(headroom 1.3 GB).

---

## 2. Sizing chi tiết

| VM | Host | RAM | vCPU | Disk | Vai trò |
|----|------|-----|------|------|---------|
| `7189srv01` | Windows | **2.0 GB** | 1 | 40 GB ext4 | control-plane only |
| `7189srv02` | Windows | **4.5 GB** | 2 | 50 GB ext4 | generic worker |
| `7189srv03` | Windows | **5.0 GB** | 2 | 50 GB ext4 | generic worker |
| `7189srv04` | Ubuntu  | **6.0 GB** | 2 | 80 GB ext4 | data tier always-on |
| **Sum** |  | **17.5 GB** | **7** | **220 GB** | |

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

### 7189srv04 (6.0 GB)

| Component | req | limit |
|-----------|-----|-------|
| vault-dev (RAM-only) | 128 Mi | 256 Mi |
| vault-prod | 256 Mi | 512 Mi |
| MySQL | 256 Mi | 512 Mi |
| Kafka | 256 Mi | 512 Mi |
| Elasticsearch | 384 Mi | 768 Mi |
| Prometheus | 256 Mi | 512 Mi |
| SPIRE server | 256 Mi | 512 Mi |
| docker-registry | 256 Mi | 512 Mi |
| Cilium agent (DS) | 128 Mi | 256 Mi |
| Tetragon (DS) | 256 Mi | 384 Mi |
| Filebeat (DS) | 100 Mi | 200 Mi |
| spire-agent + spiffe-csi (DS) | 128 Mi | 256 Mi |
| node-exporter (DS) | 32 Mi | 64 Mi |
| OS Debian 13 reserved | ~300 Mi | — |
| **Total** | **~3.0 GB** | **~5.3 GB** |

Headroom 700 MB cho spike (ES JVM heap, vault-prod startup).

---

## 4. CPU pinning (gợi ý — VMware)

Windows host (6 core total):
- 1 core riêng cho Windows host (ưu tiên cho desktop UI)
- 1 core cho `7189srv01`
- 2 core cho `7189srv02`
- 2 core cho `7189srv03`

Ubuntu host (4 core total):
- 1 core riêng cho Ubuntu host + VMware
- 2 core cho `7189srv04`
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

| Field | 7189srv01 | 7189srv02 | 7189srv03 | 7189srv04 |
|-------|-----------|-----------|-----------|-----------|
| Memory (MB) | 2048 | 4608 | 5120 | 6144 |
| Processors → Number of cores | 1 | 2 | 2 | 2 |
| Hard disk (GB) | 40 | 50 | 50 | 80 |
| Network adapter | NAT (VMnet8) | NAT (VMnet8) | NAT (VMnet8) | NAT |
| Guest OS | Debian 12.x 64-bit | Debian 12.x 64-bit | Debian 12.x 64-bit | Debian 12.x 64-bit |
| Hypervisor host | Windows | Windows | Windows | Ubuntu |

> VMware chưa có preset "Debian 13" — chọn "Debian 12.x 64-bit" cũng
> work, kernel + userspace là 13 sau khi cài.

---

## 8. Fallback nếu Windows host bị over-allocated

Nếu sau khi chạy 1 tuần thấy Windows host swap thrash:

| Option | Action | Tác động |
|--------|--------|----------|
| A | Giảm srv02 RAM 4.5 → 4.0 GB | Tetragon có thể OOMKill — chỉnh request xuống |
| B | Move ingress-nginx + Kong xuống srv04 | srv04 thêm tải, srv02/03 nhẹ hơn |
| C | Tắt Hubble UI / Kibana | Tiết kiệm ~512 Mi |
| D | Thêm `--full-enforcement=false` | Không chạy SPIRE + sigstore + Tetragon TracingPolicy phase 2 |

Hiện tại plan giả định Option A-C không cần thiết vì 11.5 / 12.8 GB
đã có 1.3 GB headroom.
