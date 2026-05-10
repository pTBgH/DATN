# Migration scripts — `git pull` rồi chạy `.sh`

> Đây là **toolkit thực thi** kèm `doc/migration/01..13-*.md`. Bạn chạy
> đúng theo thứ tự, mỗi script idempotent (re-run an toàn) và có
> try/catch + rollback.
>
> **Đọc kỹ trước khi chạy** — nhất là `00-PRECHECK.md` và
> `../ANSWERS.md`. Đây là máy ảo thật, mất data thì không hoàn lại được
> (mặc dù theo bạn nói "PVC restart không mất" cũng đỡ một phần).

---

## Cách dùng tổng thể

```bash
# 1. Trên cả 4 VM (srv01..04): clone & chuẩn bị
git clone https://github.com/bpt05/DATN.git
cd DATN
git pull          # đảm bảo lấy bản mới nhất
cp doc/migration/scripts/config.env.example doc/migration/scripts/config.env
nano doc/migration/scripts/config.env   # set TAILNET_DOMAIN, TS_AUTHKEY...

# 2. Trên MỖI VM: status report TRƯỚC khi đụng vào
bash doc/migration/scripts/00-status-report.sh

# 3. Trên MỖI VM: host prep
sudo HOSTNAME_OVERRIDE=7189srv01 -E bash doc/migration/scripts/01-host-prep.sh   # trên srv01
sudo HOSTNAME_OVERRIDE=7189srv02 -E bash doc/migration/scripts/01-host-prep.sh   # trên srv02
# ...etc

# 4. Trên srv01: init control plane
sudo -E bash doc/migration/scripts/02-control-plane-init.sh
# ... lưu lại lệnh kubeadm join từ output (cũng có sẵn trong /etc/kubernetes/zta-join.sh)

# 5. Trên srv02/03/04: paste join command
sudo cat /etc/kubernetes/zta-join.sh   # nếu đã copy từ srv01
# hoặc:
echo 'kubeadm join 100.64.10.1:6443 --token ... --discovery-token-ca-cert-hash sha256:...' \
  | sudo tee /etc/kubernetes/zta-join.cmd
sudo -E bash doc/migration/scripts/03-worker-join.sh

# 6. Trên srv01 (hoặc admin laptop có kubeconfig): cài Cilium
bash doc/migration/scripts/04-cilium-install.sh

# 7. Trên srv01: cài cluster services
bash doc/migration/scripts/05-cluster-services.sh

# 8. Status report SAU mỗi phase
bash doc/migration/scripts/00-status-report.sh
ls -la ~/.zta-migration/reports/
```

---

## Mỗi script làm gì + rollback

| # | Script | Chạy ở đâu | Phải sudo? | Rollback gồm |
|---|--------|-----------|-----------|--------------|
| 00 | `00-status-report.sh` | mọi VM | không | (không state change) |
| 01 | `01-host-prep.sh` | mọi VM | có | revert containerd config, sysctl, modules; remove kubeadm tooling (chỉ với --force) |
| 02 | `02-control-plane-init.sh` | srv01 ONLY | có | `kubeadm reset --force`, xóa CNI, kubeconfig user |
| 03 | `03-worker-join.sh` | srv02/03/04 | có | `kubeadm reset --force` (rời cluster) |
| 04 | `04-cilium-install.sh` | srv01 hoặc admin | không | `helm uninstall cilium` |
| 05 | `05-cluster-services.sh` | srv01 hoặc admin | không | `helm uninstall cert-manager/ingress-nginx/metrics-server` + xóa StorageClass alias |
| 99 | `99-rollback.sh` | tùy phase | có (cho phase 01-03) | gọi rollback của phase tương ứng |

### Rollback flow

Mỗi script có 2 mức rollback:

1. **Auto-rollback** khi gặp ERR (default `ZTA_AUTO_ROLLBACK=1`):
   trap `ERR` → chạy stack rollback đã đăng ký theo thứ tự ngược lại.

2. **Forced rollback** sau khi đã hoàn thành phase (nếu cần undo):
   ```bash
   sudo bash doc/migration/scripts/99-rollback.sh --force --phase=02-control-plane-init
   ```

---

## Idempotency markers

State files trong `~/.zta-migration/`:

```
~/.zta-migration/
├── 01-host-prep.state              # "completed" / "failed line=... cmd=..."
├── 02-control-plane-init.state
├── 03-worker-join.state
├── 04-cilium-install.state
├── 05-cluster-services.state
├── done.apt-base                    # mark per-step idempotency
├── done.containerd-installed
├── done.kube-installed
├── logs/
│   ├── 01-host-prep-20260510T...log
│   ├── 02-control-plane-init-...log
│   └── ...
└── reports/
    ├── 00-status-7189srv01-20260510T...md   # MD reports for each run
    └── ...
```

