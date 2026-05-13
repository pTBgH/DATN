# 04. Networking — Tailscale + VMware NAT + Cilium VXLAN

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


## 1. Vấn đề

VMware Workstation NAT cô lập VM trong subnet riêng của từng host:
- Host Win: VMnet8 → ví dụ `192.168.139.0/24`
- Host Ubuntu: VMnet8 → ví dụ `192.168.227.0/24`

VM Win KHÔNG ping được VM Ubuntu vì VMware NAT chặn cross-host. Bridge mode
"sửa" nhưng user báo "hơi lỗi" — có thể do WiFi access point lọc gói L2 lạ
(common với router gia đình).

→ **Tailscale làm overlay L3** giải quyết: mỗi VM tự khoan NAT-hole (DERP
fallback nếu tắc), thấy nhau qua IP `100.64.0.0/10` bất kể host vật lý.

## 2. Sơ đồ luồng gói

```
         ┌─── pod-A trên 7189srv01 ──┐         ┌─── pod-B trên 7189srv05 ──┐
         │  10.244.1.5               │         │ 10.244.4.7                │
         └─────┬─────────────────────┘         └─────┬─────────────────────┘
               │                                     │
               ▼                                     ▼
        cilium-agent 7189srv01                cilium-agent 7189srv05
               │ encap VXLAN                         │
               │ outer src=100.64.10.1               │
               │ outer dst=100.64.10.4 (UDP/8472)    │
               ▼                                     ▼
        tailscaled 7189srv01                  tailscaled 7189srv05
               │ WG src=100.64.10.1                  │
               │ WG dst=100.64.10.4 (UDP/41641)      │
               ▼                                     ▼
          ens33 NAT                              ens33 NAT
        192.168.139.10                         192.168.227.10
                      │                                      │
                      └────────► Internet ◄──────────────────┘
                          (DERP relay nếu peer-to-peer fail)
```

> Hai lớp UDP encap (Cilium VXLAN ngoài, Tailscale WG trong). Performance:
> ~5-15% overhead trên LAN, ~25-40% trên WAN. Cho lab PoC OK.

## 3. Tailscale ACL & MagicDNS

Bật MagicDNS trong admin console (`https://login.tailscale.com/admin/dns`)
để 4 VM thấy nhau bằng tên ngắn:

```
7189srv01.<tailnet>.ts.net  → 100.64.10.1
7189srv02.<tailnet>.ts.net  → 100.64.10.2
7189srv03.<tailnet>.ts.net  → 100.64.10.3
7189srv05.<tailnet>.ts.net  → 100.64.10.4
```

ACL khuyến nghị (`https://login.tailscale.com/admin/acls`):

```jsonc
{
  "tagOwners": {
    "tag:zta-cluster": ["autogroup:admin"]
  },
  "acls": [
    // Cluster nodes nói chuyện thoải mái với nhau
    { "action": "accept",
      "src": ["tag:zta-cluster"],
      "dst": ["tag:zta-cluster:*"] },

    // Admin (laptop của bạn) SSH + kubectl 6443 vào tất cả VM
    { "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:zta-cluster:22,6443,30000-30099,8443"] }
  ],
  "ssh": [
    { "action": "check",
      "src": ["autogroup:admin"],
      "dst": ["tag:zta-cluster"],
      "users": ["root", "debian", "ubuntu"] }
  ]
}
```

Auth keys (mỗi VM chỉ cần 1 lần):
1. Vào `https://login.tailscale.com/admin/settings/keys`
2. Tạo **reusable, ephemeral=false, tagged tag:zta-cluster**, expiry 90 ngày
3. Lưu thành 1 secret duy nhất, dùng chung cho 4 VM:
   ```
   sudo tailscale up --auth-key=tskey-auth-XXXX --advertise-tags=tag:zta-cluster --hostname=7189srv01
   ```

## 4. Cilium nodeIP override

Mặc định kubeadm + kubelet pick IP đầu tiên trên `default route` interface
→ tức là `192.168.139.10` (VMnet NAT). Đó là **sai** cho cluster cross-host.

Phải force Cilium + kubelet dùng IP Tailscale:

### Trên mỗi VM, file `/var/lib/kubelet/kubeadm-flags.env`

```
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.9 --node-ip=100.64.10.X"
```
(thay X cho từng VM)

### Trên 7189srv01, `kubeadm-config.yaml` cho `kubeadm init`:

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "100.64.10.1"
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    node-ip: "100.64.10.1"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "v1.30.0"
controlPlaneEndpoint: "100.64.10.1:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  dnsDomain: "cluster.local"
apiServer:
  certSANs:
    - "100.64.10.1"
    - "7189srv01"
    - "7189srv01.<tailnet>.ts.net"
    - "127.0.0.1"
    - "localhost"
  extraArgs:
    profiling: "false"
controllerManager:
  extraArgs:
    leader-elect-lease-duration: "30s"
    leader-elect-renew-deadline: "20s"
    leader-elect-retry-period: "4s"
scheduler:
  extraArgs:
    leader-elect-lease-duration: "30s"
    leader-elect-renew-deadline: "20s"
    leader-elect-retry-period: "4s"
```

`controlPlaneEndpoint=100.64.10.1:6443` cốt yếu — worker join sẽ dùng IP
Tailscale, và certSANs bao gồm Tailscale IP để TLS verify pass.

### Cilium Helm values (override `k8s-management/cilium/cilium-values.yaml`)

```yaml
# Đoạn cần thêm/sửa cho multi-VM kubeadm:
k8sServiceHost: "100.64.10.1"   # apiserver Tailscale IP
k8sServicePort: 6443
kubeProxyReplacement: "true"     # bỏ kube-proxy, Cilium làm hết
ipv4NativeRoutingCIDR: "10.244.0.0/16"

