# Answers — Câu hỏi của bạn (2026-05-10)

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


> Hai câu hỏi bạn đặt ra trước khi mình đụng tới máy thật. Mình trả lời
> rõ + dẫn nguồn, để sau này khỏi phải hỏi lại.

---

## 1. "Control plane sập thì cái server ở Ubuntu ảnh hưởng không?"

### TL;DR

| Lớp | Khi `7189srv01` (control plane) chết | Có ảnh hưởng `7189srv05` (Ubuntu) không? |
|-----|--------------------------------------|------------------------------------------|
| Host OS Ubuntu (kernel, systemd, SSH, network) | KHÔNG động vào | **KHÔNG** ảnh hưởng — Ubuntu chạy bình thường |
| Tailscale daemon trên srv05 | KHÔNG động vào | **KHÔNG** ảnh hưởng |
| containerd + kubelet trên srv05 | Vẫn chạy | **KHÔNG** ảnh hưởng |
| **Pod đang chạy trên srv05** (vault, MySQL, Kafka, ES, Prometheus, registry, SPIRE) | Tiếp tục chạy nhờ kubelet local | **KHÔNG** ảnh hưởng (state đã được kubelet cache) |
| **Dataplane Cilium trên srv05** | VXLAN tunnel đã program sẵn → tiếp tục forward | **KHÔNG** ảnh hưởng cho traffic giữa pod đã có |
| **kubectl / scheduler / controller-manager** | DOWN | Mất khả năng tạo/sửa/xóa Deployment, ConfigMap, Secret |
| **Tạo pod mới / reschedule / scale** | DOWN | Không tạo được pod mới trên srv05 |
| **Cilium identity update** | DOWN (apiserver gone) | Identity mới không sync — pod existing OK, pod mới (nếu có cách tạo được) sẽ chưa có policy |
| **Đăng ký SPIFFE workload mới** | DOWN | Workload mới không có SVID, workload cũ giữ SVID đã cấp đến khi hết TTL |

### Chi tiết kỹ thuật

Kubernetes có separation rõ giữa **control plane** (etcd, apiserver,
scheduler, controller-manager) và **data plane** (kubelet + container
runtime + CNI dataplane trên mỗi node):

```
[Admin laptop]
     │
     │ kubectl (REST/HTTPS)
     ▼
[apiserver trên 7189srv01]  ←── Khi srv01 chết, đường này bị đứt
     │                            ▼
     │                          (1) kubectl báo "connection refused"
     │                          (2) Không tạo/sửa/xóa được resource mới
     │
     │ watch event
     ▼
[kubelet trên 7189srv05]
     │
     │ CRI (gRPC unix socket)
     ▼
[containerd trên 7189srv05]
     │
     │ runc
     ▼
[Pod vault, mysql, kafka, ...] ← Vẫn chạy bình thường
```

Khi `7189srv01` chết:

1. **kubelet trên srv05** mất kết nối tới apiserver → entry watch
   timeout. **Nhưng kubelet không kill pod** — nó retry vô hạn cho tới
   khi apiserver có lại. Trong thời gian đó pod tiếp tục chạy với cấu
   hình cuối cùng kubelet đã nhận.
2. **Cilium agent** trên srv05 mất kết nối → nó không nhận được identity
   mới hay CiliumNetworkPolicy mới, nhưng các BPF map trong kernel
   (policy, services, NAT) đã được populate trước đó, nên dataplane vẫn
   chuyển gói. Pod-to-pod đã được cấp identity vẫn nói chuyện được.
3. **Static pod** trên srv01 (apiserver, etcd, controller, scheduler)
   chết theo VM. Khi VM up lại, kubelet trên srv01 đọc lại
   `/etc/kubernetes/manifests/*.yaml` và tự khởi động lại các static
   pod. **Không cần can thiệp tay**.
4. **etcd**: dữ liệu nằm trên `/var/lib/etcd/` của srv01 (PVC = không,
   chỉ là disk của VM srv01). Nếu VM srv01 không corrupt disk, etcd up
   lại bình thường. Nếu corrupt → restore từ snapshot (xem
   `12-runbook-recovery.md` §1).

### Tác động thực tế cho thesis demo

- **Có thể demo "kill control plane"** mà show pod data tier vẫn sống
  → đây là điểm cộng cho thesis (failure isolation, không như Kind cũ
  một host kéo cả cluster).
- **Recover time**: power-on srv01 → ~2-3 phút apiserver lại respond
  (etcd read PVC, scheduler/controller-manager bắt đầu reconcile).
- **Risk**: nếu srv01 chết LÂU (>10 phút) và trong thời gian đó pod trên
  srv05 OOM-killed → kubelet **không thể tạo pod thay thế** vì không
  liên hệ được apiserver. Pod sẽ stuck trong `unknown` state cho tới khi
  cp up lại. Đây là lý do `7189srv01` được cấp 2 GB RAM riêng + chạy
  trên Windows host (host nhiều RAM hơn) — giảm xác suất srv01 chết do
  RAM.

