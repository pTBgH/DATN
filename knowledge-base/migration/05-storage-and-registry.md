# 05. Storage & Registry

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


## 1. Vấn đề khi rời Kind

Kind dùng `provisioner=rancher.io/local-path` (có sẵn trong image
`kindest/node`) và bind-mount thư mục host `/var/lib/job7189-*` vào tất cả
node — coi như RWX vì là cùng host. Khi tách thành 4 VM:
- PVC neo trên 1 node cụ thể → pod RECREATE phải đúng node đó.
- StatefulSet (MySQL, Vault) cần `volumeClaimTemplates` ổn định.
- Filebeat DS dùng `/var/log/containers` của TỪNG node — vẫn OK vì
  hostPath là local theo nghĩa "mỗi VM có log riêng".
- In-cluster docker-registry mới phải reachable từ mọi node.

## 2. Lựa chọn storage backend

| Option | Pro | Con | Khuyến nghị |
|--------|-----|-----|-------------|
| **local-path-provisioner** (Rancher) | Native trong K8s, 1 deployment, dùng hostPath dưới hood | Không RWX, PVC neo node | ✅ Chọn cho ZTA lab |
| Longhorn | Replication, snapshot, RWX | +500 Mi/node, phức tạp | Quá nặng cho 20.8 GB |
| NFS server-of-1 (trên 7189srv05) | Đơn giản, RWX | Single point of failure | Dùng làm phụ cho MinIO/storage-service nếu cần RWX |
| Ceph Rook | Production grade | Quá nặng | Bỏ qua |

→ **Quyết định**: `local-path-provisioner` v0.0.30 cho mọi PVC, NFS
server-of-1 trên `7189srv05` cho 1 use case duy nhất nếu MinIO hoặc
storage-service cần RWX (kiểm chứng sau).

## 3. local-path-provisioner triển khai

### Cài đặt
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
```

Mặc định nó tạo StorageClass `local-path` (NOT default). Để các PVC cũ của
ZTA (ghi `storageClassName: standard`) tiếp tục chạy mà không phải sửa
manifest, **alias** tên `standard` về `local-path`:

```yaml
# alias-standard-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

> `WaitForFirstConsumer`: PV được tạo CHỈ KHI pod được schedule trên 1 node
> cụ thể. Đảm bảo PV nằm cùng node với pod tiêu thụ.

### NodeAffinity cho data PVC — tất cả stateful pin vào `7189srv05`

PVC của MySQL/Vault/Kafka/ES/Prometheus/SPIRE-server/registry phải neo
vào `7189srv05` (Ubuntu always-on). Cách 1: pod schedule trên srv05 nhờ
nodeAffinity → PVC tự đi theo (vì `WaitForFirstConsumer`). Cách 2: viết
`PersistentVolume` thủ công với `nodeAffinity` cứng. **Chọn cách 1**.

Trong helmfile / manifest StatefulSet:
```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values: ["7189srv05"]
```

Không dùng custom label `zta.workload.tier=data` — dùng trực tiếp
`kubernetes.io/hostname` cho đơn giản. Chỉ 1 node always-on nên không
cần abstraction tier.

PVC cũ trong các manifest hiện có (`infras/k8s-yaml/01-mysql-phpmyadmin.yaml`,
`11-vault.yaml`, `12-docker-registry.yaml`) **chỉ cần** thay
`storageClassName: standard` → vẫn OK (vì alias).

### Path trên VM 7189srv05

local-path-provisioner mặc định ghi vào `/opt/local-path-provisioner/`.
Để khớp pattern `/var/lib/job7189-*` của thesis (xem
`zta-teardown.sh` xóa path này), override path bằng ConfigMap khi cài:

```yaml
# helm-values cho local-path:
nodePathMap:
  - node: 7189srv05
    paths:
      - /var/lib/job7189-mysql
      - /var/lib/job7189-vault
      - /var/lib/job7189-kafka
      - /var/lib/job7189-elasticsearch
      - /var/lib/job7189-prometheus
      - /var/lib/job7189-registry
      - /var/lib/job7189-spire
  # Stateless workload không cần PVC — nhưng để default cho mọi node
  # tránh provisioner báo lỗi nếu một Helm chart tạo PVC đột xuất:
  - node: 7189srv01
    paths: ["/opt/local-path-provisioner"]
  - node: 7189srv02
    paths: ["/opt/local-path-provisioner"]
  - node: 7189srv03
    paths: ["/opt/local-path-provisioner"]
```

