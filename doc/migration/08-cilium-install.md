# 08. Cilium 1.19 trên multi-VM Tailscale

> Tiền điều kiện: kubeadm cluster đã up (4 node `NotReady`).

## 1. Helm repo

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update cilium
```

## 2. Values file `cilium-values-multi-vm.yaml`

Khác biệt so với `k8s-management/cilium/cilium-values.yaml` cũ:
- `k8sServiceHost`/`k8sServicePort` cố định Tailscale IP của cp1.
- `tunnelProtocol=vxlan` (mặc định, ghi rõ).
- `encryption.enabled=false` (tắt WireGuard, vì Tailscale lo).
- `kubeProxyReplacement=true` (kubeadm đã skip kube-proxy).
- `ipam.mode=kubernetes` (đơn giản, kubeadm cấp PodCIDR).
- `autoDirectNodeRoutes=false` (cần tunnel, không direct).

```yaml
# /tmp/cilium-values-multi-vm.yaml
cluster:
  name: job7189
  id: 1

# Apiserver Tailscale endpoint — KHÔNG dùng kubernetes.default ClusterIP
# (vì cilium-agent boot trước khi service kubernetes có endpoint)
k8sServiceHost: "100.64.10.1"
k8sServicePort: 6443

ipam:
  mode: kubernetes

routingMode: tunnel
tunnelProtocol: vxlan
tunnelPort: 8472

kubeProxyReplacement: "true"
bpf:
  masquerade: true
  hostLegacyRouting: false

# Tắt WireGuard — Tailscale làm rồi
encryption:
  enabled: false
  type: ""

# mTLS (mesh-auth) bật SAU bằng script 08-harden-security.sh
authentication:
  enabled: false
  mutual:
    spire:
      enabled: false

ipv4NativeRoutingCIDR: ""    # vì routingMode=tunnel
autoDirectNodeRoutes: false

# Hubble (observability)
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
  metrics:
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - icmp
      - http

# Operator: chạy trên control-plane
operator:
  replicas: 1
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  nodeSelector:
    kubernetes.io/hostname: cp1

# Resource limits cho cilium-agent (DaemonSet)
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1
    memory: 256Mi

# Healthz endpoint port
agentHealthPort: 9879

# eBPF map size — tránh DBPF conflict với Tetragon
bpf:
  preallocateMaps: true
  policyMapMax: 16384
  ctMapMax: 524288
  natMapMax: 524288
  neighMapMax: 524288
```

## 3. Install

```bash
helm upgrade --install cilium cilium/cilium \
  --version 1.19.1 \
  --namespace kube-system \
  -f /tmp/cilium-values-multi-vm.yaml \
  --wait --timeout 10m
```

> Lưu ý: lần đầu install, `helm --wait` có thể chờ lâu vì DaemonSet chưa
> ready trên 4 node. Tăng `--timeout` lên 10m an toàn.

## 4. Verify

```bash
# Cilium trạng thái
kubectl -n kube-system get pod -l k8s-app=cilium -o wide
# Kỳ vọng: 4 pod cilium-agent (1/node), 1 pod cilium-operator

# CLI cilium status (cài cilium CLI từ https://github.com/cilium/cilium-cli)
cilium status --wait

# Pod-to-pod connectivity (Cilium tự ship test):
cilium connectivity test --test-namespace cilium-test --hubble=false
```

`cilium connectivity test` chạy ~5-10 phút. Kỳ vọng: pass tất cả test trừ
external-DNS-only (vì cluster đang firewall outbound qua VMware NAT).

## 5. Node Ready

```bash
kubectl get nodes
```
Kỳ vọng:
```
NAME    STATUS  ROLES           AGE  VERSION
cp1     Ready   control-plane   15m  v1.30.0
w-data  Ready   <none>          12m  v1.30.0
w-apps  Ready   <none>          12m  v1.30.0
w-obs   Ready   <none>          12m  v1.30.0
```

## 6. Hubble UI

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
# trên admin laptop: http://localhost:12000
```

## 7. Sự khác biệt so với Kind config cũ

So với `k8s-management/cilium/cilium-values.yaml`:

| Field | Kind cũ | Multi-VM mới | Lý do |
|-------|---------|---------------|-------|
| `k8sServiceHost` | (auto, từ kubernetes svc) | `100.64.10.1` | Apiserver Tailscale, tránh chicken-and-egg |
| `kubeProxyReplacement` | `partial` | `"true"` | kubeadm skip kube-proxy |
| `routingMode` | (default = tunnel) | `tunnel` (explicit) | Tailscale L3, cần encap |
| `encryption.enabled` | `true` (sau script 08) | `false` | Tailscale đã encrypt |
| `tunnelProtocol` | `vxlan` (default) | `vxlan` (explicit) | Idem |
| `bpf.masquerade` | true | true | Idem |
| `autoDirectNodeRoutes` | true (Kind tự routing) | `false` | Vì tunnel mode |
| `cluster.id` | 1 | 1 | Idem |
| `hubble.metrics` | có | có | Idem |
| `ipam.mode` | `kubernetes` | `kubernetes` | Idem |

## 8. mTLS (mesh-auth) bật sau

Khi cluster ổn định và tất cả workload Ready, chạy `08-harden-security.sh`
PHIÊN BẢN ĐÃ ADAPT (xem `10-zta-pipeline-adaptations.md`):

```bash
# QUAN TRỌNG: chỉ bật mesh-auth, KHÔNG bật wireguard
ZTA_HARDEN_WIREGUARD=0 bash 08-harden-security.sh
```

Lý do bật mesh-auth (mTLS): SPIRE workload identity (`doc/27-spire-workload-attestation.md`)
và mesh-auth giả thiết Cilium issue cert qua SPIRE → Tetragon enforce →
PEP runtime. Tailscale chỉ encrypt tunnel L3, không thay thế mTLS L7.

## 9. Troubleshooting

### Cilium-agent CrashLoop trên 1 node
```bash
kubectl -n kube-system logs ds/cilium -c cilium-agent --previous \
  | grep -E 'level=(error|fatal)' | tail
```
Lỗi thường gặp:
- `Failed to dial https://100.64.10.1:6443`: Tailscale chưa up trên node đó hoặc apiserver firewall chặn → `tailscale ping 100.64.10.1`.
- `Failed to mount BPF filesystem`: kernel cũ → upgrade Debian kernel `apt install linux-image-cloud-amd64`.

### Pod ở các node khác nhau không reach nhau
```bash
# trên VM nguồn
sudo cilium-dbg debuginfo --output markdown > /tmp/dbg.md

# Test VXLAN có chạy không
sudo tcpdump -i any -nn 'udp port 8472' -c 5
```

Nếu không thấy gói VXLAN cross-node → VMware NAT chặn UDP 8472? **NHẦM** —
gói VXLAN của Cilium đi qua interface `tailscale0`, không qua VMnet8.
Verify:
```bash
ip route get 100.64.10.4    # phải đi qua tailscale0
```

Nếu route đi qua ens33 (VMnet) → Tailscale chưa add route → `sudo tailscale set --accept-routes=true`.

### 4 nodes thấy nhau, pod của chúng không
```bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium status
# kiểm tra Datapath, Cluster health, Encryption
```

## 10. Resources estimate

Cilium agent chạy trên 4 node → 4 × 256 Mi limit = **1 GiB tổng**.
Cilium-operator chạy 1 replica → 256 Mi.
Hubble Relay + UI: ~200 Mi tổng.

→ **~1.5 GiB cluster-wide chỉ cho Cilium**. Đã được tính trong
`02-target-architecture.md`.
