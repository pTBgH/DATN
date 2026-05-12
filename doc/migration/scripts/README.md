# Migration scripts — chạy `bootstrap.sh` trên TỪNG VM

> Đây là **toolkit thực thi** kèm `doc/migration/01..13-*.md`. Mọi thứ
> đã được gói vào **một entry-point duy nhất** `bootstrap.sh`. Bạn chạy
> nó **trên từng VM** với `--server=NN`. Mỗi phase idempotent (re-run
> an toàn) và có try/catch + rollback.
>
> **Đọc kỹ trước khi chạy** — nhất là `00-PRECHECK.md` và
> `../ANSWERS.md`. Đây là máy ảo thật, mất data thì không hoàn lại được.

---

## Quick start — 4 lệnh cho 4 VM

```bash
# Trên cả 4 VM: clone repo + tạo config.env (1 lần)
git clone https://github.com/bpt05/DATN.git ~/projects/DATN
cd ~/projects/DATN
cp doc/migration/scripts/config.env.example doc/migration/scripts/config.env
nano doc/migration/scripts/config.env          # set TAILNET_DOMAIN, TS_AUTHKEY...

# Sau đó MỖI VM chỉ chạy ĐÚNG 1 lệnh:
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --yes   # trên 7189srv01
sudo -E bash doc/migration/scripts/bootstrap.sh --server=02 --yes   # trên 7189srv02
sudo -E bash doc/migration/scripts/bootstrap.sh --server=03 --yes   # trên 7189srv03
sudo -E bash doc/migration/scripts/bootstrap.sh --server=04 --yes   # trên 7189srv04
```

`bootstrap.sh` tự suy ra **role** (control-plane vs worker) từ `--server=NN`
+ inventory trong `config.env`, rồi chạy đúng chuỗi phase cần thiết:

| Role | Phase sequence |
|------|----------------|
| control-plane (srv01) | host-prep → control-plane → cilium → cluster-services |
| worker (srv02/03/04)  | host-prep → worker-join |

Trên control-plane, sau khi `02-control-plane` chạy xong, join command được
lưu vào `/etc/kubernetes/zta-join.sh`. Mỗi worker khi chạy `bootstrap.sh
--server=NN` sẽ tự fetch token theo thứ tự sau:

1. **`$ZTA_JOIN_CMD`** — nếu bạn export biến này trước (nhanh nhất khi
   bạn paste từ clipboard).
2. **`/etc/kubernetes/zta-join.cmd`** — file local nếu bạn `scp` từ srv01.
3. **`SSH_FETCH=1`** — worker tự `ssh ptb@${CP_HOSTNAME}` nếu có passwordless SSH.

---

## CLI của `bootstrap.sh`

```text
sudo -E bash doc/migration/scripts/bootstrap.sh \
    [--server=NN | --server=auto] \
    [--phase=NAME[,NAME...]] \
    [--from=NAME] [--to=NAME] [--skip=NAME[,NAME...]] \
    [--list] [--dry-run] [--yes] [--continue-on-fail]
```

| Flag | Mục đích |
|------|----------|
| `--server=01..04` | Server ID — bắt buộc (trừ khi `--list` standalone) |
| `--server=auto`   | Tự đọc `hostname` của VM hiện tại |
| `--phase=NAME`    | Chỉ chạy phase này (lặp được, `--phase=cilium,cluster-services`) |
| `--from=NAME`     | Resume từ phase này (inclusive) |
| `--to=NAME`       | Stop sau phase này (inclusive) |
| `--skip=NAME`     | Skip phase (vẫn theo thứ tự gốc) |
| `--list`          | In ra inventory + plan, không thực thi |
| `--dry-run`       | Mô phỏng — không gọi phase script |
| `--yes`           | Không hỏi xác nhận |
| `--continue-on-fail` | Tiếp tục dù phase fail (mặc định halt) |

### Ví dụ

