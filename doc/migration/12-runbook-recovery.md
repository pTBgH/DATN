# 12. Runbook — Recovery / Disaster Scenarios

## 1. 7189srv01 chết (apiserver unreachable)

**Triệu chứng**: `kubectl get nodes` báo
`The connection to the server 100.64.10.1:6443 was refused`.

**Step 1: Xác định lỗi**
```bash
ssh debian@7189srv01.<tailnet>.ts.net  # Tailscale có on?
ssh debian@7189srv01.<tailnet>.ts.net 'tailscale status; sudo systemctl status kubelet containerd'
```

| Lỗi | Hành động |
|-----|-----------|
| VM tắt | Power on VM trong VMware |
| VM boot nhưng kubelet down | `sudo systemctl restart kubelet` |
| etcd corrupt (nhật ký lỗi `walpb: crc mismatch`) | Restore từ snapshot (xem dưới) |
| Disk đầy `/var/lib/etcd` | `sudo etcdctl snapshot save` rồi `defrag` |

**Step 2: Restore etcd snapshot**

(Backup từ `07-kubeadm-bootstrap.md` §10 — phải có sẵn `kubeadm-pki-backup-*.tar.gz`)

```bash
# Trên 7189srv01, dừng kubelet/static pods
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d /var/lib/cni
sudo systemctl restart containerd

# Restore PKI
sudo tar xzf /root/kubeadm-pki-backup-*.tar.gz -C /

# Re-init từ snapshot (nếu có etcd snapshot)
# (Chưa setup snapshot tự động — chỉ có VMware snapshot toàn VM. Restore VM
#  từ snapshot là cách dễ nhất.)
```

→ **Khuyến nghị**: tạo VMware snapshot `7189srv01-baseline` ngay sau khi
cluster ổn định. Restore = "Snapshot Manager → revert to
7189srv01-baseline" → up trong 2 phút.

**Step 3: Worker trở lại**

Worker không cần can thiệp — kubelet sẽ retry connection với apiserver,
thành công ngay khi `7189srv01` up. Nếu node đứng `NotReady` sau 5
phút:
```bash
ssh debian@<worker>.<tailnet>.ts.net 'sudo systemctl restart kubelet'
```

## 2. Tailscale rớt giữa 2 host

**Triệu chứng**: pod cross-host không reach nhau, Hubble drop count tăng.
`tailscale status` báo "Health: not connected".

**Step 1**: Verify trên VM bị mất
```bash
sudo tailscale status
sudo journalctl -u tailscaled -n 50
```

**Step 2**: Reset
```bash
sudo tailscale down
sudo tailscale up --auth-key=tskey-... --advertise-tags=tag:zta-cluster --hostname=$(hostname) --accept-dns=true
```

**Step 3**: Verify peer-to-peer khôi phục
```bash
tailscale ping <other-vm>
# Direct: peer.tailnet IP=100.x.y.z (peer-to-peer)
# DERP: relayed via DERP server (slower, but works)
```

**Step 4**: Cilium agent không cần reset — VXLAN sẽ tự reconnect khi route
có lại.

## 3. RAM cạn trên 1 VM (eviction storm)

**Triệu chứng**: `kubectl get pod` thấy nhiều pod `Evicted` trên 1 node.

**Step 1**: Xác định node + nguyên nhân
```bash
kubectl describe node <bad-node> | grep -A5 "Conditions"
# MemoryPressure: True → node thật sự thiếu RAM
ssh debian@<bad-node>.<tailnet>.ts.net 'free -h; ps aux --sort=-%mem | head -10'
```

**Step 2**: Giảm tải tạm
```bash
# Nếu 7189srv04: giảm Elasticsearch heap
kubectl -n monitoring set env statefulset/elasticsearch-master ES_JAVA_OPTS="-Xmx256m -Xms256m"
kubectl -n monitoring rollout restart sts/elasticsearch-master

# Nếu Tetragon: giảm policy
kubectl -n kube-system delete tracingpolicy <heaviest-policy>

# Khẩn cấp: drain node
kubectl drain <bad-node> --ignore-daemonsets --delete-emptydir-data
```

**Step 3**: Tăng RAM VM (cần shutdown VM trong VMware)
```bash
# Shutdown VM
ssh debian@<bad-node>.<tailnet>.ts.net 'sudo shutdown -h now'
# Trong VMware: VM Settings → Memory → tăng
# Power on
```

Sau khi reboot:
```bash
kubectl uncordon <bad-node>
```

## 4. Worker chết hẳn

**Triệu chứng**: Node `NotReady` quá 5 phút, VM không SSH được, VMware
báo "powered off" hoặc "stuck on resume".

**Step 1**: Cố power on lại
```bash
# VMware GUI: VM → Power → Power On
# Hoặc CLI:
vmrun -T ws start /path/to/vm.vmx nogui
```

**Step 2**: Pod sẽ tự reschedule sang node khác sau 5 phút (default
`pod-eviction-timeout`). Verify:
```bash
kubectl get pod -A -o wide | grep <bad-node>
# Pod đã chuyển sang node khác (vì soft-affinity, không hard)
```

**Step 3**: Nếu PVC neo trên node chết → pod sẽ stuck `Pending`. Phải:
- Phục hồi VM
- Hoặc xóa PVC + tạo lại (mất data)
- Hoặc rsync data từ snapshot VMware

```bash
# Force xóa PVC (mất data!)
kubectl delete pvc -n data mysql-data-mysql-0 --force --grace-period=0
kubectl delete pod -n data mysql-0 --force --grace-period=0
# Pod sẽ recreate, PVC sẽ recreate trên node khác (nếu pod được schedule
# tới node mới)
```

