# 06. Debian Base Prep — chuẩn bị mỗi VM

> **State as of 2026-05-13** — file này document procedure cho **Debian 13**
> trên `7189srv01..03` (VMware host). Cho data-tier node `7189srv05`
> (Ubuntu 24.04, libvirt bridge) dùng [transition-srv04-to-srv05.md](transition-srv04-to-srv05.md)
> hoặc chạy `bash doc/migration/scripts/onboard-srv05.sh` (host-prep.sh
> đã auto-detect distro qua `${ID}` từ `/etc/os-release` và chọn Docker
> apt repo đúng — debian vs ubuntu). srv04 (cũ, NAT) đã decommission;
> xem [incident-srv04-tailscale-derp-2026-05-13.md](incident-srv04-tailscale-derp-2026-05-13.md).

> Mục tiêu: từ Debian 13 "Trixie" minimal vừa cài xong → trạng thái sẵn
> sàng `kubeadm init` hoặc `kubeadm join`.

Chạy script bên dưới trên **3 VM Debian** (`7189srv01`, `7189srv02`,
`7189srv03`). Không idempotent 100% nhưng re-run an toàn (skip step đã làm).
Cho `7189srv05` (Ubuntu 24.04), dùng `onboard-srv05.sh` thay vì các bước
ở đây.

## Distro cụ thể

Debian 13 "Trixie" (released 2025-08, kernel ≥ 6.12). Kernel mới hỗ trợ
CO-RE eBPF đủ cho Tetragon. Tải ISO từ https://www.debian.org/distrib/.
Nếu cluster cuối bạn còn dùng ISO Debian 12 "Bookworm", các bước dưới đây
vẫn chạy — chỉ cần thay `$(lsb_release -cs)` về `bookworm`.

## 1. Tạo user `debian` và sudo passwordless (nếu chưa)

```bash
sudo apt update
sudo apt install -y sudo
sudo adduser debian --disabled-password --gecos ""
echo 'debian ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-debian
```

Mỗi VM dùng SSH key duy nhất từ admin laptop:
```bash
# trên admin laptop
ssh-copy-id debian@<vm-vmware-nat-ip>
# Sau khi tailscale up:
ssh debian@7189srv01.<tailnet>.ts.net
```

## 2. Cập nhật + cài tool chung

```bash
sudo apt update && sudo apt -y full-upgrade
sudo apt install -y \
  curl wget gnupg ca-certificates apt-transport-https \
  iproute2 iptables ipset conntrack ethtool socat \
  jq vim less tmux htop git unzip
```

## 3. Cài Tailscale + auth

```bash
curl -fsSL https://tailscale.com/install.sh | sh

# auth bằng pre-shared key (xem doc/migration/04-network-tailscale-cilium.md §3)
sudo tailscale up \
  --auth-key=tskey-auth-XXXXXXXXXXXXXXXX \
  --advertise-tags=tag:zta-cluster \
  --hostname=$(hostname) \
  --ssh \
  --accept-dns=true

# Verify
tailscale ip -4         # phải in 100.64.10.X
tailscale status
ping -c 3 7189srv01     # MagicDNS phải resolve (ngoại trừ chính node đó)
```

> Nếu user không muốn để key trong shell history, đặt vào `/root/.ts-key`
> mode 600 và `--auth-key=$(cat /root/.ts-key)`.

## 4. Tắt swap kiểu kubelet không dung được

```bash
# K8s 1.30 mặc định CHẤP NHẬN swap, nhưng để thesis stable, vẫn tắt:
sudo swapoff -a
sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab
free -h | grep -i swap   # phải hiển thị 0
```

Hoặc nếu muốn giữ swap (recommended cho VM nhỏ — `7189srv01` 2 GB hơi sát):
```bash
# /etc/sysctl.d/99-zta.conf
vm.swappiness = 10
vm.overcommit_memory = 1
vm.panic_on_oom = 0
kernel.panic = 10
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
sudo sysctl --system
```

Trong kubelet config sau này thêm:
```yaml
failSwapOn: false
memorySwap:
  swapBehavior: LimitedSwap
```

