# 05. Storage & Registry

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
| NFS server-of-1 (trên w-data) | Đơn giản, RWX | Single point of failure | Dùng làm phụ cho MinIO/storage-service nếu cần RWX |
| Ceph Rook | Production grade | Quá nặng | Bỏ qua |

→ **Quyết định**: `local-path-provisioner` v0.0.30 cho mọi PVC, NFS
server-of-1 trên `w-data` cho 1 use case duy nhất nếu MinIO hoặc
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

### NodeAffinity cho data PVC

PVC của MySQL/Vault/Kafka phải neo vào `w-data`. Cách 1: pod schedule trên
w-data nhờ nodeSelector / affinity → PVC tự đi theo (vì
`WaitForFirstConsumer`). Cách 2: viết `PersistentVolume` thủ công với
`nodeAffinity` cứng. **Chọn cách 1** — đơn giản.

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
              - key: zta.workload.tier
                operator: In
                values: ["data"]
```

PVC cũ trong các manifest hiện có (`infras/k8s-yaml/01-mysql-phpmyadmin.yaml`,
`11-vault.yaml`, `12-docker-registry.yaml`) **chỉ cần** thay
`storageClassName: standard` → vẫn OK (vì alias).

### Path trên VM w-data

local-path-provisioner mặc định ghi vào `/opt/local-path-provisioner/`.
Để khớp pattern `/var/lib/job7189-*` của thesis (xem
`zta-teardown.sh` xóa path này), override path bằng ConfigMap khi cài:

```yaml
# helm-values cho local-path:
nodePathMap:
  - node: w-data
    paths:
      - /var/lib/job7189-mysql      # cho PVC tên mysql-pvc
      - /var/lib/job7189-vault
      - /var/lib/job7189-kafka
      - /var/lib/job7189-keycloak
  - node: w-obs
    paths:
      - /var/lib/job7189-elasticsearch
      - /var/lib/job7189-prometheus
  - node: w-apps
    paths:
      - /var/lib/job7189-registry
```

> Nếu config quá phức tạp, đơn giản hóa: dùng default path
> `/opt/local-path-provisioner` cho mọi PVC, không cố ép tên thư mục
> giống ZTA cũ. Update `zta-teardown.sh` để xóa path mới.

## 4. In-cluster Docker Registry

### Vì sao cần
Build image trên admin laptop → push ở đâu? Kind cũ map `localhost:5000`
host port → worker3:5000. Multi-VM thì:
- Option A: chạy registry **trên admin laptop**, expose qua Tailscale
  Funnel/Serve, các node pull qua HTTPS Tailnet.
- Option B: chạy registry **trong cluster** (`registry` namespace), mọi
  node pull qua ClusterIP + image:tag dạng `registry.registry.svc:5000/...`.
- Option C: dùng GHCR (`ghcr.io/bpt03/...`) — yêu cầu PAT, chậm khi pull.

→ **Chọn B** (giống Kind cũ, đã có manifest `infras/k8s-yaml/12-docker-registry.yaml`,
chỉ cần điều chỉnh).

### Thay đổi cần làm
1. Đặt registry trên `w-apps` (label `tier=apps`):
   ```yaml
   spec:
     template:
       spec:
         affinity:
           nodeAffinity: ... tier=apps
   ```
2. Service NodePort 30005:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: docker-registry
     namespace: registry
   spec:
     type: NodePort
     ports:
     - port: 5000
       targetPort: 5000
       nodePort: 30005
   ```
3. Trên admin laptop:
   ```
   docker login w-apps.<tailnet>.ts.net:30005   # nếu có auth, hoặc bỏ
   docker tag job7189/identity-service:dev w-apps.<tailnet>.ts.net:30005/job7189/identity-service:dev
   docker push w-apps.<tailnet>.ts.net:30005/job7189/identity-service:dev
   ```
4. Trên mọi VM (cp1, w-data, w-apps, w-obs), config containerd để trust
   HTTP registry này:
   ```toml
   # /etc/containerd/certs.d/w-apps.<tailnet>.ts.net:30005/hosts.toml
   server = "http://w-apps.<tailnet>.ts.net:30005"

   [host."http://w-apps.<tailnet>.ts.net:30005"]
     capabilities = ["pull", "resolve"]
     skip_verify = true
   ```
5. Helm values cho 7 Laravel:
   ```yaml
   image:
     repository: w-apps.<tailnet>.ts.net:30005/job7189/identity-service
     tag: dev
     pullPolicy: Always
   ```

### Alt: Dùng `docker-registry.registry.svc.cluster.local:5000` cho pod-to-registry

Trong cluster, pod kéo image qua kubelet → containerd → DNS resolve
`docker-registry.registry.svc.cluster.local` về ClusterIP. Nhưng kubelet
**không** dùng cluster DNS để resolve image registry — kubelet dùng node's
`/etc/resolv.conf`. Vì vậy phải dùng tên reachable từ node:
**Tailscale MagicDNS hostname** là chọn ổn định nhất.

## 5. NFS server-of-1 (optional, chỉ khi cần)

Nếu storage-service hoặc MinIO cần RWX (dùng chung object store giữa pods
trên các node khác nhau), bật NFS trên `w-data`:

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
  --set nfs.server=100.64.10.2 \
  --set nfs.path=/var/lib/job7189-shared \
  --set storageClass.name=nfs-rwx
```

PVC nào cần RWX → `storageClassName: nfs-rwx`. Mặc định
`storageClassName: standard` (= local-path) cho phần còn lại.

## 6. Backup strategy

Lab PoC, không cần snapshot tự động. Backup thủ công:
```bash
# Trên w-data
sudo tar czf /tmp/data-backup-$(date +%F).tar.gz /var/lib/job7189-{mysql,vault,kafka,keycloak}
# scp qua admin laptop
scp w-data.<tailnet>.ts.net:/tmp/data-backup-*.tar.gz ~/backups/
```

Nếu user muốn restore điểm thời gian (e.g. trước demo): snapshot VMware
**toàn bộ VM** (Snapshot Manager → Take Snapshot) trước khi chạy demo.

## 7. Disk pressure eviction

Pod sẽ bị evict khi `nodefs.available < 10%` (đã config trong
`03-vm-sizing.md` §5). Theo dõi:
```bash
df -h /var/lib/containerd /var/lib/job7189-elasticsearch
kubectl describe node w-obs | grep -A4 "Conditions:"
```

Nếu Elasticsearch ăn hết disk → `kubectl exec` vào ES, `DELETE /index-name`
hoặc giảm retention `index.lifecycle.delete_phase.min_age=3d`.
