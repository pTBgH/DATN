# Migration: Kind → Multi-VM kubeadm trên Tailscale

Kế hoạch chuyển ZTA cluster từ Kind 1-host (12 GB RAM, hay crash do OOM
cascade — xem `doc/incident-falco-tetragon-ram-overcommit.md`,
`doc/incident-gatekeeper-crd-timeout.md`,
`doc/incident-gatekeeper-probe-webhook-stuck.md`) sang **4 VM Debian 13
chạy kubeadm**, phân bố trên 2 host vật lý nối nhau qua Tailscale.

> **Trạng thái (2026-05-10):** Phần script thực thi đã được viết
> trong `scripts/`. Đọc `00-PRECHECK.md` và `ANSWERS.md` trước khi
> chạy bất kỳ `.sh` nào.
>
> sizing srv04 đã được **giảm từ 6 GB → 4 GB** theo yêu cầu user (Ubuntu
> host cần RAM cho app khác). ES + Prometheus move sang srv02/03 với
> emptyDir.

---

## Nguyên tắc thiết kế (TL;DR)

1. **Tách kernel của K8s ra khỏi host duy nhất** — không còn chuyện một
   pod ăn RAM kéo cả etcd + apiserver chết theo (nguyên nhân gốc của 3
   incident).
2. **Để K8s tự điều phối workload** — không nodeAffinity tier-based cứng.
   Pod stateless (Laravel, Kong, ingress, Tetragon DS, Cilium DS, SPIRE
   agent, Filebeat DS, ...) đặt **bất kỳ đâu**, scheduler tự cân.
3. **Chỉ pin workload stateful (có PVC) lên `7189srv04`** (VM Ubuntu —
   "always-on host"). Lý do:
   - User ít khi tắt máy Ubuntu → data tier có uptime cao nhất
   - Vault-dev (Transit engine, RAM-only) phải KHÔNG restart, nếu không
     vault-prod sẽ mất khả năng auto-unseal
   - PVC neo node — pod restart phải đúng node có data
4. **Tailscale làm L3 underlay** — VMware NAT giữ nguyên cho từng host,
   các VM nói chuyện cross-host qua Tailscale `100.64.0.0/10` (CGNAT).
5. **Cilium VXLAN tunnel + WireGuard OFF** — Tailscale đã encrypt sẵn,
   không double-encrypt để khỏi tốn CPU.
6. **Pipeline `scripts/zta-rebuild.sh` giữ nguyên 95%** — chỉ thay phase
   `01-cluster` (kind delete/create → kubeadm bootstrap external) và
   patch nodeAffinity cho mảng stateful (~7 file YAML).

---

## VM lineup

| VM | Host | RAM | vCPU | Vai trò chính |
|----|------|-----|------|----------------|
| `7189srv01` | Windows | 2.0 GB | 1 | control-plane (etcd, apiserver, scheduler, ctrl-mgr) |
| `7189srv02` | Windows | 4.5 GB | 2 | generic worker (K8s tự schedule) |
| `7189srv03` | Windows | 5.0 GB | 2 | generic worker (K8s tự schedule) |
| `7189srv04` | Ubuntu | **4.0 GB** | 2 | data tier always-on (vault-dev, vault-prod, MySQL, Kafka, SPIRE server, docker-registry) — ES + Prometheus move sang srv02/03 |

Tổng: **15.5 GB / 7 vCPU**. Windows host dùng 11.5/12.8 GB. Ubuntu host
dùng 4/8 GB và **2 vCPU** (giảm từ 3 — máy DDR3 cũ, cần 4 GB cho app khác).

---

## Index

### Operational checklists (đọc TRƯỚC khi chạy)

| File | Mục đích |
|------|----------|
| [`00-PRECHECK.md`](00-PRECHECK.md) | Checklist OPS phải pass trước khi chạy `.sh` thật trên VM |
| [`ANSWERS.md`](ANSWERS.md) | Trả lời 2 câu hỏi: control-plane impact + tên user `ptb` vs `7189` |
| [`scripts/README.md`](scripts/README.md) | Cách dùng các script `.sh` (idempotent + rollback) |

### Architecture & rationale