## 5. Kernel modules + sysctl cho K8s

```bash
sudo tee /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/99-k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl --system
```

## 6. containerd 1.7 + runc

Debian 13 repo `trixie` có containerd 1.7, đủ cho K8s 1.30. Nếu muốn
phiên bản mới nhất (1.7.x) thì dùng package từ Docker:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt update
sudo apt install -y containerd.io
```

Generate default config + bật SystemdCgroup:
```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# Nâng pause image lên 3.9 (mặc định 3.6 too old)
sudo sed -i 's#sandbox_image = "registry.k8s.io/pause:.*"#sandbox_image = "registry.k8s.io/pause:3.9"#' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

## 7. kubeadm + kubelet + kubectl 1.30

```bash
KUBE_MINOR="1.30"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_MINOR}/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_MINOR}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet
```

## 8. Helm (chỉ cần trên admin laptop hoặc 7189srv01)

```bash
curl -fsSL https://baltocdn.com/helm/signing.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install -y helm
helm version
```

## 9. Pre-flight check trước khi `kubeadm init`

Trên `7189srv01`:
```bash
# Verify mỗi yêu cầu
echo "[1/8] containerd"; sudo systemctl is-active containerd
echo "[2/8] kubelet";    sudo systemctl is-enabled kubelet
echo "[3/8] swap off";   free -h | grep -i swap | awk '{print $3}' | grep -q '^0' && echo OK
echo "[4/8] modules";    lsmod | grep -E 'overlay|br_netfilter' | wc -l
echo "[5/8] sysctl";     sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
echo "[6/8] tailscale";  tailscale ip -4 | head -1
echo "[7/8] hostname";   hostname; cat /etc/hostname
echo "[8/8] DNS resolve"; getent hosts 7189srv01 || echo "MagicDNS not set"
```

## 10. Hostname và `/etc/hosts`

Set hostname đúng tên VM (không phải `debian`):
```bash
sudo hostnamectl set-hostname 7189srv01    # tương tự 7189srv02..04
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts
```

## 11. Chống Dynamic IP (VMware NAT DHCP)

VMware Workstation NAT có thể đổi IP DHCP của VM. Tailscale IP **ổn định**
nên cluster nội bộ không vấn đề, nhưng SSH từ laptop qua VMware NAT IP
sẽ rớt. Có 3 hướng:
- **A (recommended)**: SSH luôn qua Tailscale hostname (`7189srv01.<tailnet>.ts.net`)
  → IP NAT đổi không sao.
- **B**: cấu hình DHCP reservation trong VMware:
  - Win: Edit → Virtual Network Editor → VMnet8 → DHCP Settings → Add static.
- **C**: set static IP trong `/etc/network/interfaces` (Debian) — không
  khuyến nghị vì conflict DHCP server VMware.

## 12. Thời gian + NTP

Cluster K8s nhạy cảm với clock skew (etcd lease, mTLS cert):
```bash
sudo apt install -y systemd-timesyncd
sudo timedatectl set-ntp true
timedatectl status   # System clock synchronized: yes
```

VMware Tools có sync clock với host — verify nó OK:
```bash
sudo systemctl status open-vm-tools 2>/dev/null \
  || (sudo apt install -y open-vm-tools && sudo systemctl enable --now open-vm-tools)
```

## 13. Xong giai đoạn này

Sau khi 4 VM cài xong base, từ admin laptop:
```bash
for vm in 7189srv01 7189srv02 7189srv03 7189srv05; do
  # srv01-03: user 'debian'. srv05 (Ubuntu): user 'ptb' — đổi prefix tương ứng.
  user=$([ "$vm" = "7189srv05" ] && echo ptb || echo debian)
  echo "=== $vm ($user) ==="
  ssh ${user}@$vm.<tailnet>.ts.net 'echo OK; systemctl is-active containerd kubelet; tailscale ip -4'
done
```

Output kỳ vọng: 4 lần "OK + active + active + 100.X.X.X".

Tiến tới `07-kubeadm-bootstrap.md`.
