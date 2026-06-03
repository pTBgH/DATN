# 00. Pre-check — đọc TRƯỚC khi chạy bất kỳ script nào

> Đây là checklist OPS bạn **PHẢI** đi qua trước khi cho phép script
> đụng vào máy ảo thật. User đã nhấn mạnh: "rất ít chỗ cho sự sai sót".

---

## A. Trên 2 host vật lý (Windows + Ubuntu)

| # | Check | Cách verify | Pass nếu |
|---|-------|-------------|----------|
| A1 | Windows host có ≥ 13 GB RAM trống cho 3 VM (2 + 4.5 + 5.0 = 11.5 GB + overhead) | Task Manager → Performance → Memory | **Available ≥ 13 GB** |
| A2 | Ubuntu host có ≥ 4 GB RAM trống cho 1 VM (chính bạn còn 4 GB cho app khác) | `free -h` trên Ubuntu host | **available ≥ 4.5 GB** |
| A3 | Disk space: Windows host ≥ 150 GB free (3 VM × 50 GB) | `dir D:\` hoặc disk gì bạn cài VM | **≥ 150 GB free** |
| A4 | Disk space: Ubuntu host ≥ 70 GB free | `df -h /var/lib/libvirt` hoặc nơi cài VM | **≥ 70 GB free** |
| A5 | VMware Workstation Player/Pro đã hoạt động bình thường, đã từng chạy ít nhất 1 VM thành công | (kinh nghiệm) | OK |
| A6 | Tailscale account có sẵn, account của bạn admin của tailnet | https://login.tailscale.com/admin/machines | OK — xem [`TAILSCALE-SETUP.md`](TAILSCALE-SETUP.md) nếu chưa có |
| A7 | Ubuntu host vẫn truy cập internet (cần để VM pull image lúc bootstrap) | `curl -I https://google.com` | 200 |
| A8 | Có 1 reusable Tailscale auth key, tag `tag:zta-cluster` (chưa expire) | https://login.tailscale.com/admin/settings/keys | OK |
| A9 | Tailscale đã cài trên Ubuntu host và có IP `100.64.x.y` | `tailscale ip -4` trên Ubuntu host | trả về IP CGNAT |
| A10 | Docker registry (`registry:2`) chạy trên Ubuntu host port 5000 | `curl http://localhost:5000/v2/_catalog` trên Ubuntu host | trả về JSON — xem [`REGISTRY-DECISION.md`](REGISTRY-DECISION.md) |

---

## B. Bốn VM đã được tạo + Debian 13 đã cài

| # | Check | Cách verify | Pass nếu |
|---|-------|-------------|----------|
| B1 | 4 VM tồn tại trong VMware (3 trên Windows, 1 trên Ubuntu) | VMware GUI | OK |
| B2 | Sizing đúng (theo `03-vm-sizing.md` revised 2026-05-10) | VMware → VM Settings | srv01=2GB/1c/40G, srv02=4.5GB/2c/50G, srv03=5GB/2c/50G, srv04=**4GB**/2c/60G |
| B3 | Hostname đã set đúng | `ssh ptb@<vm-vmnet-ip> hostname` | trả về `7189srv01..04` |
| B4 | OS Debian 13 (hoặc 12 cũng OK) | `cat /etc/os-release` | `VERSION_ID="13"` hoặc `"12"` |
| B5 | User `ptb` có sudo passwordless | `sudo -n ls /` | không hỏi password |
| B6 | SSH key login từ admin laptop | `ssh ptb@<vmnet-ip> 'echo ok'` | "ok" |
| B7 | Mỗi VM có ít nhất 5 GB free root disk | `ssh ptb@<host> df -h /` | `/` ≥ 5 GB free |

---

## C. Networking

| # | Check | Cách verify | Pass nếu |
|---|-------|-------------|----------|
| C1 | VM nào cũng có IP NAT từ VMware (cùng host) | `ip a` thấy `ens33` với 192.168.x.x | OK |
| C2 | VM ping được Internet | `ping -c 3 1.1.1.1` | 0% loss |
| C3 | DNS hoạt động | `getent ahosts github.com` | trả về IP |
| C4 | Firewall không block port 22, 6443, 8472, 30000-30100 trong VMnet8 | (mặc định OK; check nếu bạn customize) | Mặc định: pass |

---

## D. Repo + scripts

