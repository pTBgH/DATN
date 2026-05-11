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
| `KUBE_VERSION` | `1.30.14` | Full k8s patch version, dùng cho binary download từ `dl.k8s.io` |
| `KUBE_MINOR` | `1.30` | minor (legacy field, không còn dùng cho apt repo) |
| `CRICTL_VERSION` | `v1.30.1` | crictl pinned compatible với KUBE_VERSION |
| `CNI_PLUGINS_VERSION` | `v1.5.1` | CNI plugins (loopback, host-local, ...) |
| `KUBE_RELEASE_TEMPLATE_VERSION` | `v0.18.0` | kubelet.service template từ `kubernetes/release` |
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

## Troubleshooting

### `01-host-prep.sh` lỗi ở step "apt update for k8s repo"

Triệu chứng (Debian 13 Trixie, từ 2026-02-01):

```
W: OpenPGP signature verification failed: ... pkgs.k8s.io ...
   Sub-process /usr/bin/sqv returned an error code (1), error message is:
   Error: Policy rejected packet type
   Caused by:
       Signature Packet v3 is not considered secure since 2026-02-01T00:00:00Z
E: The repository 'https://pkgs.k8s.io/core:/stable:/v1.30/deb  InRelease' is not signed.
```

Nguyên nhân: Debian 13 dùng `sqv` (Sequoia PGP) làm signature verifier
mặc định cho apt, reject GPG v3 packets sau 2026-02-01. Repo
`pkgs.k8s.io` vẫn ký bằng v3 → bị block.

Fix: script đã chuyển sang **binary install từ `dl.k8s.io`** (không qua
apt). Pull commit mới và re-run:

```bash
cd ~/projects/DATN
git pull
sudo HOSTNAME_OVERRIDE=7189srvXX -E bash doc/migration/scripts/01-host-prep.sh
```

Script idempotent — phần đã done (Tailscale, sysctl, containerd) bị
skip, chỉ chạy lại STEP 6 mới.

Nếu trên máy đã có legacy apt repo từ run cũ bị fail:

```bash
sudo rm -f /etc/apt/sources.list.d/kubernetes.list /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt-get update
```

### Tailscale IP CGNAT khác `100.64.10.x`

Tailscale gán IP từ `100.64.0.0/10` ngẫu nhiên. Ví dụ user của bạn dùng
`100.114.68.15`. KHÔNG sao — script `02-control-plane-init.sh` tự đọc
`tailscale ip -4` runtime, không hardcode IP. config.env không cần
declare CP_TS_IP.

### `kubelet: command not found` sau khi 01-host-prep.sh ok

Có thể PATH chưa include `/usr/local/bin/`. Kiểm tra:
```bash
ls -la /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl
echo $PATH | tr ':' '\n' | grep -i local
```
Nếu binaries có nhưng PATH thiếu: `export PATH="/usr/local/bin:$PATH"`
hoặc relogin shell. Script v2 đã tự normalize PATH ở `lib/common.sh`.

### Step 7 verify báo "containerd: command not found" + auto-rollback

Triệu chứng (đã từng xảy ra trên srv01):
```
2026-...Z [STEP ] [7/7] Verify
doc/migration/scripts/01-host-prep.sh: line 299: containerd: command not found
2026-...Z [ERROR] Failed at line 299: head -1
2026-...Z [WARN ] Auto-rollback ON — undoing recorded actions in reverse order
```

Nguyên nhân (3 bug cascade — đã fix trong v2):
1. `sudo -E` preserve PATH của user → `/usr/bin/containerd` không nằm trong PATH → verify line fail.
2. Verify line nằm trong `$(...)` substitution → ERR trap fire trong subshell, **không exit script** → script tiếp tục, các verify line khác cũng fail → rollback chạy **nhiều lần**.
3. `mark_done` viết marker file nhưng rollback KHÔNG dọn marker → run tiếp theo skip step đó, dù binary đã bị rollback xóa → **state không nhất quán**.

Recovery nếu bạn vẫn còn ở trạng thái cũ:
```bash
# Trên VM bị stuck:
sudo rm -f ~/.zta-migration/done.* ~/.zta-migration/*.state
# Verify cluster state (nên sạch):
ls /usr/bin/containerd /usr/local/bin/kube* 2>/dev/null
# Pull patch v2 và chạy lại — script tự kiểm tra binary presence khi gặp marker:
cd ~/projects/DATN && git pull
sudo HOSTNAME_OVERRIDE=7189srv01 -E bash doc/migration/scripts/01-host-prep.sh
```

Fix v2 đã làm trong `lib/common.sh`:
- `shopt -s inherit_errexit` → errexit propagate vào `$()`.
- `mark_done` tự động register rollback "rm marker" → rollback dọn marker.
- `already_done_and "<key>" "<presence-check>"` → check cả marker VÀ binary presence; nếu marker stale, tự xóa và redo step.
- `migration_end` clear rollback stack → exit normal không trigger stale undo.
- `_zta_rollback` clear stack sau khi chạy → không re-run nhiều lần.
- `_zta_on_err` `exit "$rc"` explicit + disable ERR trap re-entry.
- PATH normalize: `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` prepend ngay đầu mỗi script.

Fix v2 trong `01-host-prep.sh`:
- STEP 7 verify dùng `_verify_probe` helper: subshell ALWAYS exit 0; log `<label>: not found` nếu binary thiếu, không trigger ERR trap.
- STEP 5+6 skip-condition: dùng `already_done_and` thay vì `already_done` — defense-in-depth nếu marker còn nhưng binary đã bị xóa.

---

## Tham chiếu nhanh

- Migration plan tổng: `../README.md`
- Sizing chi tiết: `../03-vm-sizing.md` (đã update srv04=4GB)
- Network design: `../04-network-tailscale-cilium.md`
- ZTA pipeline adaptations: `../10-zta-pipeline-adaptations.md`
- Recovery runbook: `../12-runbook-recovery.md`
- Validation checklist: `../13-validation-checklist.md`
