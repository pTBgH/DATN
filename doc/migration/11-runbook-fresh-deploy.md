# 11. Runbook — Fresh Deploy từ 0 trên multi-VM

> Operator runbook cho lần triển khai đầu tiên. Tổng thời gian ~3-5 giờ
> bao gồm cài Debian.

## Phase 0 — Chuẩn bị 4 VM (1 giờ)

### Trên VMware Workstation (Windows host)

1. Tải Debian 13 "Trixie" netinst ISO từ https://www.debian.org/distrib/netinst.
2. Tạo 3 VM trên Windows host theo `03-vm-sizing.md` §7:

| VM | RAM (MB) | vCPU | Disk (GB) | NIC mode |
|----|----------|------|-----------|----------|
| 7189srv01 | 2048 | 1 | 40 | NAT |
| 7189srv02 | 4608 | 2 | 50 | NAT |
| 7189srv03 | 5120 | 2 | 50 | NAT |

3. Cài Debian server-only (không GNOME, không web server):
   - Hostname: `7189srv01`, `7189srv02`, `7189srv03` tương ứng
   - User `debian` (password tạm; sẽ đổi thành SSH key only)
   - Đánh dấu **chỉ "SSH server" + "standard system utilities"** trong
     tasksel (tránh cài thêm package vô ích)

### Trên VMware Workstation (Ubuntu host)

4. Trên Ubuntu host, tạo `7189srv04`: 6144 MB / 2 vCPU / 80 GB / NAT.
   Hostname: `7189srv04`. Đây là VM **always-on** chứa tất cả stateful
   workload (vault-dev, vault-prod, MySQL, Kafka, ES, Prometheus,
   docker-registry, SPIRE server).

### Common cho 4 VM

5. Boot xong: `ssh debian@<vmware-nat-ip>` từ host tương ứng.
6. Chạy script chuẩn bị (xem `06-debian-base-prep.md`) trên TỪNG VM:
   - Tailscale install + auth
   - containerd 1.7
   - kubeadm/kubelet/kubectl 1.30
   - sysctl, modules, swap
   - `hostnamectl set-hostname <name>`

## Phase 1 — Bootstrap K8s (30 phút)

```bash
# Trên 7189srv01
sudo kubeadm config images pull --kubernetes-version v1.30.0
sudo kubeadm init --config=/root/kubeadm-config.yaml --skip-phases=addon/kube-proxy --upload-certs

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Lưu lệnh kubeadm join từ output
echo "<paste join command output>" > /tmp/kubeadm-join.cmd
```

Trên 3 worker (`7189srv02`, `7189srv03`, `7189srv04`) — chạy lệnh join
(xem `07-kubeadm-bootstrap.md` §5).

```bash
# Verify từ admin laptop
export KUBECONFIG=~/.kube/config-job7189
kubectl get nodes
# Kỳ vọng 4 node NotReady (chưa Cilium)
```

## Phase 2 — Cilium + addon (30 phút)

```bash
# Trên admin laptop
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium \
  --version 1.19.1 -n kube-system \
  -f doc/migration/cilium-values-multi-vm.yaml \
  --wait --timeout 10m

# Wait for nodes Ready
kubectl wait node --all --for=condition=Ready --timeout=300s

# Label node always-on (không dùng tier-based labels cho stateless)
kubectl label node 7189srv04 zta.workload.always-on=true
```

Cài Gateway API, cert-manager, ingress-nginx, metrics-server,
local-path-provisioner (xem `09-cluster-services-bringup.md`):

```bash
# Có thể đóng gói thành 1 script duy nhất sau khi user duyệt plan
bash doc/migration/scripts/01-cluster-bringup.sh    # placeholder name
```

## Phase 3 — In-cluster registry + push images (45 phút)

```bash
# Apply manifest registry
kubectl apply -f infras/k8s-yaml/12-docker-registry-multi-vm.yaml

# Build + push 7 Laravel
ZTA_REGISTRY_HOST="7189srv04.<tailnet>.ts.net:30005" \
  bash 04-build-and-push-images.sh

# Verify
curl -s http://7189srv04.<tailnet>.ts.net:30005/v2/_catalog | jq
```

## Phase 4 — ZTA stack (60-90 phút)

Sau khi adapt scripts (xem `10-zta-pipeline-adaptations.md`):

```bash
# Từ admin laptop, KUBECONFIG đã set
cd /path/to/DATN

# Pre-flight
kubectl get --raw=/readyz
kubectl top nodes   # mỗi node free RAM > 1 GiB

# Run ZTA pipeline trong external-cluster mode
bash scripts/zta-rebuild.sh --external-cluster --yes
```

`scripts/zta-rebuild.sh` sẽ:
- Skip step `01-cluster` (đã có cluster external)
- Run `02-infra` → `03-microservices` → `05-seed` → `07-monitoring`
- Run `08-harden` với `ZTA_HARDEN_WIREGUARD=0` (Tailscale đã encrypt)
- Run `90-verify`

## Phase 5 — Full enforcement (30 phút)

```bash
bash scripts/zta-rebuild.sh --external-cluster --full-enforcement --yes
```

Bật thêm: Tetragon, SPIRE, Cosign policy-controller, Hubble export,
Gatekeeper, PDP, Trivy.

## Phase 6 — Verify + evidence (15 phút)

```bash
bash 09-verify-zta.sh
ls -la evidence/
```

Kỳ vọng:
- 35-50 PASS (40-50 ở `--full-enforcement`)
- 0-2 FAIL (Vault sealed initial là expected; chạy unseal)
- Evidence files trong `evidence/<timestamp>/`

## Phase 7 — Demo / live test

```bash
# Test JWT enforcement qua Tailscale (thay 7189srv02 bằng worker nào
# ingress-nginx đang chạy — K8s scheduler tự đặt):
curl -i https://7189srv02.<tailnet>.ts.net:30001/api/v1/jobs
# Kỳ vọng: 401 (no JWT)

curl -i https://7189srv02.<tailnet>.ts.net:30001/api/v1/jobs \
  -H "Authorization: Bearer $(...)"
# Kỳ vọng: 200

# Test Hubble flow drop
kubectl run untrusted --image=alpine:3.19 -n default --command -- sleep 600
kubectl exec -it untrusted -n default -- wget -qO- mysql.data:3306
# Kỳ vọng: timeout (default-deny)
hubble observe --from-pod default/untrusted --verdict DROPPED -n 5
```

## Tổng kết time-to-cluster

| Phase | Thời gian | Cumulative |
|-------|-----------|-----------|
| 0. VM + Debian + Tailscale | 60 phút | 60 |
| 1. kubeadm init + join | 30 phút | 90 |
| 2. Cilium + addon | 30 phút | 120 |
| 3. Registry + image build | 45 phút | 165 |
| 4. ZTA base | 75 phút | 240 |
| 5. Full enforcement | 30 phút | 270 |
| 6. Verify | 15 phút | 285 |
| **Tổng (lần đầu)** | **~5 giờ** | |
| **Lần 2 trở đi** (re-run rebuild) | **~45-60 phút** | (skip Phase 0-2) |

Sau khi VM đã setup xong, mỗi rebuild ZTA chỉ cần Phase 4-6.
