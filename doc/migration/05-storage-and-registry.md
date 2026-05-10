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
| NFS server-of-1 (trên 7189srv04) | Đơn giản, RWX | Single point of failure | Dùng làm phụ cho MinIO/storage-service nếu cần RWX |
| Ceph Rook | Production grade | Quá nặng | Bỏ qua |

→ **Quyết định**: `local-path-provisioner` v0.0.30 cho mọi PVC, NFS
server-of-1 trên `7189srv04` cho 1 use case duy nhất nếu MinIO hoặc
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

### NodeAffinity cho data PVC — tất cả stateful pin vào `7189srv04`

PVC của MySQL/Vault/Kafka/ES/Prometheus/SPIRE-server/registry phải neo
vào `7189srv04` (Ubuntu always-on). Cách 1: pod schedule trên srv04 nhờ
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
                values: ["7189srv04"]
```

Không dùng custom label `zta.workload.tier=data` — dùng trực tiếp
`kubernetes.io/hostname` cho đơn giản. Chỉ 1 node always-on nên không
cần abstraction tier.

PVC cũ trong các manifest hiện có (`infras/k8s-yaml/01-mysql-phpmyadmin.yaml`,
`11-vault.yaml`, `12-docker-registry.yaml`) **chỉ cần** thay
`storageClassName: standard` → vẫn OK (vì alias).

### Path trên VM 7189srv04

local-path-provisioner mặc định ghi vào `/opt/local-path-provisioner/`.
Để khớp pattern `/var/lib/job7189-*` của thesis (xem
`zta-teardown.sh` xóa path này), override path bằng ConfigMap khi cài:

```yaml
# helm-values cho local-path:
nodePathMap:
  - node: 7189srv04
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
1. Đặt registry trên `7189srv04` (always-on, có PVC):
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
                   values: ["7189srv04"]
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
   docker login 7189srv04.<tailnet>.ts.net:30005   # nếu có auth, hoặc bỏ
   docker tag job7189/identity-service:dev 7189srv04.<tailnet>.ts.net:30005/job7189/identity-service:dev
   docker push 7189srv04.<tailnet>.ts.net:30005/job7189/identity-service:dev
   ```
4. Trên mọi VM (7189srv01..04), config containerd để trust HTTP registry
   này:
   ```toml
   # /etc/containerd/certs.d/7189srv04.<tailnet>.ts.net:30005/hosts.toml
   server = "http://7189srv04.<tailnet>.ts.net:30005"

   [host."http://7189srv04.<tailnet>.ts.net:30005"]
     capabilities = ["pull", "resolve"]
     skip_verify = true
   ```
5. Helm values cho 7 Laravel:
   ```yaml
   image:
     repository: 7189srv04.<tailnet>.ts.net:30005/job7189/identity-service
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
trên các node khác nhau), bật NFS trên `7189srv04` (cuối cùng đã always-on):

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
# Trên 7189srv04
sudo tar czf /tmp/data-backup-$(date +%F).tar.gz \
  /var/lib/job7189-{mysql,vault,kafka,elasticsearch,prometheus,registry,spire}
# scp qua admin laptop
scp 7189srv04.<tailnet>.ts.net:/tmp/data-backup-*.tar.gz ~/backups/
```

Nếu user muốn restore điểm thời gian (e.g. trước demo): snapshot VMware
**toàn bộ VM** (Snapshot Manager → Take Snapshot) trước khi chạy demo.

## 7. Disk pressure eviction

Pod sẽ bị evict khi `nodefs.available < 10%` (đã config trong
`03-vm-sizing.md` §5). Theo dõi:
```bash
df -h /var/lib/containerd /var/lib/job7189-elasticsearch
kubectl describe node 7189srv04 | grep -A4 "Conditions:"
```

Nếu Elasticsearch ăn hết disk → `kubectl exec` vào ES, `DELETE /index-name`
hoặc giảm retention `index.lifecycle.delete_phase.min_age=3d`.
