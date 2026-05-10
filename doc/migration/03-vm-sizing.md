# 03. VM Sizing — Phân bổ RAM/CPU/Disk

## 1. Ngân sách 2 host vật lý

| Host | Tổng RAM | RAM cho VM | Tổng vCPU | vCPU cho VM | Ghi chú |
|------|----------|-----------|-----------|-------------|---------|
| Windows (laptop) | 16 GB | **12.8 GB** | 6 cores | **5 vCPU** | 3.2 GB + 1 core dành cho Windows host + Edge + IDE |
| Ubuntu desktop (Resolute 26) | 8 GB | **~6.0 GB** | 4 cores | **3 vCPU** | 2.0 GB + 1 core dành cho Ubuntu host + GNOME |

Total RAM cho VM: 18.8 GB. Total vCPU: 8.

> User ghi "tối đa 12.8 GB cho VM" trên Windows — đó là con số trần. Nên
> giữ ~10.5-11.5 GB cấp phát thực để có 1.3 GB headroom cho VMware vmware-vmx
> process + page-file thrashing.

## 2. Sizing chi tiết

| VM | Host | RAM (cấp phát) | RAM (workload est.) | vCPU | Disk | Network |
|----|------|----------------|----------------------|------|------|---------|
| `cp1` | Win | **2.0 GB** | ~1.7 GB | 1 | 30 GB thin | NAT + Tailscale |
| `w-data` | Win | **5.0 GB** | ~3.4 GB (limits) | 2 | 60 GB thin (PVC neo ở đây) | NAT + Tailscale |
| `w-apps` | Win | **4.5 GB** | ~2.4 GB (req), 5.7 GB (limits) | 2 | 50 GB thin | NAT + Tailscale |
| `w-obs` | Ubuntu | **6.0 GB** | ~3.3 GB (req), 6.0 GB (limits) | 3 | 60 GB thin (ELK PVC) | NAT + Tailscale |
| **Tổng** | | **17.5 GB** | | **8 vCPU** | 200 GB | |

Còn lại: Windows 12.8 - 11.5 = **1.3 GB headroom**, Ubuntu 6.0 GB cấp đúng
trần (không spare). Nếu Ubuntu pressure quá mạnh, giảm Tetragon limit hoặc
`elasticsearch -Xmx` xuống 256 Mi.

## 3. Disk layout từng VM

### `cp1` (30 GB)
```
/         15 GB  ext4 (root)
/var/lib/etcd   5 GB  ext4 (mount riêng — etcd cần I/O ổn định)
/var/lib/containerd   8 GB  ext4 (image pull cache)
swap     2 GB  (file, vm.swappiness=10)
```

### `w-data` (60 GB)
```
/         15 GB  ext4
/var/lib/containerd   10 GB  ext4
/var/lib/job7189-mysql      15 GB  ext4 (PVC mount qua local-path-provisioner)
/var/lib/job7189-vault       3 GB  ext4
/var/lib/job7189-kafka      10 GB  ext4
/var/lib/job7189-keycloak    3 GB  ext4
swap                          4 GB
```

### `w-apps` (50 GB)
```
/         15 GB  ext4
/var/lib/containerd   25 GB  ext4 (chứa 7 Laravel image × ~600 MB)
/var/lib/job7189-registry    8 GB  ext4 (in-cluster docker-registry)
swap                          2 GB
```

### `w-obs` (60 GB)
```
/         15 GB  ext4
/var/lib/containerd   10 GB  ext4
/var/lib/job7189-elasticsearch 25 GB  ext4 (logs + Hubble flow sink)
/var/lib/job7189-prometheus    8 GB  ext4
swap                            2 GB
```

> Không dùng LVM (user yêu cầu "không LVM hay gì cả"). Nếu cần resize sau
> này, mở rộng vmdk + `growpart` + `resize2fs`.

## 4. CPU pinning chiến lược (optional)

VMware Workstation Pro hỗ trợ "Reserved CPU" + "Number of cores per
processor". Đề xuất:

- Windows host (6 cores total):
  - VMware overhead + host: 1 core
  - cp1: 1 vCPU (1 core)
  - w-data: 2 vCPU (2 cores)
  - w-apps: 2 vCPU (2 cores)
  - **Tổng: 6 cores đúng** (không over-allocate vì 6 = 6).

- Ubuntu host (4 cores total):
  - GNOME + host: 1 core
  - w-obs: 3 vCPU (3 cores)
  - **Tổng: 4 cores**.

Nếu cảm thấy w-obs eBPF + ELK quá ngốn CPU, tắt GNOME (boot multi-user)
và dồn 4 vCPU.

## 5. Kubelet system-reserved

Trên mọi VM, kubelet cần được cấu hình:
```yaml
# /var/lib/kubelet/config.yaml (kubeadm tự gen, edit phần này)
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
```

Mục đích: pod KHÔNG được phép dùng hết tới byte cuối cùng — luôn chừa
512 Mi cho systemd + kubelet + containerd. Đây là điểm Kind không có
(Kind không expose được cgroup root → không enforce reserved → hậu quả
là 3 incident OOM cascade ở doc cũ).

## 6. Swap policy

User cũ trên `doc/06-resource-budget.md`: swap 4 GB, swappiness 60 →
**đổi xuống 10**, kubelet `failSwapOn=false` (mặc định K8s 1.30 chấp nhận
swap).

```bash
# /etc/sysctl.d/99-zta.conf
vm.swappiness = 10
vm.overcommit_memory = 1   # giống K8s khuyến nghị
vm.panic_on_oom = 0
kernel.panic = 10
fs.inotify.max_user_watches = 524288    # cho Filebeat + cilium-monitor
fs.inotify.max_user_instances = 8192
```

Với `swappiness=10`, kernel chỉ swap khi RAM thực sự cạn. Pod Burstable
(MySQL, Laravel) sẽ là ứng viên đầu tiên — chấp nhận được vì I/O của ELK
(Elasticsearch) đã chiếm rất nhiều page-cache.

## 7. Bảng tóm tắt sizing (paste vào VMware)

```
+---------+--------+-------+---------+--------+----------+
| VM      | Host   | RAM   | vCPU    | Disk   | NIC mode |
+---------+--------+-------+---------+--------+----------+
| cp1     | Win    | 2048  | 1       | 30 GB  | NAT      |
| w-data  | Win    | 5120  | 2       | 60 GB  | NAT      |
| w-apps  | Win    | 4608  | 2       | 50 GB  | NAT      |
| w-obs   | Ubuntu | 6144  | 3       | 60 GB  | NAT      |
+---------+--------+-------+---------+--------+----------+
```

Tất cả VM dùng **chế độ thin-provisioned** disk + **EFI firmware**
(BIOS legacy cũng OK, nhưng EFI cho phép secure boot nếu sau này muốn
SBOM-attestation chap 26).

## 8. Phương án dự phòng nếu RAM không đủ

Nếu trong lúc deploy, VM `w-obs` OOM:
1. **Giảm Elasticsearch heap** từ 384 Mi → 256 Mi (`-Xmx256m`).
2. **Tắt Kibana** (`kubectl scale -n monitoring deploy/kibana --replicas=0`)
   — query qua `kubectl exec` của ES.
3. **Giảm Tetragon limit** xuống 256 Mi nhưng **không** đi dưới 256 Mi
   (đã có incident OOM ở 256 Mi).
4. **Đẩy Gatekeeper sang w-data** nếu nó là pod nặng nhất còn lại — chấp
   nhận latency admission cao hơn vì cross-VM.

Nếu w-data OOM (Vault/MySQL):
1. **Tắt Kafka** nếu không demo event flow → tiết kiệm ~512 Mi.
2. **Kafka và Vault DB engine không thể giảm sâu hơn**, nếu vẫn chật thì
   migrate Keycloak sang w-obs (nhưng lúc đó w-obs cũng chật).

Cuối cùng: nếu phương án trên không đủ, tăng RAM Ubuntu host từ 8 GB lên
16 GB (đây là khuyến nghị strong nhất nếu user có thể nâng phần cứng).
