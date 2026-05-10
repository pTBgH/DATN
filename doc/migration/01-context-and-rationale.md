# 01. Context & Rationale — Tại sao bỏ Kind?

## 1. Lý do nghiệp vụ

Stack ZTA hiện tại (16 step trong `scripts/zta-rebuild.sh`) đã 3 lần kéo sập
host VM 12 GB:

| Incident | Triggering step | Root cause |
|----------|----------------|------------|
| `incident-falco-tetragon-ram-overcommit.md` | 25-falco | 2 eBPF DS (Falco + Tetragon) đẩy tổng limit lên 17 GiB > host 12 GiB → kernel swap thrash → control-plane lease lost → cascade OOMKill (metrics-server 137, tetragon 137 × 14 restart, cilium-operator CrashLoop, kube-controller-manager flapping). |
| `incident-gatekeeper-crd-timeout.md` | 26-gatekeeper | Helm install Gatekeeper trên host load-avg = 191 → apiserver trả 504 trên POST CRD → helm fail → orphan resources, cluster đã không recover được. |
| `incident-gatekeeper-probe-webhook-stuck.md` | 26-gatekeeper | post-install Job `probeWebhook` curl loop chiếm slot trong khi controller-manager không schedule được vì RAM cạn → helm hang → mỗi lần helm retry tạo thêm Job + RS → host OOM → "Total pods: 0". |

Common thread: **cùng kernel duy nhất, scheduler không biết kernel sắp chết**.

## 2. Kind là gì và tại sao nó kẹt

Kind chạy mỗi "node" trong **một container Docker**, share kernel với host:

```
Host VM (12 GiB)
├─ kernel
├─ Docker daemon
│   ├─ kind-control-plane container (cgroup limit, but same kernel)
│   ├─ kind-worker  container
│   ├─ kind-worker2 container
│   └─ kind-worker3 container (ports 80/443/8200/8080/31000 mapped here)
└─ swap.img 4 GiB
```

Hệ quả:
- **OOM-killer hoạt động ở mức kernel**, không phân biệt cgroup nào "đáng
  giết" hơn. Khi tổng RSS chạm RAM, kernel killer chọn process có
  oom_score_adj cao nhất — thường là Tetragon hoặc apiserver, KHÔNG phải
  pod nặng nhất.
- **Scheduler thấy 4 node** với resource quota tách biệt nhưng kernel
  pressure là chung. `kubectl top node` hiển thị OK trong khi `dmesg` đầy
  oom_reaper.
- Pre-flight `MIN_FREE_MIB=1500` (xem `scripts/utils/zta-common.sh
  require_host_ram_mi`) là band-aid: nó kiểm tra host trước install, nhưng
  không ngăn pod chạy đã rồi swell sau đó.

## 3. Tại sao multi-VM giải quyết

Mỗi VM = **kernel độc lập + RAM riêng**. Khi pod nặng trên VM `7189srv04`
(vault-prod, MySQL, Kafka, ES, Prometheus) làm pressure ở đó, etcd trên
VM `7189srv01` không hề bị ảnh hưởng. Kubernetes scheduler bây giờ TRÁNH được node sắp full RAM
một cách thật sự (vì kubelet trên node đó báo `MemoryPressure=true`, đẩy
NoSchedule taint).

Ngoài ra:
- **Networking thật**: pod-to-pod đi qua VXLAN-over-Tailscale, trùng với
  pattern production (Cilium tunnel). Hubble flows phản ánh đúng path
  cross-node, không còn "loopback giả" trong Kind.
- **Storage tách**: hostPath bind mount của Kind ánh xạ 1 thư mục host →
  4 nodes thấy chung dữ liệu (lỗi giả về StatefulSet pinning). Multi-VM
  buộc PVC phải pin node hoặc dùng RWX (NFS / longhorn). Đây là "real
  posture" mà thesis ZTA cần demo (DAAS classification chap 18).
- **Failure isolation**: VM crash ⇒ chỉ mất pod trên VM đó, etcd vẫn
  online (có thể demo node-drain → reschedule).

## 4. Trade-off vs Kind

| Hạng mục | Kind (cũ) | Multi-VM kubeadm (mới) |
|----------|-----------|-------------------------|
| Setup time | 5 phút | 30-45 phút lần đầu |
| RAM total trên host | 12 GiB chung | 12.8 + 8 = 20.8 GiB |
| Startup-to-cluster-ready | < 3 phút | ~5 phút (kubeadm + cilium + join) |
| Failure blast radius | Whole cluster | 1 node only |
| Tetragon DS RAM | ~256 Mi/node × 4 = 1 GiB chung kernel | 256 Mi/node × 4 = 1 GiB phân tán ở 4 kernel |
| OOMKill cascade tới control-plane | THẤY rồi (3 incident) | Khó xảy ra (7189srv01 cô lập) |
| Reproducibility (zero state → cluster up) | `kind delete && create` | `kubeadm reset && init && join × 3` |
| Tailscale-aware nodeIP | N/A (Kind tự gen `172.18.x`) | Phải set `--node-ip=100.64.x.y` |
| LoadBalancer / Ingress | hostPort 80/443 mapped vào worker3 | NodePort + Tailscale exit / MetalLB |

## 5. Khi nào KHÔNG nên migrate

- Nếu chỉ chạy demo 30 phút rồi tắt: Kind đủ và rẻ hơn.
- Nếu thesis chỉ cần single-node evidence: giữ Kind cho repeatable.
- Nếu Tailnet không stable trong WiFi của môi trường demo (sân khấu, hội
  trường) → dự phòng plan B = chạy Kind trên Ubuntu host làm fallback.

## 6. Migration timeline ước tính

(Sau khi user duyệt plan này.)

| Ngày | Việc | Output |
|------|------|--------|
| D+0 | Tạo 4 VM, cài Debian 13 "Trixie", Tailscale auth | 4 host SSH-able qua tailnet |
| D+1 | Run `06-debian-base-prep.md` (containerd, sysctl, kubeadm) | `kubeadm init` ready |
| D+2 | `kubeadm init` 7189srv01 + join 3 worker + Cilium 1.19 | `kubectl get nodes` 4 Ready |
| D+3 | Adapt + run `02-deploy-infrastructure.sh` → `03-deploy-microservices.sh` → `05-seed-databases.sh` | App layer up |
| D+4 | `08-harden-security.sh` (mTLS only, WireGuard SKIP — Tailscale đã làm) → `09-verify-zta.sh` | Verify pass 35-50 test |
| D+5 | `10-deploy-tetragon.sh` + `--full-enforcement` (SPIRE, Cosign, Hubble export, Gatekeeper) | Optimal ZTA |

Tổng: 1 tuần làm thật, sau khi plan chốt.
