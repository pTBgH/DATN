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

## 12. Containerd state corrupt sau unclean shutdown

**Triệu chứng (chuỗi 3 bước, đừng dừng ở bước 1):**

1. `kubelet.service` crash-loop với:
   ```
   dial unix /run/containerd/containerd.sock: connect: no such file or directory
   ```
2. Sau khi `systemctl restart containerd` lại được, pod mới fail với:
   ```
   failed to prepare extraction snapshot ... rename ... : file exists
   ```
3. Sau khi xóa CHỈ `io.containerd.snapshotter.v1.overlayfs/`, lỗi mới xuất hiện:
   ```
   failed to create snapshot: missing parent "k8s.io/3/sha256:..." bucket: not found
   ```

Bước 3 là lỗi báo hiệu **global metadata DB** (`io.containerd.metadata.v1.bolt/meta.db`) lệch
với snapshotter mới. Xóa nửa vời sẽ kéo dài tình trạng — phải nuke `/var/lib/containerd`
hoàn toàn.

**Cảnh báo an toàn:**

- Quy trình này XÓA toàn bộ image local + container state trên node đó.
- An toàn khi node chưa host stateful workload (vault, MySQL, Kafka, registry, SPIRE).
- KHÔNG làm với `7189srv04` nếu `vault-dev` đang chạy — Transit key trong RAM của
  vault-dev sẽ mất → `vault-prod` mất auto-unseal. Khi đó dùng VMware/libvirt snapshot
  restore thay vì nuke containerd.

**Recovery procedure (chỉ làm khi node KHÔNG có stateful workload):**

```bash
# 1. Stop kubelet TRƯỚC containerd
sudo systemctl stop kubelet
sudo systemctl stop containerd

# 2. Xác nhận không còn container/pod đang chạy
sudo crictl ps 2>/dev/null
sudo ctr -n k8s.io c ls 2>/dev/null | head

# 3. Backup toàn bộ /var/lib/containerd
sudo mv /var/lib/containerd /var/lib/containerd.broken.$(date +%s)
sudo mkdir -p /var/lib/containerd
sudo chmod 711 /var/lib/containerd

# 4. Dọn CNI tàn dư (IPAM cũ + lxc interface có thể chặn pod sandbox sau khi nuke)
sudo rm -rf /var/lib/cni /var/run/cni 2>/dev/null || true
sudo ip link show | awk -F': ' '/cilium_|lxc/{print $2}' | xargs -r -n1 sudo ip link delete 2>/dev/null || true

# 5. Start lại
sudo systemctl start containerd
sleep 5
sudo systemctl start kubelet

# 6. Verify runtime healthy
sudo systemctl is-active containerd kubelet
```

Sau đó từ control plane:

```bash
# Force recreate cilium DS pod trên node bị ảnh hưởng
kubectl -n kube-system delete pod -l k8s-app=cilium \
  --field-selector spec.nodeName=<affected-node>

# Watch ~2-3 phút cho image pull lại từ quay.io
kubectl -n kube-system get pod -l k8s-app=cilium -o wide -w
```

Sau 1 tuần không vấn đề, xóa backup giải phóng disk:
```bash
sudo rm -rf /var/lib/containerd.broken.*
```

Tham khảo chi tiết: `doc/migration/incident-srv04-containerd-snapshotter-2026-05-12.md`.

## 13. Tailscale DERP relay saturation (double-NAT VM)

**Triệu chứng (3 dấu hiệu phải XẢY RA ĐỒNG THỜI):**

1. Node `NotReady`, `kubectl describe node` cho thấy
   `LastHeartbeatTime` đã cũ hàng phút/giờ. Conditions: `Unknown`.
2. Trên node đó: `containerd` + `kubelet` đều `active`, socket
   `/run/containerd/containerd.sock` tồn tại. Tức KHÔNG phải lỗi
   containerd/snapshotter.
3. `sudo tailscale ping <CP>` thành công (qua DERP) nhưng:
   ```
   curl -k --max-time 10 https://<CP-tailscale-ip>:6443/livez
   # → Connection timed out (TLS Client Hello sent, no response)
   ```
   Và trong `journalctl -u tailscaled`:
   ```
   open-conn-track: timeout opening (TCP <self>:<port> => <CP>:6443)
     to node [...]; online=yes, lastRecv=Ns
   ```

**Xác nhận root cause:**

```bash
sudo tailscale netcheck | head -20
```

Tìm:
- `MappingVariesByDestIP: true` ← symmetric NAT, UDP holepunch fail
- `Nearest DERP: <city>` ← relay node bạn đang qua (vd. Hong Kong)

Kết hợp với traffic counter bất thường trong `tailscale status`:
```
<peer>  active; relay "hkg", tx N rx M    ← N/M ratio > 5 = retry storm
```

⇒ Mọi traffic K8s bị buộc qua DERP relay; relay đang quá tải → drop
gói TCP lớn (ví dụ TLS Client Hello 1.5 KiB).

**Mitigation (theo thứ tự ưu tiên):**

1. **Tạm thời (giảm latency 1-2 phút):**
   ```bash
   sudo tailscale down && sleep 2 && sudo tailscale up
   sudo systemctl restart kubelet
   ```
   Sẽ reset connection state. Hữu hiệu trong vòng vài phút trước khi
   relay saturate lại.

2. **Bán-vĩnh-viễn (port-forward UDP 41641):**
   Trên hypervisor host (KVM/libvirt) HOẶC router:
   ```bash
   sudo iptables -t nat -A PREROUTING -p udp --dport 41641 \
     -j DNAT --to-destination <VM-LAN-IP>:41641
   sudo iptables -A FORWARD -p udp -d <VM-LAN-IP> --dport 41641 -j ACCEPT
   sudo netfilter-persistent save
   ```
   Cộng port-forward UDP 41641 trên router/modem nhà → IP host. Mục
   tiêu: bypass DERP, enable direct P2P.

3. **Vĩnh viễn (thay VM):**
   Nếu VM dính double-NAT (libvirt NAT bên trong ISP CGNAT) → khả năng
   `MappingVariesByDestIP=true` cao. Provision VM mới với bridge
   network thay vì NAT. Xem `transition-srv04-to-srv05.md` cho quy
   trình thay node data-tier.

**Phòng ngừa:**

- Trước khi thêm node mới vào cluster, chạy `sudo tailscale netcheck`
  và xác nhận `MappingVariesByDestIP: false` HOẶC port-forward UDP
  41641 đã active.
- Stateful workload (vault, registry, mysql, kafka) **KHÔNG** được
  pin vào node có dấu hiệu phụ thuộc DERP — DERP throughput không đủ
  cho workload thật, sẽ sập dưới tải.

Tham khảo chi tiết: `doc/migration/incident-srv04-tailscale-derp-2026-05-13.md`.

## 14. Bảng phản ứng nhanh

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
| `containerd.sock: no such file` + snapshot `rename: file exists` | §12 | Nuke `/var/lib/containerd` (chỉ khi không có stateful) |
| Node NotReady + containerd/kubelet OK nhưng TCP timeout, `MappingVariesByDestIP=true` | §13 | tailscale down/up tạm thời; thay VM (bridge) lâu dài |