| # | Check | Cách verify | Pass nếu |
|---|-------|-------------|----------|
| D1 | Repo cloned trên cả 4 VM | `ls ~/DATN/knowledge-base/migration/scripts` | thấy 6 file `.sh` |
| D2 | Latest commit | `cd ~/DATN && git log --oneline -1` | matches origin/main |
| D3 | `config.env` đã được tạo và edit | `cat ~/DATN/knowledge-base/migration/scripts/config.env` | TAILNET_DOMAIN, TS_AUTHKEY (hoặc thủ công) đã set |
| D4 | Scripts có executable bit | `ls -la ~/DATN/knowledge-base/migration/scripts/*.sh` | `-rwxr-xr-x` |

Nếu D4 fail:
```bash
chmod +x ~/DATN/knowledge-base/migration/scripts/*.sh
```

---

## E. Sanity-check khô (chạy không destructive)

Trên MỖI VM:

```bash
cd ~/DATN

# 1. Status report — đọc kỹ output (sẽ tạo file .md trong ~/.zta-migration/reports/)
bash knowledge-base/migration/scripts/00-status-report.sh

# 2. Dry-run host prep (không thực thi, chỉ in lệnh)
sudo ZTA_DRY_RUN=1 HOSTNAME_OVERRIDE=$(hostname) -E \
  bash knowledge-base/migration/scripts/01-host-prep.sh

# Đọc lại output. Nếu thấy lệnh nào "lạ", DỪNG, ping mình review.
```

---

## F. Snapshot trước khi chạy thật

**ĐÂY LÀ BƯỚC SAFETY-NET QUAN TRỌNG NHẤT**.

Trước khi chạy `01-host-prep.sh` trên thật, **CHỤP VMware snapshot**
4 VM:

```
VMware GUI → VM → Snapshot → Take Snapshot
  Name: pre-zta-migration-2026-05-10
  Description: Clean Debian 13 minimal install before any ZTA scripts
```

Khi gặp lỗi không recover được:
```
VMware GUI → VM → Snapshot → Snapshot Manager → Revert to "pre-zta-migration-..."
```

→ VM trở về trạng thái sạch trong 30 giây. Mất nhanh hơn debug.

---

## G. Thứ tự chạy (chỉ làm khi A-F đều xanh)

```
Trên 4 VM (parallel OK)            sudo bash 01-host-prep.sh    [HOSTNAME_OVERRIDE=7189srvXX]
                                                  │
Trên srv01                         sudo bash 02-control-plane-init.sh
                                                  │
Trên srv02/03/04 (parallel OK)     sudo bash 03-worker-join.sh
                                                  │
Trên srv01 (hoặc admin laptop)     bash 04-cilium-install.sh
                                                  │
Trên srv01 (hoặc admin laptop)     bash 05-cluster-services.sh
                                                  │
Trên srv01                         bash scripts/zta-rebuild.sh --external-cluster --yes
                                   (đây là pipeline ZTA cũ, có sẵn trong repo)
```

Sau MỖI step:
```bash
bash knowledge-base/migration/scripts/00-status-report.sh
ls -t ~/.zta-migration/reports/ | head -3
```

---

## H. Khi gặp lỗi

1. **Đừng panic, đừng `kubeadm reset` thủ công**.
2. Đọc `~/.zta-migration/<phase>.state` — sẽ có `failed line=... cmd=...`.
3. Đọc log: `tail -100 ~/.zta-migration/logs/<phase>-*.log | head -200`
4. Auto-rollback đã chạy nếu `ZTA_AUTO_ROLLBACK=1` (default). Verify
   bằng status report.
5. Nếu cần re-run từ đầu (forced): `bash 99-rollback.sh --force --phase=<name>`.
6. Nếu bí 100%: revert VMware snapshot `pre-zta-migration-...`.

---

## I. Sau khi cluster lên xong

1. **Tạo VMware snapshot mới** trên cả 4 VM:
   ```
   Name: post-zta-baseline-<date>
   ```
   → Đây là baseline cho `12-runbook-recovery.md` §1.

2. **Backup kubeconfig**:
   ```bash
   scp ptb@7189srv01.<tailnet>.ts.net:/home/ptb/.kube/config \
       ~/keep-safe/zta-kubeconfig-$(date +%F).yaml
   ```

3. **Verify**:
   ```bash
   bash knowledge-base/migration/scripts/00-status-report.sh
   ls -t ~/.zta-migration/reports/ | head -1
   # Đọc kỹ file MD report. Tất cả "Quick assertions" phải PASS.
   ```

4. **Thông báo mình** (Devin) với link report MD, mình sẽ review trước
   khi chạy ZTA stack pipeline (`scripts/zta-rebuild.sh`).