| # | File | Trả lời câu hỏi |
|---|------|------------------|
| 01 | [`01-context-and-rationale.md`](01-context-and-rationale.md) | Tại sao bỏ Kind? Trade-off Kind vs multi-VM. |
| 02 | [`02-target-architecture.md`](02-target-architecture.md) | Topology mới + workload placement. |
| 03 | [`03-vm-sizing.md`](03-vm-sizing.md) | RAM/CPU/disk từng VM, fit ngân sách 12.8 + 8 GB. |
| 04 | [`04-network-tailscale-cilium.md`](04-network-tailscale-cilium.md) | Tailscale + VMware NAT + Cilium VXLAN. |
| 05 | [`05-storage-and-registry.md`](05-storage-and-registry.md) | local-path-provisioner pin vào `7189srv04`. |
| 06 | [`06-debian-base-prep.md`](06-debian-base-prep.md) | Cài đặt Debian 13 cho cả 4 VM. |
| 07 | [`07-kubeadm-bootstrap.md`](07-kubeadm-bootstrap.md) | `kubeadm init` `7189srv01` + join 3 worker. |
| 08 | [`08-cilium-install.md`](08-cilium-install.md) | Cilium 1.19 với Tailscale-aware `nodeIP`. |
| 09 | [`09-cluster-services-bringup.md`](09-cluster-services-bringup.md) | metrics-server, ingress, cert-manager. |
| 10 | [`10-zta-pipeline-adaptations.md`](10-zta-pipeline-adaptations.md) | Thay đổi cụ thể trong `01-setup-cluster.sh`, manifest stateful. |
| 11 | [`11-runbook-fresh-deploy.md`](11-runbook-fresh-deploy.md) | Day-0 runbook end-to-end. |
| 12 | [`12-runbook-recovery.md`](12-runbook-recovery.md) | Khi VM chết / Tailscale rớt / kubeadm token hết hạn. |
| 13 | [`13-validation-checklist.md`](13-validation-checklist.md) | Cách biết migration thành công. |

---

## Quy ước

- **Cluster name** giữ nguyên `job7189` (verify scripts không phải đổi).
- **Pod CIDR** giữ `10.244.0.0/16`, **Service CIDR** giữ `10.96.0.0/12` —
  không đụng `100.64.0.0/10` của Tailscale.
- **Container runtime**: `containerd` (Debian 13 "Trixie" package,
  kubeadm khuyến nghị, tương thích Cilium + Tetragon CO-RE eBPF).
- **Distro**: Debian 13 "Trixie" trên mọi VM (kernel ≥ 6.6, đủ CO-RE eBPF
  cho Tetragon).
- **K8s version**: 1.30 (mới nhất ổn định khi cluster reference này được
  thiết kế; downgrade 1.29 nếu cần để khớp Cilium 1.19 hoặc Gatekeeper).

---

## Stateful workloads pin vào `7189srv04`

| Workload | NS | PVC | Lý do pin |
|----------|-----|-----|-----------|
| `vault-dev` | vault | (RAM only — không PVC) | Không bao giờ được restart (mất Transit key → vault-prod mất auto-unseal). Đặt trên Ubuntu always-on. |
| `vault-prod` | vault | 2 Gi | Stateful + co-locate với vault-dev cho low-latency unseal call |
| MySQL | data | ~10 Gi | Stateful database |
| Kafka | data | ~5 Gi | StatefulSet broker |
| ~~Elasticsearch~~ | monitoring | (emptyDir, srv02/03) | **MOVE OFF srv04** — srv04 chỉ còn 4 GB; ES dock heap 256 Mi trên worker, accept restart data loss |
| ~~Prometheus~~ | monitoring | (emptyDir, srv02/03) | **MOVE OFF srv04** — retention 6h, accept restart data loss |
| `docker-registry` | registry | ~8 Gi | Tránh re-pull 7 Laravel images khi srv02/03 reboot |
| SPIRE server | spire | ~1 Gi | Workload identity DB (sqlite) |

Pin technique: nodeAffinity `kubernetes.io/hostname=7189srv04` trong
StatefulSet/Deployment template. Stateless còn lại (Keycloak Deployment
H2-in-memory, 7 Laravel, Kong, ingress, cert-manager, Grafana, Kibana,
Cilium operator, Hubble Relay/UI, Gatekeeper, sigstore, PDP, Hubble
shipper) → KHÔNG nodeAffinity, K8s tự điều phối.

---

## Open questions

| Vấn đề | Giả định hiện tại | Nơi sẽ phải sửa nếu đổi |
|--------|------------------|--------------------------|
| Hypervisor Windows | VMware Workstation Pro | `06-debian-base-prep.md` |
| Số VM | 4 (1 cp + 3 w) | `02`, `03`, `07` |
| K8s flavor | kubeadm 1.30 | `06`, `07`, `10` |
| Tailscale làm L3 | Có, Cilium WG OFF | `04`, `08` |
| Distro | Debian 13 (Trixie) | `06` |
