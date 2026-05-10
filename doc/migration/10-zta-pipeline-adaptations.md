# 10. ZTA Pipeline Adaptations — sửa script nào, thay gì

> Mục tiêu: giữ tối đa logic cũ. Script `zta-rebuild.sh`, `02-…sh`, `03-…sh`,
> `05-…sh`, `07-…sh`, `08-…sh`, `09-verify-zta.sh`, `10-deploy-tetragon.sh`
> đều **GIỮ NGUYÊN**. Chỉ:
> 1. Đổi phase `01-cluster` từ `bash 01-setup-cluster.sh` (Kind) sang
>    pre-built kubeadm cluster (đã có sẵn từ `07-kubeadm-bootstrap.md`).
> 2. Patch một số nodeAffinity / nodeSelector trong manifest cho đúng tier.
> 3. Patch path/registry hostname.
> 4. Bypass `--kind` flag bất kỳ chỗ nào còn dùng.

## 1. `01-setup-cluster.sh` — chia làm 2 chế độ

### Đề xuất viết lại header để hỗ trợ cả Kind (cũ) + multi-VM (mới)

```bash
# Đầu file 01-setup-cluster.sh thêm flag:
ZTA_CLUSTER_MODE="${ZTA_CLUSTER_MODE:-kind}"   # kind | external

if [ "$ZTA_CLUSTER_MODE" = "external" ]; then
  echo "ZTA_CLUSTER_MODE=external — bỏ qua kind delete/create."
  echo "Verify cluster đã sẵn sàng:"
  kubectl cluster-info --request-timeout=10s
  kubectl get nodes -o wide
  # skip kind cleanup, kind create, registry mounting
  # giữ nguyên: cài Gateway API CRDs, Cilium (đã có rồi), cert-manager, ingress
  # Nhưng nếu các thứ này đã được cài bằng Helm trong 09-cluster-services-bringup.md
  # → chỉ cần verify thay vì re-install:
  echo "[external] Verify Cilium ready..."
  kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}'
  echo "[external] Verify cert-manager + ingress-nginx..."
  ...
  exit 0
else
  # Logic cũ (Kind): kind delete, kind create, helm install Cilium, ...
  ...
fi
```

### Hoặc: bỏ qua hoàn toàn `01-setup-cluster.sh` ở chế độ multi-VM

Trong `scripts/zta-rebuild.sh`, thêm `--external-cluster` flag để skip step
`01-cluster`. Logic:

```bash
# scripts/zta-rebuild.sh — thêm flag
EXTERNAL_CLUSTER=0
case "$arg" in
  --external-cluster) EXTERNAL_CLUSTER=1; SKIP_CLUSTER=1 ;;
  ...
esac

# Trong run_step loop:
if [ "$EXTERNAL_CLUSTER" -eq 1 ] && [ "$id" = "01-cluster" ]; then
  echo "  ⏭  external cluster mode — skipping 01-cluster"
  STEP_RESULTS["01-cluster"]="SKIPPED"
  continue
fi
```

→ Sau migration, lệnh chạy:
```bash
bash scripts/zta-rebuild.sh --external-cluster --yes
```

## 2. `02-deploy-infrastructure.sh` — patch nodeAffinity

Hầu hết workload đã có Service ClusterIP nên cross-node OK. Cần thêm
nodeAffinity cho:

| Workload | File | Patch nodeAffinity |
|----------|------|---------------------|
| MySQL | `infras/k8s-yaml/01-mysql-phpmyadmin.yaml` | `tier=data` |
| Vault prod + dev | `infras/k8s-yaml/11-vault.yaml` | `tier=data` |
| Vault agent injector | (helm chart) | (mọi node, MutatingWebhook) |
| Keycloak | `infras/k8s-yaml/02-keycloak.yaml` | `tier=data` |
| Kafka | `infras/k8s-yaml/03-kafka.yaml` | `tier=data` |
| Kong | `infras/k8s-yaml/04-kong-dbless.yaml` | `tier=apps` |
| oauth2-proxy | (manifest) | `tier=apps` |
| ELK + Prom + Grafana | `05-elasticsearch.yaml`, `08-prometheus.yaml`, `09-grafana.yaml` | `tier=observability` |
| In-cluster docker-registry | `12-docker-registry.yaml` | `tier=apps` |

Ví dụ patch StatefulSet MySQL:

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

Nếu không muốn sửa manifest gốc → tạo Kustomize overlay:

```
infras/k8s-yaml/multi-vm-overlay/
├── kustomization.yaml      # references file gốc + áp patch
├── mysql-affinity.yaml
├── vault-affinity.yaml
└── ...
```

```yaml
# infras/k8s-yaml/multi-vm-overlay/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../01-mysql-phpmyadmin.yaml
patches:
  - path: mysql-affinity.yaml
    target: { kind: StatefulSet, name: mysql }
```

`02-deploy-infrastructure.sh` đổi từ `kubectl apply -f infras/k8s-yaml/01-mysql-phpmyadmin.yaml`
→ `kubectl apply -k infras/k8s-yaml/multi-vm-overlay/`.