---

## Variables (config.env)

| Var | Default | Mục đích |
|-----|---------|----------|
| `TAILNET_DOMAIN` | `<your>.ts.net` | MagicDNS domain (login.tailscale.com → DNS) |
| `TS_AUTHKEY` | _empty_ | Reusable auth key. Nếu bỏ trống, script bảo bạn `tailscale up` thủ công. |
| `CP_HOSTNAME` | `7189srv01` | Hostname của control-plane VM |
| `WORKER_HOSTNAMES` | `7189srv02 7189srv03 7189srv04` | Space-separated |
| `DATA_NODE` | `7189srv04` | Node được pin stateful |
| `KUBE_VERSION` | `1.30.0` | Full k8s version |
| `KUBE_MINOR` | `1.30` | minor cho apt repo |
| `CILIUM_VERSION` | `1.19.1` | |
| `POD_CIDR` | `10.244.0.0/16` | Tránh conflict với `100.64/10` Tailscale |
| `SVC_CIDR` | `10.96.0.0/12` | |
| `CLUSTER_NAME` | `job7189` | Verify scripts khớp với cũ |
| `RESOURCE_PROFILE` | `tight` | `tight` cho srv04=4GB; `normal` cho srv04=6GB |
| `REGISTRY_NODEPORT` | `30005` | NodePort docker-registry |
| `HTTP_NODEPORT` | `30003` | NodePort ingress-nginx HTTP |
| `HTTPS_NODEPORT` | `30001` | NodePort ingress-nginx HTTPS |

---

## Phổ biến: error scenarios + cách xử lý

### Lỗi: `kubeadm init` fail, cluster nửa state

```bash
# Auto-rollback đã chạy. Xem log:
ls -lt ~/.zta-migration/logs/02-control-plane-init-*.log | head -1
tail -50 $(ls -t ~/.zta-migration/logs/02-control-plane-init-*.log | head -1)

# Sau khi sửa nguyên nhân, re-run:
sudo -E bash doc/migration/scripts/02-control-plane-init.sh
```

### Lỗi: worker không join được — token expired

Trên srv01:
```bash
sudo kubeadm token create --print-join-command \
  | sudo tee /etc/kubernetes/zta-join.sh
sudo cat /etc/kubernetes/zta-join.sh   # paste sang worker
```

Trên worker:
```bash
echo '<paste here>' | sudo tee /etc/kubernetes/zta-join.cmd
sudo -E bash doc/migration/scripts/03-worker-join.sh
```

### Lỗi: cilium-agent CrashLoop

```bash
kubectl -n kube-system logs ds/cilium -c cilium-agent --previous \
  | tail -30
# Thường là k8sServiceHost sai. Check config.env CP_HOSTNAME / Tailscale IP của srv01.
# Re-run:
bash doc/migration/scripts/04-cilium-install.sh
```

### Lỗi: muốn bắt đầu lại từ 0

```bash
# Trên TỪNG VM theo thứ tự ngược:
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=05-cluster-services   # admin/srv01
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=04-cilium-install     # admin/srv01
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=03-worker-join        # mỗi worker
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=02-control-plane-init # srv01
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=01-host-prep          # mọi VM
```

---

## Câu hỏi của bạn

Xem `../ANSWERS.md`:
- Control plane sập → ảnh hưởng host Ubuntu? **KHÔNG** (chi tiết trong file)
- Tên user `ptb` quan trọng? **Không** — không cần đổi sang `7189`

---

## Test "khô" trước khi chạy thật

Trước khi chạy script destructive trên VM thật, dùng `ZTA_DRY_RUN=1` để
xem các lệnh sẽ chạy mà không thực sự execute:

```bash
sudo ZTA_DRY_RUN=1 -E bash doc/migration/scripts/01-host-prep.sh
sudo ZTA_DRY_RUN=1 -E bash doc/migration/scripts/02-control-plane-init.sh
ZTA_DRY_RUN=1 bash doc/migration/scripts/04-cilium-install.sh
```

`ZTA_DRY_RUN=1` log mỗi lệnh nhưng skip thực thi. Pre-flight check vẫn
chạy (đó là điều chúng ta MUỐN — verify môi trường).

---

## Tham chiếu nhanh

- Migration plan tổng: `../README.md`
- Sizing chi tiết: `../03-vm-sizing.md` (đã update srv04=4GB)
- Network design: `../04-network-tailscale-cilium.md`
- ZTA pipeline adaptations: `../10-zta-pipeline-adaptations.md`
- Recovery runbook: `../12-runbook-recovery.md`
- Validation checklist: `../13-validation-checklist.md`