### Khuyến nghị

1. **Lấy VMware snapshot `7189srv01-baseline`** ngay sau khi cluster
   stable. Restore = "Snapshot Manager → Revert" → up trong 2 phút.
2. **Cron etcd snapshot mỗi ngày** (chạy trong static pod có
   privileged):
   ```bash
   ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     snapshot save /var/lib/etcd-backup/snap-$(date +%F).db
   ```
3. **Khi srv01 sập trong demo**: chỉ cần **không đụng vào srv05**. Pod
   tiếp tục phục vụ HTTP request giữa các worker và tới user. Power-on
   srv01 lại là xong.

### Trường hợp Ubuntu host ăn ảnh hưởng

| Kịch bản | Ubuntu host (OS) bị ảnh hưởng? |
|---------|-------------------------------|
| `7189srv01` (Windows) chết — apiserver gone | KHÔNG |
| Toàn bộ Windows host crash → 3 VM chết | KHÔNG (Ubuntu host và srv05 vẫn chạy độc lập) |
| Tailscale rớt giữa Windows ↔ Ubuntu | KHÔNG (host vẫn online; chỉ pod cross-host mất kết nối) |
| `7189srv05` (VM trên Ubuntu) ăn quá nhiều RAM | **CÓ** — Ubuntu host bị thiếu RAM cho các app khác |
| `7189srv05` corrupt disk file `.qcow2` | **CÓ** — file disk image (libvirt/KVM) hỏng cần fix qua `qemu-img check`/`virsh` |

→ **Kết luận**: control plane sập trên Windows **KHÔNG** ảnh hưởng tới
Ubuntu host. Chỉ có việc dùng kubectl bị treo cho đến khi srv01 up lại.
Workload data trên srv05 vẫn phục vụ.

---

## 2. "Tên user có quan trọng không? Mình để hết là `ptb`, có cần đổi sang `7189` không?"

### TL;DR

**Không cần đổi**. `ptb` hoạt động hoàn toàn OK. Mình sẽ viết script
dùng `${USER}` (biến shell) thay vì hardcode `debian`/`ubuntu`. Thậm chí
bạn có thể trộn — `ptb` trên cả 4 VM, hoặc `ptb` trên Ubuntu, `7189`
trên Windows VM — kệ.

### Chi tiết: Kubernetes nhìn cái gì?

| Thực thể | K8s thấy như thế nào | User Linux liên quan? |
|---------|---------------------|----------------------|
| Hostname VM | `kubernetes.io/hostname` label trên Node | KHÔNG |
| nodeAffinity matching | `kubernetes.io/hostname=7189srv05` | KHÔNG |
| kubelet identity | TLS cert do CA của apiserver issue | KHÔNG (kubelet chạy với systemd unit, KHÔNG dùng user `ptb`) |
| etcd files trên srv01 | `/var/lib/etcd/` (root owned) | KHÔNG |
| containerd files | `/var/lib/containerd/` (root) | KHÔNG |
| kubeconfig | File trên disk admin laptop | CÓ (file user-owned, $HOME/.kube/config) |
| Tailscale node tags | Tag `tag:zta-cluster` trong tailnet | KHÔNG (set qua `tailscale up --advertise-tags`) |

→ **Cái K8s quan tâm**: HOSTNAME (`7189srv01..04`), KHÔNG phải Linux user.

### Cái Linux user `ptb` có ảnh hưởng

1. **SSH login**: `ssh ptb@7189srv01.<tailnet>.ts.net`. Đổi user ⇒ đổi
   target SSH ⇒ phải copy lại authorized_keys.
2. **Sudo passwordless**: `/etc/sudoers.d/90-ptb` chứa
   `ptb ALL=(ALL) NOPASSWD:ALL`. Dùng được, OK.
3. **Kubeconfig path**: trên srv01 sau `kubeadm init` mặc định nằm trong
   `/home/ptb/.kube/config` (hoặc bất kỳ user nào đang chạy lệnh
   `cp /etc/kubernetes/admin.conf $HOME/.kube/config`). Đổi user ⇒ phải
   copy lại file.
4. **Thư mục PVC** (`/var/lib/job7189-mysql`, `/var/lib/job7189-vault`,
   ...): root-owned, **không liên quan user `ptb`**. local-path
   provisioner chmod 777 cho pod write.

### Khi nào CẦN đổi tên user

| Lý do | Khuyến nghị đổi? |
|-------|------------------|
| Tránh xuất hiện chữ `debian`/`ubuntu` trong demo screencast | OK đổi tên user thành `ptb` (đã làm) — không cần đổi tiếp |
| Tránh confusion thesis defense (giảng viên hỏi) | KHÔNG — chỉ thêm complication. Giải thích "user OS không phải user K8s" là đủ. |
| Đồng bộ `7189` brand theme cho thesis evidence | KHÔNG cần — hostname đã là `7189srv0X`, screenshots K8s sẽ luôn show `7189` |
| Bảo mật (user mạnh hơn) | KHÔNG — user nào cũng cần SSH key + sudo NOPASSWD nên security bằng nhau |