## 3. `03-deploy-microservices.sh` + Helmfile

Helmfile dùng chart `k8s-management/charts/laravel-app`. Patch
`k8s-management/values/laravel-common-values.yaml` thêm:

```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: zta.workload.tier
        operator: In
        values: ["apps"]
image:
  repository: w-apps.<tailnet>.ts.net:30005/job7189/<service>
  tag: dev
  pullPolicy: Always
```

`04-build-and-push-images.sh` đổi default registry:
```bash
REGISTRY_HOST=${1:-"w-apps.<tailnet>.ts.net:30005"}
```

Hoặc qua env var:
```bash
ZTA_REGISTRY_HOST="w-apps.<tailnet>.ts.net:30005" bash 04-build-and-push-images.sh
```

`03-deploy-microservices.sh` `configure_kind_registry_access` function
**không còn dùng** (Kind-specific) → guard với:
```bash
if [ "$ZTA_CLUSTER_MODE" = "external" ]; then
  echo "External cluster — containerd hosts.toml đã được cấu hình thủ công."
  echo "(xem doc/migration/05-storage-and-registry.md §4)"
else
  configure_kind_registry_access "$REGISTRY_HOST"
fi
```

## 4. `05-seed-databases.sh`

Không cần sửa gì — script này chỉ `kubectl exec` vào MySQL pod. Cross-node
OK (Service DNS resolve qua kube-dns). Verify lần đầu:
```bash
kubectl -n data exec -it mysql-0 -- mysql -uroot -p$(...) -e "SHOW DATABASES;"
```

## 5. `07-deploy-monitoring-exporters.sh`

`node-exporter` là DaemonSet → tự chạy trên 4 node. `kube-state-metrics`
1 replica → patch nodeAffinity `tier=observability`.

```bash
# trong helm install kube-state-metrics:
--set affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=zta.workload.tier \
--set affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=In \
--set affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]=observability
```

## 6. `08-harden-security.sh` — TẮT WireGuard

Đây là điểm thay đổi LỚN NHẤT:

```bash
# Multi-VM setup: Tailscale đã encrypt L3, BẬT WireGuard ở Cilium = double encrypt
# → CHỈ enable mesh-auth (mTLS L7), KHÔNG enable WireGuard
ZTA_HARDEN_WIREGUARD=0 bash 08-harden-security.sh
```

Script đã có flag này (xem `08-harden-security.sh` line 24:
`ZTA_HARDEN_WIREGUARD="${ZTA_HARDEN_WIREGUARD:-1}"`). Chỉ cần đảm bảo
zta-rebuild.sh truyền flag đúng:

```bash
# scripts/zta-rebuild.sh STEPS array — đổi:
"08-harden|Enable Cilium mesh-auth + apply CNPs + workload labels + L7|do_harden_full"
# function do_harden_full nội bộ chạy 08-harden-security.sh nhưng với
# ZTA_HARDEN_WIREGUARD=0 khi external cluster
do_harden_full() {
  if [ "$EXTERNAL_CLUSTER" = "1" ]; then
    ZTA_HARDEN_WIREGUARD=0 bash 08-harden-security.sh
  else
    bash 08-harden-security.sh
  fi
  ...
}
```

Doc `doc/15-encryption-mtls-spiffe.md` cần thêm chú thích:

> **Trên multi-VM Tailscale**: Tailscale đã cung cấp WireGuard encryption
> ở L3 underlay. Bật Cilium `enable-wireguard=true` sẽ encrypt 2 lần
> (Tailscale ngoài + Cilium trong). Trong PoC này, mặc định
> `ZTA_HARDEN_WIREGUARD=0` cho external cluster — mesh-auth (mTLS L7) vẫn
> bật để phục vụ thesis SPIFFE/mTLS evidence.

## 7. `09-verify-zta.sh` Test 5 (encryption status)

Test 5 hiện kiểm tra:
- Cilium mesh-auth enabled
- Cilium WireGuard enabled

Trong external mode, Test 5b (WireGuard) sẽ fail (đúng — vì mình tắt).
Patch:

```bash
# 09-verify-zta.sh function test_5_encryption()
if [ "${ZTA_CLUSTER_MODE:-kind}" = "external" ]; then
  echo "  ℹ  External cluster: WireGuard handled by Tailscale L3 underlay (skipping)."
  return 0
fi
# logic kiểm tra Cilium WG cũ
```

Hoặc thêm Test 5c mới: verify Tailscale up trên mọi node (cần SSH key):
```bash
for node in cp1 w-data w-apps w-obs; do
  ssh debian@$node.<tailnet>.ts.net 'tailscale status | head -1' || echo "  WARN: $node Tailscale not reachable"
done
```

## 8. `10-deploy-tetragon.sh`