> Nếu config quá phức tạp, đơn giản hóa: dùng default path
> `/opt/local-path-provisioner` cho mọi PVC, không cố ép tên thư mục
> giống ZTA cũ. Update `zta-teardown.sh` để xóa path mới.

## 4. Docker Registry trên Ubuntu HOST (baosrc)

### Lựa chọn thiết kế
Chúng ta sử dụng **Option A**: Chạy registry trực tiếp trên máy chủ chứa VM (`baosrc`), thay vì chạy registry bên trong cụm Kubernetes.

- **Địa chỉ Registry**: `100.74.189.43:5443` (IP Tailscale của máy `baosrc`).
- **Giao thức**: HTTPS trên port `5443` (sử dụng chứng chỉ TLS được cấp bởi Vault CA).
- **Lý do**: Tránh quá tải RAM của srv05, bảo toàn dữ liệu image khi reset cluster, và giải quyết vấn đề "chicken-and-egg" khi bootstrap cluster.

### Thay đổi và Cấu hình đã thực hiện

1. **Cấu hình HTTPS trên baosrc**:
   - Container `zta-registry` được cấu hình mount certificates từ `/var/lib/zta-registry/certs`.
   - Docker daemon trên `baosrc` tin tưởng CA qua `/etc/docker/certs.d/100.74.189.43:5443/ca.crt`.

2. **Cấu hình containerd trên toàn bộ cluster nodes**:
   - Tự động hóa việc cấu hình registry qua DaemonSet `containerd-certs-setup` trong namespace `kube-system`.
   - DaemonSet thực hiện tạo thư mục và ghi file trên từng node host:
     - `/etc/containerd/certs.d/100.74.189.43:5443/hosts.toml`
     - `/etc/containerd/certs.d/100.74.189.43:5443/ca.crt`
   - File `hosts.toml` trỏ trực tiếp đến registry:
     ```toml
     server = "https://100.74.189.43:5443"

     [host."https://100.74.189.43:5443"]
       capabilities = ["pull", "resolve"]
       ca = "/etc/containerd/certs.d/100.74.189.43:5443/ca.crt"
     ```

3. **Deploy & Build Pipeline**:
   - Sử dụng script `scripts/build_and_deploy.sh` để build image, push lên `100.74.189.43:5443`, giải quyết digest và cập nhật trực tiếp vào file values của Helm.
   - Các pod trong cụm sẽ kéo image trực tiếp từ `100.74.189.43:5443` qua kết nối HTTPS bảo mật, sau khi được ký bằng `cosign`.


## 5. NFS server-of-1 (optional, chỉ khi cần)

Nếu storage-service hoặc MinIO cần RWX (dùng chung object store giữa pods
trên các node khác nhau), bật NFS trên `7189srv05` (cuối cùng đã always-on):

```bash
sudo apt install -y nfs-kernel-server
sudo mkdir -p /var/lib/job7189-shared
sudo chown nobody:nogroup /var/lib/job7189-shared
echo '/var/lib/job7189-shared 100.64.10.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl enable --now nfs-server
```

Cài nfs-subdir-external-provisioner:
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-rwx nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -n storage --create-namespace \
  --set nfs.server=100.64.10.4 \
  --set nfs.path=/var/lib/job7189-shared \
  --set storageClass.name=nfs-rwx
```

PVC nào cần RWX → `storageClassName: nfs-rwx`. Mặc định
`storageClassName: standard` (= local-path) cho phần còn lại.

## 6. Backup strategy

Lab PoC, không cần snapshot tự động. Backup thủ công:
```bash
# Trên 7189srv05
sudo tar czf /tmp/data-backup-$(date +%F).tar.gz \
  /var/lib/job7189-{mysql,vault,kafka,elasticsearch,prometheus,registry,spire}
# scp qua admin laptop
scp 7189srv05.<tailnet>.ts.net:/tmp/data-backup-*.tar.gz ~/backups/
```

Nếu user muốn restore điểm thời gian (e.g. trước demo): snapshot VMware
**toàn bộ VM** (Snapshot Manager → Take Snapshot) trước khi chạy demo.

## 7. Disk pressure eviction

Pod sẽ bị evict khi `nodefs.available < 10%` (đã config trong
`03-vm-sizing.md` §5). Theo dõi:
```bash
df -h /var/lib/containerd /var/lib/job7189-elasticsearch
kubectl describe node 7189srv05 | grep -A4 "Conditions:"
```

Nếu Elasticsearch ăn hết disk → `kubectl exec` vào ES, `DELETE /index-name`
hoặc giảm retention `index.lifecycle.delete_phase.min_age=3d`.