```bash
# Inspect — không cần sudo, không thực thi:
bash doc/migration/scripts/bootstrap.sh --list
bash doc/migration/scripts/bootstrap.sh --server=01 --list
bash doc/migration/scripts/bootstrap.sh --server=02 --dry-run --yes

# Chỉ cài lại Cilium trên srv01 (cluster đã up):
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=cilium --yes

# Resume sau khi host-prep + control-plane đã xong, chạy cilium tiếp:
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --from=cilium --yes

# Bỏ qua cluster-services lần này (sẽ chạy sau, ví dụ sau khi all workers joined):
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --skip=cluster-services --yes

# Worker: paste join cmd qua env var (cách clean nhất):
export ZTA_JOIN_CMD="kubeadm join 100.X.Y.Z:6443 --token ... --discovery-token-ca-cert-hash sha256:..."
sudo -E bash doc/migration/scripts/bootstrap.sh --server=02 --yes
```

---

## Cấu trúc thư mục

```
doc/migration/scripts/
├── bootstrap.sh                  # entry-point — bạn chỉ gọi script này
├── 0[1-5]-*.sh                   # backward-compat wrappers (vẫn chạy được)
├── 00-status-report.sh           # diagnostic snapshot (không state change)
├── 99-rollback.sh                # forced rollback theo phase name
├── config.env.example            # mẫu — copy sang config.env trước khi chạy
├── README.md                     # file này
├── lib/
│   ├── common.sh                 # logging + rollback stack + try/catch
│   └── inventory.sh              # server-id ↔ hostname ↔ role mapping
└── phases/                       # phase scripts — bootstrap.sh gọi
    ├── host-prep.sh
    ├── control-plane.sh
    ├── worker-join.sh
    ├── cilium.sh
    └── cluster-services.sh
```

**Backward compat**: `01-host-prep.sh`, `02-control-plane-init.sh`,
`03-worker-join.sh`, `04-cilium-install.sh`, `05-cluster-services.sh` ở
top-level vẫn chạy được — chúng là wrapper mỏng `exec phases/<name>.sh
"$@"`. Bạn không cần đổi muscle memory cũ, nhưng `bootstrap.sh` clean
hơn nhiều.

---

## Mỗi phase làm gì + rollback

| Phase | Chạy ở đâu | Cần sudo? | Rollback gồm |
|-------|-----------|-----------|--------------|
| `host-prep` | mọi VM | có | revert containerd config, sysctl, modules; remove kubeadm tooling (chỉ với `--force` qua 99-rollback) |
| `control-plane` | srv01 ONLY | có | `kubeadm reset --force`, xóa CNI, kubeconfig user |
| `worker-join` | srv02/03/04 | có | `kubeadm reset --force` (rời cluster) |
| `cilium` | srv01 hoặc admin | có (nếu auto-install helm) | `helm uninstall cilium` |
| `cluster-services` | srv01 hoặc admin | có | `helm uninstall cert-manager/ingress-nginx/metrics-server` + xóa StorageClass alias |

### Rollback flow

Mỗi phase có 2 mức:

1. **Auto-rollback** khi gặp ERR (default `ZTA_AUTO_ROLLBACK=1`):
   trap `ERR` → chạy stack rollback đã đăng ký theo thứ tự ngược lại.

2. **Forced rollback** sau khi đã hoàn thành phase (nếu cần undo):
   ```bash
   sudo bash doc/migration/scripts/99-rollback.sh --force --phase=control-plane
   ```

---

## Idempotency markers + per-run logs

State files trong `~/.zta-migration/`:

```
~/.zta-migration/
├── runs/
│   └── 20260512T080741Z/             # 1 thư mục cho mỗi lần bootstrap.sh chạy
│       ├── banner.txt
│       ├── host-prep.log
│       ├── control-plane.log
│       ├── cilium.log
│       ├── cluster-services.log
│       └── SUMMARY.md                # status từng phase + duration + log path
├── logs/                              # per-phase logs (giữ qua các run)
│   ├── host-prep-20260512T...log
│   └── ...
├── reports/                           # 00-status-report.sh output
│   └── 00-status-7189srv01-...md
├── done.apt-base                      # per-step idempotency markers
├── done.containerd-installed
└── done.kube-installed
```