Tetragon cần CO-RE eBPF — Debian 12 kernel 6.1 OK. Cần verify sau install:
```bash
kubectl -n kube-system get ds tetragon
# Kỳ vọng: 4/4 Ready (1 pod mỗi node — bao gồm cả cp1 vì Tetragon
# có toleration NoSchedule control-plane).
```

Pre-flight RAM trong script (`require_node_ram_mi 200`) đã có. Sau migration
4 node, 200 Mi/node thoải mái (cp1 1.7 Gi req trên 2 GiB không kẹt).

## 9. SPIRE (`scripts/zta-deploy-spire.sh`)

Pre-flight RAM trong script: `SPIRE_REQUIRED_NODE_MI=450`. Sau migration:
- cp1 có ~300 Mi free (kẹt — bypass `ZTA_RAM_CHECK_FATAL=0` hoặc
  bump cp1 lên 2.5 GB)
- w-data ~1.6 Gi free → OK
- w-apps ~2.1 Gi free → OK
- w-obs ~2.7 Gi free → OK (chính là VM nó được pin vào)

Đề xuất: pin SPIRE server StatefulSet vào `w-obs`:
```yaml
# infras/k8s-yaml/spire/values.yaml — thêm:
server:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: zta.workload.tier
            operator: In
            values: ["observability"]
```

SPIRE agent (DS) chạy trên mọi node (mặc định DS) — đúng yêu cầu để mỗi
workload trên mỗi node nhận SVID.

## 10. Gatekeeper (`scripts/zta-deploy-gatekeeper.sh`)

Tương tự SPIRE: pin controller-manager + audit vào `w-obs`. Pre-flight
RAM `MIN_FREE_MIB=1500` áp dụng cho **host** (không phải node). Trên
multi-VM, host ở đây là VM mà controller chạy → w-obs có 6 GB tổng,
free ~3 Gi → pass.

## 11. PDP Controller (`scripts/zta-deploy-pdp.sh`)

PDP chạy 1 replica trong namespace `security`. Pin:
```yaml
nodeAffinity: tier=observability
```
PDP cần list/get pod toàn cluster → cần RBAC ClusterRole (đã có).

## 12. Hubble Export (`scripts/zta-deploy-hubble-export.sh`)

Filebeat shipper (deployment 1 replica) chạy ở `w-obs`. cilium DS
hubble-export-file ghi flow log local trên mọi node (DS).

## 13. Zta-rebuild.sh — thay đổi tổng kết

Diff conceptual:

```diff
@@ scripts/zta-rebuild.sh @@
+EXTERNAL_CLUSTER=0
+for arg in "$@"; do
+  case "$arg" in
+    --external-cluster) EXTERNAL_CLUSTER=1; SKIP_CLUSTER=1 ;;
+    ...
+  esac
+done
+export EXTERNAL_CLUSTER

 STEPS=(
-  "01-cluster|Setup Kind cluster + Cilium + cert-manager + ingress + metrics-server|bash 01-setup-cluster.sh"
+  "01-cluster|Setup Kind cluster (skipped if --external-cluster)|do_cluster_setup"
   "02-infra|Deploy Vault + Keycloak + ...|bash 02-deploy-infrastructure.sh"
   ...
 )

+do_cluster_setup() {
+  if [ "$EXTERNAL_CLUSTER" = "1" ]; then
+    echo "External cluster mode — verify only, no install."
+    kubectl cluster-info --request-timeout=10s
+    kubectl get nodes
+    kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}'
+    return 0
+  fi
+  bash 01-setup-cluster.sh
+}
```

## 14. Bảng tóm tắt thay đổi

| File | Loại thay đổi | Lý do |
|------|---------------|-------|
| `01-setup-cluster.sh` | Add `ZTA_CLUSTER_MODE=external` branch | Skip kind delete/create |
| `04-build-and-push-images.sh` | Default registry → Tailscale hostname | Cross-host pull |
| `03-deploy-microservices.sh` | Skip `configure_kind_registry_access` if external | Containerd config thủ công |
| `08-harden-security.sh` | Doc + default `ZTA_HARDEN_WIREGUARD=0` if external | Tránh double-encrypt |
| `09-verify-zta.sh` | Test 5b skip nếu external + add Test 5c (Tailscale) | Reflect new posture |
| `infras/k8s-yaml/*.yaml` | Add nodeAffinity hoặc Kustomize overlay | Pin pod vào tier |
| `k8s-management/values/laravel-common-values.yaml` | Add nodeAffinity + registry | Pod scheduling + image |
| `scripts/zta-rebuild.sh` | Add `--external-cluster` flag | Skip step `01-cluster` |
| `infras/k8s-yaml/spire/values.yaml` | Add nodeAffinity cho server | Pin SPIRE server vào w-obs |

## 15. Ngoài phạm vi PR plan này

Các script sửa nêu trên là **plan**, sẽ commit ở PR riêng sau khi user duyệt
plan. PR này chỉ chứa `doc/migration/*.md`, KHÔNG đụng `scripts/`,
`infras/`, `01-…sh`, `02-…sh`, etc.