## 5. kubeadm token hết hạn (>24h sau init)

**Triệu chứng**: Worker mới không join được, lỗi `token has expired`.

**Step 1**: Tạo token mới trên 7189srv01
```bash
ssh debian@7189srv01.<tailnet>.ts.net
sudo kubeadm token create --print-join-command
# Output:
# kubeadm join 100.64.10.1:6443 --token abc.xyz \
#   --discovery-token-ca-cert-hash sha256:abc...
```

**Step 2**: Trên worker mới, dùng lệnh trên thay cho `kubeadm join`.

## 6. Cilium connectivity test fail

**Triệu chứng**: `cilium connectivity test` báo fail, pod không reach
service ClusterIP.

**Step 1**: Verify VXLAN tunnel
```bash
sudo tcpdump -i tailscale0 -nn 'udp port 8472' -c 5
# Nếu KHÔNG thấy gói → cilium agent chưa encap
```

**Step 2**: Restart cilium agents
```bash
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
```

**Step 3**: Verify mỗi agent kết nối với apiserver
```bash
kubectl -n kube-system exec ds/cilium -- cilium status | grep -i k8s
```

## 7. PVC stuck trong `Pending`

**Triệu chứng**: `kubectl describe pvc <name>` báo `WaitForFirstConsumer`
quá lâu hoặc `failed to provision volume`.

**Step 1**: Verify pod đang consume PVC tồn tại
```bash
kubectl describe pvc <name>  # xem `Used By:` field
```

**Step 2**: Verify local-path-provisioner running
```bash
kubectl -n local-path-storage get pod
kubectl -n local-path-storage logs -l app=local-path-provisioner --tail=50
```

**Step 3**: Verify path tồn tại + writable trên node
```bash
ssh debian@<target-node>.<tailnet>.ts.net 'ls -la /var/lib/job7189-mysql && touch /var/lib/job7189-mysql/test && rm /var/lib/job7189-mysql/test'
```

## 8. Vault sealed (sau VM reboot)

**Triệu chứng**: Vault pod Running nhưng API trả `"sealed":true`.

```bash
kubectl -n vault exec -it vault-0 -- vault status
# Sealed: true

# Unseal qua transit (Vault dev) — nếu auto-unseal config đúng (chap 16):
kubectl -n vault rollout restart sts/vault-prod
# Auto-unseal sẽ chạy lại

# Hoặc manual unseal với 3/5 keys:
for k in $UNSEAL_KEY_1 $UNSEAL_KEY_2 $UNSEAL_KEY_3; do
  kubectl -n vault exec -it vault-0 -- vault operator unseal $k
done
```

## 9. Toàn bộ cluster reset (worst case)

```bash
# Trên CP1 + 3 worker
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d /var/lib/cni /var/lib/job7189-* /var/lib/local-path-provisioner
sudo systemctl restart containerd

# Bắt đầu lại từ Phase 1 trong 11-runbook-fresh-deploy.md
```

KHÔNG cần re-cài Debian/Tailscale/containerd — những thứ đó persistent.

## 10. VMware host crash (Windows BSOD)

**Triệu chứng**: 3 VM trên Windows host (`7189srv01`, `7189srv02`,
`7189srv03`) đột ngột tắt. **`7189srv04` trên Ubuntu host vẫn chạy —
stateful workload (vault-dev, vault-prod, MySQL, etc.) tiếp tục khả dụng
với những pod đã chạy, nhưng cluster api không reachable.**

**Step 1**: Reboot Windows host. VMware Workstation **không** auto-start
VM mặc định — phải bật riêng:
- VMware Workstation → File → Open `*.vmx` → Power → Start when host
  starts (đánh dấu)

Hoặc CLI ở Windows:
```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws start "C:\path\to\7189srv01.vmx" nogui
```

**Step 2**: Sau khi 3 VM up, cluster sẽ tự heal — apiserver online, kubelet
trên các node tự reconnect, pod được restart từ etcd state.

## 11. Tailnet bị unauthorize (auth key revoked)

**Triệu chứng**: VM báo `Tailscale: 401 Unauthorized`.

**Step 1**: Tạo auth key mới trong admin console.

**Step 2**: Trên VM:
```bash
sudo tailscale logout
sudo tailscale up --auth-key=tskey-NEW... --advertise-tags=tag:zta-cluster --hostname=$(hostname) --accept-dns=true
```

> Nếu IP Tailscale **đổi** sau re-auth → kubeadm certSANs không khớp →
> apiserver TLS verify fail. Để tránh: trong Tailscale admin, đặt IP
> reservation cho từng hostname.

## 12. Bảng phản ứng nhanh

| Triệu chứng | Trang | Xử lý |
|-------------|-------|-------|
| `kubectl` connection refused | §1 | Restart 7189srv01 |
| Cross-VM pod 100% drop | §2 | Reset Tailscale |
| Pod Evicted hàng loạt | §3 | Giảm tải / tăng RAM |
| Node NotReady > 5 min | §4 | Power on VM |
| `token has expired` | §5 | Tạo token mới |
| `cilium connectivity test` fail | §6 | Restart cilium DS |
| PVC Pending | §7 | Verify provisioner + path |
| Vault sealed | §8 | Auto-unseal hoặc manual |
| All-cluster reset | §9 | kubeadm reset + redeploy |
| Windows host crash | §10 | Power on VM thủ công |
| Tailnet 401 | §11 | Tạo + login auth key mới |