routingMode: "tunnel"            # VXLAN trên Tailscale
tunnelProtocol: "vxlan"
tunnelPort: 8472

encryption:
  enabled: false                 # TẮT WireGuard — Tailscale đã encrypt
  type: ""

ipam:
  mode: "kubernetes"             # PodCIDR từ K8s, đơn giản

operator:
  replicas: 1                    # 1 cp → 1 operator

hubble:
  enabled: true
  relay: { enabled: true }
  ui:    { enabled: true }
  metrics:
    enabled: ["dns", "drop", "tcp", "flow", "icmp", "http"]

# Cố định nodeIP từ kubelet flag, không dùng --auto-direct-node-routes
autoDirectNodeRoutes: false

cluster:
  name: "job7189"
  id: 1

# Bật mTLS sau khi cluster ổn định (script 08-harden-security.sh)
authentication:
  enabled: false                 # bật bằng `kubectl patch` sau
  mutual:
    spire: { enabled: false }
```

**Lý do tunnel=vxlan thay vì native routing**: native routing cần subnet
routes giữa các pod-CIDR của các node. Trên Tailscale L3 mesh, để dùng
native routing ta phải `tailscale set --advertise-routes=10.244.X.0/24`
trên từng node + bật `--accept-routes` trên cả tailnet — phức tạp và dễ
broken khi reboot. VXLAN tunnel tự encap nên không cần.

## 5. NodePort + Ingress + external access

Kind cũ map host port qua `kind-config.yaml`:
```
30000 → 80 (Kong proxy NodePort)
30001 → 443 (ingress-nginx)
30002 → 8200 (Vault — debug only)
30003 → 8080 (oauth2-proxy)
30004 → 31000 (...)
```

Multi-VM: NodePort tự nhiên reachable trên IP Tailscale của bất kỳ worker
nào. Để demo từ máy admin (laptop) qua Tailscale:

```
http://7189srv02.<tailnet>.ts.net:30000  # Kong
https://7189srv02.<tailnet>.ts.net:30001 # Ingress
http://7189srv05.<tailnet>.ts.net:30002  # Vault UI (debug, srv05 always-on)
```

Tùy chọn ingress chính:
- Ingress-nginx Service NodePort 30001 → tự động trên 4 worker
- Hoặc bật **Tailscale Funnel** trên 1 worker để có URL
  `https://7189srv02.<tailnet>.ts.net` mà không cần port 30001 — đẹp hơn cho
  demo public.

## 6. Hubble Relay/UI khi cross-VM

Hubble Relay aggregator chạy 1 replica (Deployment), Cilium agent trên 4
node forward flow events qua gRPC sang Relay. Relay → UI (Service in-cluster).

Để truy cập Hubble UI từ admin laptop:
```
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
# rồi mở http://localhost:12000
```

Hoặc expose qua ingress với JWT auth (Kong route).

## 7. DNS resolution trong VM

`/etc/resolv.conf` của Debian VM mặc định trỏ tới VMware NAT gateway
(192.168.139.2 hoặc tương đương). Tailscale MagicDNS thêm `100.100.100.100`
làm primary nameserver tự động sau `tailscale up` (nếu bật trong admin
console). Cảnh báo: với `--accept-dns=false` thì **không** override resolv.

Kiểm tra:
```bash
sudo tailscale status
resolvectl status
nslookup 7189srv01   # phải trả 100.64.10.1
```

Coredns trong cluster cũng resolve được tên Tailscale nhờ upstream
forward `/etc/resolv.conf` → `100.100.100.100`. Tuy nhiên để app trong
pod resolve `7189srv01` không đáng tin → giữ nguyên Service ClusterIP DNS
`mysql.data.svc.cluster.local` thay vì `7189srv05:3306`.

## 8. Firewall trên Debian VM

iptables/nftables cần mở:

| Port | Proto | Direction | Mục đích |
|------|-------|-----------|----------|
| 6443 | TCP | inbound (7189srv01 only) | apiserver |
| 10250 | TCP | inbound | kubelet |
| 10256 | TCP | inbound | kube-proxy / cilium |
| 8472 | UDP | inbound | Cilium VXLAN |
| 4240 | TCP | inbound | Cilium health |
| 41641 | UDP | inbound | Tailscale (DERP fallback) |
| 22 | TCP | inbound (Tailscale only) | SSH |

Đề xuất: dùng `ufw` hoặc `iptables` allowlist trên interface `tailscale0`
(KHÔNG mở port qua VMware NAT external):

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0
sudo ufw allow in on cilium_host    # liên quan đến cilium veth
sudo ufw enable
```

## 9. Test connectivity sau setup

```bash
# Trên mọi VM
ping -c 3 7189srv01                    # MagicDNS phải resolve
ping -c 3 100.64.10.1                  # IP trực tiếp
nc -vz 100.64.10.1 6443                # apiserver port (sau kubeadm init)

# Trên 7189srv01
curl -k https://100.64.10.1:6443/version
kubectl get nodes -o wide              # cột INTERNAL-IP phải là 100.64.10.X
```

Nếu node hiển thị IP VMnet NAT (192.168.x), kubelet đang chưa pick
`--node-ip` đúng → kiểm tra `/var/lib/kubelet/kubeadm-flags.env`.