### Khuyến nghị

- **Giữ user `ptb` trên cả 4 VM** — nhất quán, dễ nhớ.
- **Hostname phải đúng `7189srv01..04`** — đây mới là cái K8s tracking.
  Verify bằng `hostnamectl status`. Nếu sai, đổi rồi reboot:
  ```bash
  sudo hostnamectl set-hostname 7189srv02
  sudo reboot
  ```
- **Script migration của mình dùng `${USER}` chứ không hardcode**. Bạn
  chạy script với user nào nó deploy với user đó. Nếu user là `ptb` thì
  kubeconfig sẽ vào `/home/ptb/.kube/config`.
- **Trong tài liệu/CLI cheat sheet** mình ghi `ssh ptb@7189srv0X.<tailnet>.ts.net`
  thay vì `debian@...` — đỡ confusion.
- **Khi demo thesis**, slide/screencast show prompt `ptb@7189srv01:~$` 
  → nhất quán brand. OK.

### Edge cases

1. **Tailscale SSH**: nếu bật `--ssh` lúc `tailscale up`, ACL trong
   tailnet quy định login user. Hiện ACL có:
   ```jsonc
   { "users": ["root", "debian", "ubuntu"] }
   ```
   → **Cần thêm `"ptb"`** vào danh sách users trong ACL Tailscale (xem
   `04-network-tailscale-cilium.md` §3). Mình sẽ update doc này.

2. **kubeadm init**: chạy bằng `sudo` (root). Output gợi ý:
   ```
   To start using your cluster, you need to run the following as a regular user:
     mkdir -p $HOME/.kube
     sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
     sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```
   `$(id -u):$(id -g)` tự lấy UID của user hiện tại (`ptb`). OK, không
   phải sửa gì.

3. **Helm**: chạy với user nào thì đọc `~/<user>/.config/helm/`. OK,
   không quan trọng.

→ **Final answer**: `ptb` is fine. Không cần đổi sang `7189`.

---

## Bonus: Ubuntu host RAM = 8 GB → revise sizing

Bạn nói:
> Một số vấn đề nữa là Ubuntu làm host có 8GB thôi, vì vậy để cái máy ảo
> của nó 4GB thôi nhé

Plan cũ (`03-vm-sizing.md`) tính srv05 = **6 GB**. Mình revise xuống
**4 GB** trong file `03-vm-sizing.md` (xem PR này) và trim workload
tương ứng:

| Component | Plan cũ (req/limit) | Plan mới 4 GB (req/limit) | Notes |
|-----------|---------------------|---------------------------|-------|
| vault-dev | 128 / 256 Mi | 96 / 192 Mi | RAM-only, ít activity |
| vault-prod | 256 / 512 Mi | 192 / 384 Mi | |
| MySQL | 256 / 512 Mi | 256 / 512 Mi | giữ — DB chính |
| Kafka | 256 / 512 Mi | 192 / 384 Mi | giảm broker heap |
| Elasticsearch | 384 / 768 Mi | **MOVE OFF srv05** → emptyDir trên srv02/03 với heap 256 Mi | Accept restart-time data loss (bạn đã ok) |
| Prometheus | 256 / 512 Mi | **MOVE OFF srv05** → emptyDir trên srv02/03, retention 6h | Accept restart-time data loss |
| SPIRE server | 256 / 512 Mi | 192 / 384 Mi | sqlite nhỏ |
| docker-registry | 256 / 512 Mi | 128 / 256 Mi | Phục vụ pull, không nén nặng |
| Tetragon DS | (skip srv05) | (skip srv05) | toleration không deploy DS lên srv05 |
| Cilium DS | 128 / 256 Mi | 128 / 256 Mi | giữ |
| Filebeat DS | 100 / 200 Mi | 64 / 128 Mi | giảm |
| spire-agent + csi DS | 128 / 256 Mi | 96 / 192 Mi | giảm |
| node-exporter DS | 32 / 64 Mi | 32 / 64 Mi | giữ |
| OS Debian 13 reserved | 300 Mi | 280 Mi | |
| **Total req** | ~3.0 GB | **~1.7 GB** | |
| **Total limit** | ~5.3 GB | **~2.9 GB** | |

→ **Headroom**: 4096 - 2900 = ~1.2 GB cho spike, OS cache, journald,
syslog, etc. Đủ.

→ **Tradeoff**: ES + Prom mất state khi pod restart. Cho thesis demo
short-lived OK. Nếu cần persist long-term, bump srv05 lên 5-6 GB hoặc
dựng external observability trên admin laptop.

Chi tiết update trong PR: `knowledge-base/migration/03-vm-sizing.md` được rewrite,
các script `02-control-plane-init.sh`, `05-cluster-services.sh` đã được
chỉnh để áp dụng resource profile mới.