Mỗi run bootstrap.sh có 1 `SUMMARY.md` riêng — đây là nơi đầu tiên check
khi muốn biết "đã chạy gì, fail ở đâu".

---

## Variables (`config.env`)

| Var | Default | Mục đích |
|-----|---------|----------|
| `TAILNET_DOMAIN` | `<your>.ts.net` | MagicDNS domain (login.tailscale.com → DNS) |
| `TS_AUTHKEY` | _empty_ | Reusable auth key. Bỏ trống → script bảo bạn `tailscale up` thủ công. |
| `CP_HOSTNAME` | `7189srv01` | Hostname của control-plane VM |
| `WORKER_HOSTNAMES` | `7189srv02 7189srv03 7189srv04` | Space-separated |
| `DATA_NODE` | `7189srv04` | Node được pin stateful |
| `KUBE_VERSION` | `1.30.14` | Full k8s patch version, dùng cho binary download từ `dl.k8s.io` |
| `KUBE_MINOR` | `1.30` | minor (legacy field, không còn dùng cho apt repo) |
| `CRICTL_VERSION` | `v1.30.1` | crictl pinned compatible với KUBE_VERSION |
| `CNI_PLUGINS_VERSION` | `v1.5.1` | CNI plugins (loopback, host-local, ...) |
| `KUBE_RELEASE_TEMPLATE_VERSION` | `v0.18.0` | kubelet.service template |
| `CILIUM_VERSION` | `1.19.1` | |
| `POD_CIDR` | `10.244.0.0/16` | Tránh conflict với `100.64/10` Tailscale |
| `SVC_CIDR` | `10.96.0.0/12` | |
| `CLUSTER_NAME` | `job7189` | Cluster name dùng cho Cilium cluster-mesh |
| `RESOURCE_PROFILE` | `tight` | `tight` cho srv04=4GB; `normal` cho srv04=6GB |
| `REGISTRY_NODEPORT` | `30005` | NodePort docker-registry |
| `HTTP_NODEPORT` | `30003` | NodePort ingress-nginx HTTP |
| `HTTPS_NODEPORT` | `30001` | NodePort ingress-nginx HTTPS |

---

## Test "khô" trước khi chạy thật

Hai tầng dry-run, chọn cái phù hợp:

```bash
# 1. bootstrap.sh dry-run — chỉ in plan, không gọi phase nào:
bash doc/migration/scripts/bootstrap.sh --server=01 --dry-run --yes

# 2. ZTA_DRY_RUN=1 inside a phase — pre-flight chạy, command nội bộ log nhưng không thực thi:
sudo ZTA_DRY_RUN=1 -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=host-prep --yes
```

`ZTA_DRY_RUN=1` log mỗi lệnh nhưng skip thực thi. Pre-flight check vẫn
chạy (đó là điều chúng ta MUỐN — verify môi trường).

---

## Phổ biến: error scenarios + cách xử lý

### Lỗi: `kubeadm init` fail, cluster nửa state

```bash
# Auto-rollback đã chạy. Xem SUMMARY của lần chạy gần nhất:
ls -lt ~/.zta-migration/runs/ | head -3
cat ~/.zta-migration/runs/<TS>/SUMMARY.md

# Sau khi sửa nguyên nhân, re-run chỉ phase này:
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=control-plane --yes
```

### Lỗi: worker không join được — token expired

Trên srv01:
```bash
sudo kubeadm token create --print-join-command \
  | sudo tee /etc/kubernetes/zta-join.sh
sudo cat /etc/kubernetes/zta-join.sh   # paste sang worker
```

Trên worker — 3 cách trao token cho `worker-join`:

```bash
# Cách 1 (đơn giản nhất): paste vào env var
export ZTA_JOIN_CMD="kubeadm join 100.X.Y.Z:6443 --token ... --discovery-token-ca-cert-hash sha256:..."
sudo -E bash doc/migration/scripts/bootstrap.sh --server=02 --yes

# Cách 2: paste vào file local
echo 'kubeadm join 100.X.Y.Z:6443 --token ... ...' | sudo tee /etc/kubernetes/zta-join.cmd
sudo -E bash doc/migration/scripts/bootstrap.sh --server=02 --yes

# Cách 3: SSH fetch (cần passwordless SSH worker→CP):
sudo SSH_FETCH=1 -E bash doc/migration/scripts/bootstrap.sh --server=02 --yes
```

### Lỗi: cilium-agent CrashLoop / Init:Error

```bash
# Pod nào fail:
kubectl -n kube-system get pods -l k8s-app=cilium
POD=$(kubectl -n kube-system get pod -l k8s-app=cilium -o name | head -1)

# Init container nào fail:
kubectl -n kube-system describe $POD | sed -n '/Init Containers/,/^Conditions/p' | head -100
for c in config mount-cgroup apply-sysctl-overwrites mount-bpf-fs clean-cilium-state install-cni-binaries; do
  echo "=== $c ==="
  kubectl -n kube-system logs $POD -c $c --tail=30 2>&1
done

# Re-install:
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=cilium --yes
```

**Known issue**: `mount-cgroup` báo `cp: cannot create regular file
'/hostbin/cilium-mount': Permission denied` → root cause là
`/opt/cni/bin` owned UID 1001 từ tarball gốc của upstream `cni-plugins`,
Cilium init container có `capabilities.drop=ALL` (no `DAC_OVERRIDE`)
nên root trong container không write được. Fix v3 (PR #9):
`host-prep.sh` extract với `--no-same-owner` + `chown -R root:root
/opt/cni`. Trên host cũ chưa có fix, chỉ cần:

```bash
sudo chown -R root:root /opt/cni
kubectl -n kube-system delete pods -l k8s-app=cilium    # recreate
```

### Lỗi: muốn bắt đầu lại từ 0

```bash
# Trên TỪNG VM theo thứ tự ngược:
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=cluster-services   # admin/srv01
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=cilium              # admin/srv01
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=worker-join         # mỗi worker
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=control-plane       # srv01
sudo bash doc/migration/scripts/99-rollback.sh --force --phase=host-prep           # mọi VM
```

---

## Troubleshooting (legacy issues — đã fix)

### `01-host-prep.sh` lỗi ở step "apt update for k8s repo"

Debian 13 Trixie + sqv reject GPG v3 packets → repo `pkgs.k8s.io` block.
Đã chuyển sang binary install từ `dl.k8s.io`. Pull commit mới và re-run.

### Tailscale IP CGNAT khác `100.64.10.x`

Tailscale gán IP từ `100.64.0.0/10` ngẫu nhiên. KHÔNG sao —
`control-plane.sh` tự đọc `tailscale ip -4` runtime, không hardcode IP.

### `kubelet: command not found` sau khi host-prep ok

PATH chưa include `/usr/local/bin/`. `lib/common.sh` v2 tự normalize
PATH ở đầu mỗi script (`/usr/local/sbin:/usr/local/bin:...`).

### Step 7 verify báo "containerd: command not found" + auto-rollback

3-bug cascade đã fix trong v2 (PR #6). Recovery nếu vẫn còn trạng thái cũ:

```bash
sudo rm -f ~/.zta-migration/done.* ~/.zta-migration/*.state
cd ~/projects/DATN && git pull
sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=host-prep --yes
```

---

## Tham chiếu nhanh

- Migration plan tổng: `../README.md`
- Sizing chi tiết: `../03-vm-sizing.md` (đã update srv04=4GB)
- Network design: `../04-network-tailscale-cilium.md`
- ZTA pipeline adaptations: `../10-zta-pipeline-adaptations.md`
- Recovery runbook: `../12-runbook-recovery.md`
- Validation checklist: `../13-validation-checklist.md`
