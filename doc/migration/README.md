# Migration: Kind → Multi-VM kubeadm trên Tailscale

Kế hoạch chi tiết để chuyển ZTA cluster từ Kind 1-host (12 GB RAM, hay
crash do OOM cascade — xem `doc/incident-falco-tetragon-ram-overcommit.md`,
`doc/incident-gatekeeper-crd-timeout.md`, `doc/incident-gatekeeper-probe-webhook-stuck.md`)
sang **4 VM Debian 12 chạy kubeadm**, phân bố trên 2 host vật lý nối nhau
qua Tailscale.

> **Trạng thái:** Đây là tài liệu kế hoạch (planning-only). Chưa có script,
> manifest, hay file infrastructure mới được commit. Sau khi user duyệt
> plan, mới triển khai và viết script tự động.

---

## Nguyên tắc thiết kế (TL;DR)

1. **Tách kernel của K8s ra khỏi host duy nhất** — không còn chuyện một pod
   ăn RAM kéo cả etcd + apiserver chết theo (nguyên nhân gốc của 3 incident).
2. **Tailscale làm L3 underlay** — VMware NAT giữ nguyên cho từng host,
   các VM nói chuyện cross-host qua Tailscale `100.64.0.0/10` (CGNAT).
3. **Cilium VXLAN tunnel + WireGuard OFF** — Tailscale đã encrypt sẵn,
   không double-encrypt để khỏi tốn CPU.
4. **Workload đặt theo namespace tier** — heavy stuff (ELK, Tetragon DS,
   SPIRE, Gatekeeper) đẩy sang VM Ubuntu host (6 GB) để VM Windows host
   nhẹ tải hơn.
5. **Pipeline `scripts/zta-rebuild.sh` giữ nguyên 90%** — chỉ thay phase
   `01-cluster` (kind delete/create → kubeadm bootstrap external) và một
   số tweak nhỏ về registry / hostPath / NodePort.

---

## Index 13 file

| # | File | Trả lời câu hỏi |
|---|------|------------------|
| 01 | [`01-context-and-rationale.md`](01-context-and-rationale.md) | Tại sao bỏ Kind? Kind vs multi-VM trade-off. |
| 02 | [`02-target-architecture.md`](02-target-architecture.md) | Topology mới gồm gì, pod chạy ở VM nào. |
| 03 | [`03-vm-sizing.md`](03-vm-sizing.md) | RAM/CPU/disk từng VM, fit ngân sách 12.8 + 8 GB. |
| 04 | [`04-network-tailscale-cilium.md`](04-network-tailscale-cilium.md) | Tailscale + VMware NAT + Cilium VXLAN ráp ra sao. |
| 05 | [`05-storage-and-registry.md`](05-storage-and-registry.md) | local-path-provisioner + in-cluster registry. |
| 06 | [`06-debian-base-prep.md`](06-debian-base-prep.md) | Cài đặt Debian server cho cả 4 VM (idempotent). |
| 07 | [`07-kubeadm-bootstrap.md`](07-kubeadm-bootstrap.md) | `kubeadm init` trên cp1 + `kubeadm join` 3 worker. |
| 08 | [`08-cilium-install.md`](08-cilium-install.md) | Cilium 1.19 với Tailscale-aware `nodeIP`. |
| 09 | [`09-cluster-services-bringup.md`](09-cluster-services-bringup.md) | metrics-server, ingress, cert-manager, gateway-api CRDs. |
| 10 | [`10-zta-pipeline-adaptations.md`](10-zta-pipeline-adaptations.md) | Thay đổi cụ thể trong `01-setup-cluster.sh`, `zta-rebuild.sh`. |
| 11 | [`11-runbook-fresh-deploy.md`](11-runbook-fresh-deploy.md) | Day-0 runbook end-to-end. |
| 12 | [`12-runbook-recovery.md`](12-runbook-recovery.md) | Khi VM chết / Tailscale rớt / kubeadm token hết hạn. |
| 13 | [`13-validation-checklist.md`](13-validation-checklist.md) | Cách biết migration thành công (mirror `09-verify-zta.sh`). |

---

## Quy ước

- **Cluster name** giữ nguyên `job7189` (để verify scripts không phải đổi).
- **Pod CIDR** giữ `10.244.0.0/16`, **Service CIDR** giữ `10.96.0.0/12` —
  không đụng `100.64.0.0/10` của Tailscale.
- **Container runtime**: `containerd` (Debian package mặc định, kubeadm
  khuyến nghị, tương thích Cilium + Tetragon).
- **Distro**: Debian 12 "Bookworm" trên mọi VM (kernel 6.1, đủ CO-RE eBPF
  cho Tetragon).
- **K8s version**: 1.30 (mới nhất ổn định khi cluster reference này được
  thiết kế; downgrade 1.29 nếu cần để khớp Cilium 1.19 hoặc Gatekeeper).

---

## Open questions còn lại

(Mình đã chốt theo default sau khi user skip 4/5 câu — nếu sai expectation
thì sửa file tương ứng):

| Vấn đề | Giả định hiện tại | Nơi sẽ phải sửa nếu đổi |
|--------|------------------|--------------------------|
| Hypervisor Windows | VMware Workstation Pro | `06-debian-base-prep.md` |
| Số VM | 4 (1 cp + 3 w) | `02`, `03`, `07` |
| K8s flavor | kubeadm 1.30 | `06`, `07`, `10` |
| Tailscale làm L3 | Có, Cilium WG OFF | `04`, `08` |
| LTS desktop OS Ubuntu | Resolute (26 LTS) | (không ảnh hưởng — chỉ là host SSH client) |
