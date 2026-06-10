# Docker registry — đặt ở đâu trong setup multi-VM?

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


> Bạn hỏi: "docker registry nên để ở đâu? nó có cần build trên k8s
> không? hiện tại hình như mình đang để nó nằm ngoài thì phải"
>
> File này phân tích 4 lựa chọn + khuyến nghị + cách setup chi tiết.

---

## TL;DR

**Khuyến nghị: Chạy registry như Docker container TRÊN UBUNTU HOST (baosrc)**
(ngoài K8s, ngoài VM srv05). 

> [!NOTE]
> **Cập nhật 2026-06-10**: Option A đã được triển khai chạy trên HTTPS port `5443` bằng cách sử dụng chứng chỉ TLS được ký bởi Vault CA. Các cluster node đã được cấu hình tự động thông qua DaemonSet để trust kết nối HTTPS này.

Lý do chọn Option A:

1. **Tách lifecycle khỏi K8s**: `kubeadm reset`, snapshot revert, hay
   wipe srv05 → registry KHÔNG mất images. Re-build lại 7 Laravel images
   mất 15-30 phút mỗi lần — không muốn lặp đi lặp lại.
2. **Không tốn RAM của srv05**: srv05 chỉ còn 4 GB, đã chật chội với
   MySQL + Vault + Kafka + SPIRE. In-cluster registry thêm 256 Mi limit
   là phần không đáng để nhét vào.
3. **Bootstrap chicken-and-egg**: Khi cluster vừa lên (sau `04-cilium-install.sh`),
   cluster chưa có pod nào. Nếu registry CŨNG là pod K8s, làm sao mà
   pod identity-service kéo image từ registry-pod-chưa-tồn-tại?
   → External registry tránh hẳn vấn đề này.
4. **Đúng với hiện tại của bạn**: bạn nói "hình như mình đang để nó
   nằm ngoài" — `04-build-and-push-images.sh` mặc định
   `REGISTRY_HOST=localhost:5000`, build trên admin máy thì push thẳng
   vào localhost (không vào K8s registry).

---

## Hiện trạng repo (hỗn hợp, hơi confused)

| File | Hiện trạng |
|------|-----------|
| `04-build-and-push-images.sh` | Build trên admin laptop, default push tới `localhost:5000` (Docker registry chạy sẵn trên admin laptop) |
| `infras/k8s-yaml/12-docker-registry.yaml` | Manifest deploy registry **trong K8s** với 50Gi PVC, NodePort 30005 |
| `k8s-management/charts/laravel-app/templates/deployment.yaml` | Image tag = `<registry-helper>/<repo>:<tag>`. Nếu `image.registry=""`, fallback về Docker Hub (sẽ KHÔNG hoạt động cho `job7189/identity-service`) |
| `k8s-management/values/identity-values.yaml` | `image.registry: ""` (rỗng) |
| Kind workflow cũ | `docker build` → `kind load docker-image` (không cần registry trong cluster) |

→ **Pipeline cũ chạy được trên Kind vì `kind load docker-image` copy
image trực tiếp vào node. Multi-VM kubeadm KHÔNG có cơ chế đó**.
Image phải ở registry mà containerd trên mỗi VM pull được.

---

## 4 phương án

### Phương án A — Registry trên **Ubuntu HOST** (KHUYẾN NGHỊ)

```
[Admin laptop]
   │ docker build job7189/identity-service:v2.8.18
   │ docker push <ubuntu-host-tailscale-ip>:5000/job7189/identity-service:v2.8.18
   │
   ▼
[Ubuntu HOST] (8 GB RAM, 1 vCPU dành cho host)
   │
   │ docker run -d --restart=always --name registry \
   │   -p 5000:5000 -v /var/lib/registry:/var/lib/registry \
   │   registry:2
   │
   ▼
[Tailscale advertises Ubuntu host IP, e.g. 100.64.10.5]
   │
   ▼
[VM srv01..04] containerd cấu hình: registry-mirrors = "http://100.64.10.5:5000"
   │
   ▼ pull
[K8s pod identity-service spawns on srv02 → containerd pulls from 100.64.10.5:5000]
```

**Pros**:
- Survives `kubeadm reset`, `helm uninstall`, VM snapshot revert
- 0 RAM trên VM (chạy trên host kernel)
- Disk dùng disk của host (rộng hơn 60 GB của srv05)
- Auth tùy chọn: bật basic auth khi cần (lab env không cần)
- Setup 5 phút

