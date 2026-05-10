# 09. Cluster Services Bring-up — addon CRDs/controller

> Tiền điều kiện: 4 nodes Ready, Cilium up (mục `08-cilium-install.md`).

Mục tiêu: cài các "thứ-không-thuộc-ZTA-nhưng-cần-trước-ZTA" — Gateway API
CRDs, cert-manager, ingress-nginx, metrics-server, local-path-provisioner.
Tương đương `01-setup-cluster.sh` step 4-9 (đã đoạn lệnh `kind`).

## 1. Gateway API CRDs

```bash
kubectl apply --server-side --validate=false \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```

## 2. cert-manager v1.14.7

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack
helm upgrade --install cert-manager jetstack/cert-manager \
  --version v1.14.7 \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --set webhook.timeoutSeconds=30 \
  --set extraArgs="{--enable-gateway-api}" \
  --wait --timeout 5m
```

Verify:
```bash
kubectl -n cert-manager get pod
# 3 pod: cert-manager, cert-manager-webhook, cert-manager-cainjector
```

## 3. ingress-nginx (NodePort 30001 HTTPS, 30003 HTTP)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version 4.10.0 \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30003 \
  --set controller.service.nodePorts.https=30001 \
  --set controller.metrics.enabled=true \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=90Mi \
  --set controller.resources.limits.cpu=500m \
  --set controller.resources.limits.memory=256Mi \
  --wait --timeout 5m
```

> Không pin ingress-nginx vào node cụ thể — K8s scheduler chọn worker phù
> hợp dựa trên RAM. Nếu sau này muốn ép, dùng `nodeSelector:
> kubernetes.io/hostname: 7189srv02` trong values.

Truy cập từ admin laptop: `https://7189srv02.<tailnet>.ts.net:30001/`
(thay `7189srv02` bằng bất kỳ worker nào ingress đang chạy — K8s scheduler
tự đặt).

## 4. metrics-server

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update metrics-server
helm upgrade --install metrics-server metrics-server/metrics-server \
  --version 3.12.1 \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --set 'args[1]=--kubelet-preferred-address-types=InternalIP\,Hostname' \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=50Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=100Mi \
  --wait --timeout 5m
```

Verify:
```bash
sleep 30
kubectl top nodes
kubectl top pod -A | head
```

## 5. local-path-provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
```

Edit để dùng path `/var/lib/job7189-*` (xem `05-storage-and-registry.md` §3):
```bash
kubectl -n local-path-storage edit cm local-path-config
# hoặc kubectl patch cm local-path-config -n local-path-storage --type=json \
#   -p='[{"op":"replace","path":"/data/config.json","value":"..."}]'
```

Alias `standard` → `local-path`:
```yaml
# /tmp/standard-storageclass.yaml
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

```bash
kubectl apply -f /tmp/standard-storageclass.yaml
kubectl get sc
```

## 6. In-cluster Docker Registry

Từ `infras/k8s-yaml/12-docker-registry.yaml` (đã có sẵn). Adapt:
- NodeAffinity `kubernetes.io/hostname=7189srv04` (always-on, có PVC)
- Service NodePort 30005

```bash
# tạo file mới: infras/k8s-yaml/12-docker-registry-multi-vm.yaml
# (chỉ thêm nodeAffinity + nodePort vào file gốc)
kubectl apply -f infras/k8s-yaml/12-docker-registry-multi-vm.yaml
```

## 7. Containerd config trên 4 VM (cho image pull qua registry)

Trên TẤT CẢ 4 VM:
```bash
sudo mkdir -p /etc/containerd/certs.d/7189srv04.<tailnet>.ts.net:30005
sudo tee /etc/containerd/certs.d/7189srv04.<tailnet>.ts.net:30005/hosts.toml <<'EOF'
server = "http://7189srv04.<tailnet>.ts.net:30005"

[host."http://7189srv04.<tailnet>.ts.net:30005"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

sudo systemctl restart containerd
```

## 8. Sanity smoke test

```bash
# Test 1: tạo PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smoke-test
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: standard
  resources: { requests: { storage: 1Gi } }
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: smoke
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    volumeMounts:
    - { name: vol, mountPath: /data }
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: smoke-test
EOF

kubectl wait --for=condition=Ready pod/smoke --timeout=120s
kubectl exec -it smoke -- df -h /data
kubectl delete pod smoke
kubectl delete pvc smoke-test
```

# Test 2: cross-node pod-to-pod
```bash
kubectl run alpine-1 --image=alpine:3.19 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"7189srv02"}}}' --command -- sleep 600
kubectl run alpine-2 --image=alpine:3.19 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"7189srv04"}}}' --command -- sleep 600
kubectl wait --for=condition=Ready pod/alpine-1 pod/alpine-2 --timeout=120s
IP1=$(kubectl get pod alpine-1 -o jsonpath='{.status.podIP}')
kubectl exec alpine-2 -- ping -c 3 $IP1
kubectl delete pod alpine-1 alpine-2
```

Kỳ vọng: ping success, RTT < 50ms.

## 9. Hubble flow check (post-test)

```bash
kubectl -n kube-system port-forward svc/hubble-relay 4245:80 &
hubble observe --pod default/alpine-2 --since 5m
```

Phải thấy ICMP forwarded từ alpine-2 (7189srv04) → alpine-1 (7189srv02) qua VXLAN.

## 10. Snapshot baseline

Lưu output này vào `evidence/migration-baseline-$(date +%F).txt`:
```bash
{
  echo "=== Cluster nodes ==="
  kubectl get nodes -o wide
  echo
  echo "=== Cilium status ==="
  cilium status
  echo
  echo "=== Storage classes ==="
  kubectl get sc
  echo
  echo "=== System pods ==="
  kubectl get pod -A
  echo
  echo "=== Resource usage ==="
  kubectl top node
  kubectl top pod -A | head -30
} > evidence/migration-baseline-$(date +%F).txt
```

Đây là chứng cứ "cluster ZTA Phase 0 (multi-VM) up". Sau đó chạy
`02-deploy-infrastructure.sh` (đã adapt — xem `10-zta-pipeline-adaptations.md`).
