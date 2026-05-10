# 07. kubeadm Bootstrap — init cp1 + join 3 worker

> Tiền điều kiện: `06-debian-base-prep.md` chạy xong cho cả 4 VM.

## 1. Pull pre-required images (cp1)

Pre-pull để `kubeadm init` không tốn 5-7 phút download:
```bash
sudo kubeadm config images pull --kubernetes-version v1.30.0
```

## 2. Tạo `kubeadm-config.yaml` trên cp1

```bash
TAILNET_DOMAIN="<your-tailnet>.ts.net"   # đổi cho khớp tailnet
CP_TS_IP="$(tailscale ip -4 | head -1)"

cat <<EOF | sudo tee /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${CP_TS_IP}"
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: "${CP_TS_IP}"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.30.0
clusterName: job7189
controlPlaneEndpoint: "${CP_TS_IP}:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  dnsDomain: cluster.local
apiServer:
  certSANs:
    - "${CP_TS_IP}"
    - "cp1"
    - "cp1.${TAILNET_DOMAIN}"
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
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
failSwapOn: false
systemReserved:
  cpu: 100m
  memory: 256Mi
  ephemeral-storage: 1Gi
kubeReserved:
  cpu: 100m
  memory: 256Mi
  ephemeral-storage: 1Gi
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
EOF
```

## 3. `kubeadm init`

```bash
sudo kubeadm init --config=/root/kubeadm-config.yaml --skip-phases=addon/kube-proxy --upload-certs
```

> `--skip-phases=addon/kube-proxy`: Cilium sẽ thay kube-proxy
> (`kubeProxyReplacement=true`). Nếu để kubeadm cài kube-proxy, sau đó
> phải `kubectl -n kube-system delete ds kube-proxy` và xóa cm — phiền.

Output sẽ có:
```
kubeadm join 100.64.10.1:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

LƯU lệnh này lại — sẽ paste vào worker.

## 4. Cấu hình kubeconfig cho user `debian`

Trên cp1:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get --raw=/healthz   # kỳ vọng: ok
kubectl get nodes            # cp1 NotReady (chưa có CNI)
```

Copy kubeconfig về admin laptop:
```bash
# trên admin laptop
mkdir -p ~/.kube
scp debian@cp1.${TAILNET_DOMAIN}:/home/debian/.kube/config ~/.kube/config-job7189
export KUBECONFIG=~/.kube/config-job7189
kubectl get nodes
```

## 5. Join 3 worker

Trên TỪNG worker (`w-data`, `w-apps`, `w-obs`):
```bash
WORKER_TS_IP="$(tailscale ip -4 | head -1)"

# Tạo kubeadm-join-config.yaml để force --node-ip Tailscale
cat <<EOF | sudo tee /root/kubeadm-join.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: "${WORKER_TS_IP}"
discovery:
  bootstrapToken:
    apiServerEndpoint: "<CP1_TS_IP>:6443"
    token: "<TOKEN_FROM_kubeadm_init>"
    caCertHashes:
      - "sha256:<HASH_FROM_kubeadm_init>"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
failSwapOn: false
systemReserved:
  cpu: 100m
  memory: 256Mi
kubeReserved:
  cpu: 100m
  memory: 256Mi
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
EOF

sudo kubeadm join --config=/root/kubeadm-join.yaml
```

Nếu token đã hết hạn (>24h), tạo lại trên cp1:
```bash
sudo kubeadm token create --print-join-command
```

## 6. Verify nodes joined

Trên admin laptop:
```bash
kubectl get nodes -o wide
```

Kỳ vọng:
```
NAME    STATUS     ROLES           AGE  VERSION  INTERNAL-IP
cp1     NotReady   control-plane   5m   v1.30.0  100.64.10.1
w-data  NotReady   <none>          1m   v1.30.0  100.64.10.2
w-apps  NotReady   <none>          1m   v1.30.0  100.64.10.3
w-obs   NotReady   <none>          1m   v1.30.0  100.64.10.4
```

`NotReady` là đúng — vì chưa có CNI. Sang `08-cilium-install.md`.

## 7. Label nodes theo tier

Sau khi tất cả Ready (sau khi cài Cilium):
```bash
kubectl label node cp1     zta.workload.tier=control-plane
kubectl label node w-data  zta.workload.tier=data
kubectl label node w-apps  zta.workload.tier=apps
kubectl label node w-obs   zta.workload.tier=observability
```

## 8. Taint cleanup

Mặc định cp1 có taint `node-role.kubernetes.io/control-plane:NoSchedule`.
**Giữ nguyên** — chỉ pod quan trọng (apiserver/etcd/scheduler/cilium-agent)
mới có toleration này.

Nếu sau này quá thiếu vCPU và bạn muốn cho phép pod nhẹ chạy ở cp1:
```bash
kubectl taint node cp1 node-role.kubernetes.io/control-plane:NoSchedule-
```
KHÔNG khuyến nghị — vì etcd cần I/O không bị nhiễu.

## 9. Test apiserver từ worker

Trên worker:
```bash
kubectl get nodes  # KHÔNG hoạt động vì worker không có kubeconfig
```

Đó là đúng — worker không có kubeconfig admin. Để debug từ worker:
```bash
sudo crictl ps | head -10   # kiểm tra kubelet/cilium-agent đang chạy
sudo journalctl -u kubelet -n 100 | grep -E 'error|warn' | tail -20
```

## 10. Backup kubeadm certs

Cert/key của apiserver/etcd nằm ở `/etc/kubernetes/pki/`. Backup ngay sau
init:
```bash
sudo tar czf /root/kubeadm-pki-backup-$(date +%F).tar.gz /etc/kubernetes/pki /etc/kubernetes/admin.conf
sudo chmod 600 /root/kubeadm-pki-backup-*.tar.gz
# scp về admin laptop
scp debian@cp1.${TAILNET_DOMAIN}:/root/kubeadm-pki-backup-*.tar.gz ~/cluster-backup/
```

Cần backup này nếu `cp1` chết và phải khôi phục từ snapshot etcd.

## 11. kubeadm reset (rollback)

Nếu init/join sai, reset clean:
```bash
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d /var/lib/cni
sudo iptables-save | grep -v KUBE | sudo iptables-restore
sudo ipvsadm --clear 2>/dev/null || true
sudo systemctl restart containerd
```

Rồi quay lại bước 2 (cp1) hoặc bước 5 (worker).