**Cons**:
- Phụ thuộc Ubuntu host up. Nếu host crash → registry down → pod restart sẽ fail pull. Nhưng:
  - Ubuntu host = "always-on host" theo design (đã chọn srv05 vì lý do này)
  - imagePullPolicy=IfNotPresent → containerd cache trên VM vẫn cho pod chạy lại miễn là chưa GC
- Registry HTTP plain (không TLS) → cần config `[insecure_registries]` trên containerd của 4 VM. Đối với lab acceptable.

**Cách setup**: xem §"Setup chi tiết phương án A" bên dưới.

---

### Phương án B — Registry **in-cluster trên srv05**

Như `infras/k8s-yaml/12-docker-registry.yaml` đang làm: deploy
`registry:2` trong K8s namespace `registry`, NodePort 30005, PVC 50 Gi
(local-path trên srv05).

**Pros**:
- "K8s-native", quản lý cùng K8s lifecycle
- TLS qua cert-manager nếu cần
- HA dễ hơn (replica > 1 với S3 backend)

**Cons (rất nặng cho setup này)**:
- **Chicken-and-egg**: lúc bootstrap cluster, NodePort 30005 chưa lên → pod khác kéo image cách nào? Phải pre-load image vào containerd của mỗi VM thủ công. Mỗi lần re-deploy phải nhớ làm.
- **OOM trên srv05**: srv05 4 GB đã trim Vault/MySQL/Kafka đến mức tối thiểu. Thêm 256 Mi cho registry là vượt budget.
- **Mất state khi `kubeadm reset`**: PVC trên local-path đi theo node — `kubeadm reset` của srv05 = mất registry storage = mất tất cả image cache.
- **NodePort routing qua Cilium**: thêm 1 hop network, nếu Cilium agent trên srv05 lỗi thì registry NodePort cũng lỗi → không bootstrap được.

→ Skip. Phương án này chỉ hợp lý nếu cluster ĐÃ stable + production lab có ≥8 GB cho mỗi node.

---

### Phương án C — Registry **trên admin laptop** (`localhost:5000`)

Default hiện tại của `04-build-and-push-images.sh`. Dùng cho dev nhanh.

**Pros**:
- Setup 30 giây: `docker run -d -p 5000:5000 registry:2`

**Cons**:
- Chỉ available khi admin laptop up + trên tailnet
- Cluster KHÔNG kéo được từ `localhost:5000` của admin (admin localhost ≠ VM localhost)
- Phải dùng `<admin-tailscale-ip>:5000` thay vì `localhost:5000` từ VM perspective
- Không phù hợp khi user demo thesis qua VM mà không có laptop

→ Tương tự A nhưng kém ổn định. **Skip nếu Ubuntu host khả dụng**.

---

### Phương án D — Cloud registry (Docker Hub / GHCR / GitLab)

Push lên public/private cloud registry.

**Pros**:
- Không cần setup gì trên local
- Auto-pull khi cluster fresh

**Cons**:
- Cần internet bandwidth + auth token
- Pull lần đầu chậm (7 image × ~500 MB = 3.5 GB từ internet)
- Lộ tag thesis ra public unless private (cần $)
- Vi phạm "Zero Trust" thesis spirit (untrusted internet bị chèn vào supply chain)

→ Skip cho thesis lab.

---

## Setup chi tiết phương án A

### Bước 1: Lấy Tailscale IP của Ubuntu host

Đảm bảo Ubuntu host (KHÔNG phải srv05 VM) đã chạy Tailscale:

```bash
# Trên Ubuntu HOST (không phải trong VM)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=ubuntu-host --accept-dns=true
tailscale ip -4
# Giả sử output: 100.64.10.5
```

Note IP này → dùng làm `REGISTRY_HOST` xuyên suốt.

### Bước 2: Run registry container trên Ubuntu host

```bash
# Trên Ubuntu HOST
sudo mkdir -p /var/lib/job7189-registry
sudo docker run -d --name zta-registry --restart=always \
  -p 5000:5000 \
  -v /var/lib/job7189-registry:/var/lib/registry \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2

# Kiểm tra
curl http://localhost:5000/v2/_catalog
# Expected: {"repositories":[]}

# Disk usage tracking
du -sh /var/lib/job7189-registry
```

Tự khởi động lại sau reboot: tham số `--restart=always` đã bao luôn.

### Bước 3: Update repo config

Trên admin laptop (nơi build):

```bash
cd ~/DATN

# Set REGISTRY_HOST khi gọi 04-build-and-push-images.sh:
export ZTA_REGISTRY_HOST=100.64.10.5:5000

# Nếu repo có ZTA_REGISTRY_HOST trong helmfile/values, update:
sed -i 's|registry: ""|registry: "100.64.10.5:5000"|' k8s-management/values/*-values.yaml
# Hoặc edit từng file
```

### Bước 4: Cấu hình containerd trên 4 VM cho phép HTTP registry

`registry:2` chạy plain HTTP. containerd mặc định từ chối pull HTTP →
phải whitelist:

```bash
# Trên MỖI VM (srv01..04):
sudo mkdir -p /etc/containerd/certs.d/100.64.10.5:5000
sudo tee /etc/containerd/certs.d/100.64.10.5:5000/hosts.toml > /dev/null <<'EOF'
server = "http://100.64.10.5:5000"

[host."http://100.64.10.5:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

# Verify hosts.toml is being used (đã set trong /etc/containerd/config.toml mặc định)
sudo grep config_path /etc/containerd/config.toml
# Expected: config_path = "/etc/containerd/certs.d"
```

Nếu output không có `config_path`, thêm vào (`01-host-prep.sh` đã làm
phần này via `containerd config default`):

```bash
sudo sed -i 's|^\(\s*\)\[plugins\."io.containerd.grpc.v1.cri"\.registry\]|\1[plugins."io.containerd.grpc.v1.cri".registry]\n\1  config_path = "/etc/containerd/certs.d"|' /etc/containerd/config.toml
sudo systemctl restart containerd
```

### Bước 5: Build & push từ admin laptop

```bash
cd ~/DATN
ZTA_REGISTRY_HOST=100.64.10.5:5000 bash 04-build-and-push-images.sh

# Verify
curl http://100.64.10.5:5000/v2/_catalog
# Expected: {"repositories":["job7189/identity-service","job7189/workspace-service",...]}
```

### Bước 6: Smoke test pull từ VM

```bash
# SSH vào srv02
ssh ptb@7189srv02.<tailnet>.ts.net
sudo crictl pull 100.64.10.5:5000/job7189/identity-service:v2.8.18
# Expected: "Image is up to date for sha256:..."
```

### Bước 7: Helm values

Trong `k8s-management/values/*-values.yaml`:

```yaml
image:
  registry: "100.64.10.5:5000"   # tailscale IP của Ubuntu host
  repository: job7189/identity-service
  tag: "v2.8.18"
  pullPolicy: IfNotPresent
```

Helm template `laravel-app/templates/deployment.yaml` đã handle:

```yaml
{{- $registry := include "registry.url" . -}}
{{- if $registry }}
image: "{{ $registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
{{- else }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
{{- end }}
```

→ Khi pod identity-service spawn trên srv02, containerd thấy
`100.64.10.5:5000/...`, đọc `/etc/containerd/certs.d/100.64.10.5:5000/hosts.toml`,
plain HTTP pull thành công.

---

## Khi nào nên đổi sang in-cluster (option B)?

Nếu sau này:
- srv05 được bump lên 6+ GB
- Cluster đã stable >2 tuần không reset
- Bạn cần đa vùng storage (S3 backend cho registry)
- Demo thesis lift to production thật

Thì có thể migrate registry vào in-cluster. Setup trong file
`infras/k8s-yaml/12-docker-registry.yaml` đã sẵn sàng — chỉ cần:

```bash
kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml
# Update HOSTS_TOML trên VM trỏ về NodePort 30005:
# server = "http://7189srv05.<tailnet>.ts.net:30005"
```

Hiện tại GIỮ option A.

---

## Trả lời câu hỏi gốc

> "docker registry nên để ở đâu?"
> → **Ubuntu HOST** (không trong K8s, không trong VM srv05).

> "nó có cần build trên k8s không?"
> → KHÔNG. Build trên admin laptop bằng `docker build`, push tới
> registry trên Ubuntu host. K8s chỉ pull, không build.

> "hiện tại hình như mình đang để nó nằm ngoài thì phải"
> → Đúng. Default `04-build-and-push-images.sh` push lên
> `localhost:5000` (= chạy registry trên admin laptop). Bạn cần
> *move registry tới Ubuntu host* (sang luôn từ `localhost:5000` của
> admin laptop → `100.64.10.5:5000` của Ubuntu host) để khi laptop tắt
> vẫn pull được.
