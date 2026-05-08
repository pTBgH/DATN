# 32. Deploy Script Troubleshooting

Tài liệu này hệ thống hoá các lỗi đã gặp khi chạy `scripts/zta-deploy-*.sh`
+ recovery flow chuẩn cho từng module nặng. Đọc cùng `23-rebuild-from-scratch.md`.

---

## 1. Common helpers — `scripts/utils/zta-common.sh`

3 hàm/utility được mọi script `zta-deploy-*` source và dùng:

| Hàm | Tác dụng |
|-----|----------|
| `wait_for_dns <host>` | Chờ DNS resolve được host trước khi `helm repo add`. Tránh fail giả khi systemd-resolved chưa ready. Override: `ZTA_DNS_WAIT_TIMEOUT`. |
| `helm_repo_update_retry <repo>` | Retry `helm repo update` 5 lần với backoff. Tránh fail giả khi mirror chưa ready. Override: `ZTA_HELM_REPO_UPDATE_RETRIES`, `ZTA_HELM_REPO_UPDATE_BACKOFF`. |
| `require_node_ram_mi <mi> <component>` | Pre-flight check **per Kind node** (cgroup): refuse install nếu node nào có `<mi>` MB free RAM. Skip nếu metrics-server chưa cài. Bypass: `ZTA_RAM_CHECK_FATAL=0`. |
| `require_host_ram_mi <mi> <component>` | Pre-flight check **host VM** (`free -m` cột `available`): refuse install nếu host có `<mi>` MB available. Bắt được pressure mà `kubectl top node` bỏ sót (Kind dùng chung kernel với host). Bypass: `ZTA_HOST_RAM_CHECK_FATAL=0`. |

Mọi script helm-based dùng `--cleanup-on-fail` để failed install không để
lại orphan workload chặn re-run.

---

## 2. SPIRE — `scripts/zta-deploy-spire.sh`

### 2.1 Flags

| Flag | Tác dụng |
|------|----------|
| (default) | Install/upgrade theo `infras/k8s-yaml/spire/values.yaml` |
| `--reset` | Force-uninstall trước rồi install lại fresh (dùng khi release deployed nhưng pod broken) |
| `--uninstall` | Xoá toàn bộ: helm release + ClusterSPIFFEID + orphan pods + PVC + helm hook jobs + namespace |
| `--crds-only` | Chỉ apply `infras/k8s-yaml/spire/cluster-spiffe-ids.yaml` (re-apply CRDs sau khi sửa) |

Env override: `SPIRE_HELM_TIMEOUT=900s`, `SPIRE_REQUIRED_NODE_MI=450`.

### 2.2 Triệu chứng & nguyên nhân hay gặp

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| `pre-upgrade hooks failed: Job/spire/spire-server-pre-upgrade not ready. status: Failed. failed: 7/1` | Helm release `spire` ở trạng thái `deployed` nhưng `spire-server-0` thực ra đang `1/2 CrashLoop`. Pre-upgrade hook không pass được vì server chết → helm refuse re-run failed Job. | `bash scripts/zta-deploy-spire.sh --reset` (script tự detect "deployed-but-broken" + xoá hook job + force reinstall). |
| `helm install` timeout `Available: 0/4`, `Replicas: 0/1`, `context deadline exceeded` | Pod cũ orphan chưa terminate (helm uninstall đôi khi không xoá CrashLoop pod) hoặc PVC cũ data corrupt. | `bash scripts/zta-deploy-spire.sh --uninstall && bash scripts/zta-deploy-spire.sh`. `--uninstall` mới đã force-delete toàn bộ pod + PVC + hook job. |
| `spire-server-0  0/2  Error  24` (24+ restarts trên fresh install) | spire-controller-manager OOM khi reconcile 11+ ClusterSPIFFEID, hoặc PVC cũ trust-store hỏng. | Đã được handle: `values.yaml` bump controller-manager limit 192Mi → 256Mi + nới probe (initialDelay 30/10 → 60/20s). Nếu vẫn fail: `--uninstall && deploy lại`. |
| `failed to lookup pod sandbox… csi.spiffe.io` trong workload pod (PR #20 demo) | spiffe-csi-driver chưa Ready trên node đó (DS không lan đủ 4 node), hoặc kubelet plugin dir bị lock. | `kubectl -n spire get ds spiffe-csi-driver` confirm Ready 4/4. Nếu không: force restart `kubectl -n spire rollout restart ds/spiffe-csi-driver`. |
| Pre-flight: `at least one node has insufficient free RAM for spire` | Cluster RAM ≤450Mi/node free. | `bash scripts/free-ram-for-tetragon.sh` (giải phóng ~600Mi). Hoặc bypass: `ZTA_RAM_CHECK_FATAL=0 bash scripts/zta-deploy-spire.sh`. |

### 2.3 Recovery flow chuẩn

```bash
# Cấp 1: tự script tự recover (deployed-but-broken state)
bash scripts/zta-deploy-spire.sh --reset

# Cấp 2: full reinstall (orphan pod / PVC corrupt)
bash scripts/zta-deploy-spire.sh --uninstall
bash scripts/zta-deploy-spire.sh

# Cấp 3: nuke ns spire bằng tay rồi re-install (chỉ khi cấp 2 fail)
helm uninstall spire -n spire 2>/dev/null
helm uninstall spire-crds -n spire 2>/dev/null
kubectl -n spire delete pod --all --grace-period=0 --force --ignore-not-found
kubectl -n spire delete pvc --all --ignore-not-found
kubectl -n spire delete job --all --ignore-not-found
kubectl delete ns spire --ignore-not-found
bash scripts/zta-deploy-spire.sh

# Verify
bash 09-verify-zta.sh | grep "Test 4i" -A 12
```

### 2.4 Logic auto-recovery trong script

`scripts/zta-deploy-spire.sh` set `NEEDS_RESET=1` và tự uninstall + delete
PVC + force-delete pod + sleep 5s khi GẶP ÍT NHẤT MỘT trong:

1. User gọi với `--reset`
2. Helm release status ∈ `{failed, pending-install, pending-upgrade, uninstalling}`
3. Helm release status = `deployed` nhưng `StatefulSet/spire-server` không có `readyReplicas == replicas`

Trước khi quyết, script luôn xoá stale hook job (`spire-server-pre-upgrade`,
`spire-agent-pre-upgrade`) — helm refuse re-run hook job đã fail trước đó.

---

## 3. policy-controller — `scripts/zta-deploy-policy-controller.sh`

### 3.1 Flags

| Flag | Tác dụng |
|------|----------|
| (default) | Install/upgrade chart `sigstore/policy-controller` |
| `--reset` | Force-uninstall trước rồi install lại fresh |
| `--uninstall` | Xoá: helm release + ClusterImagePolicy + namespace label + cluster-scoped webhook configs + orphan pods + namespace |
| `--policies-only` | Chỉ patch + apply ClusterImagePolicy (re-apply CIP sau khi sửa cosign key, không re-install chart) |

Env override: `POLICY_CONTROLLER_HELM_TIMEOUT=600s`, `PC_REQUIRED_NODE_MI=200`.

### 3.2 Triệu chứng & nguyên nhân hay gặp

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| `conflict with "webhook" using admissionregistration.k8s.io/v1: .webhooks[name="policy.sigstore.dev"].namespaceSelector` | Webhook pod đang chạy SSA-update field `.namespaceSelector` của chính `{Validating,Mutating}WebhookConfiguration` của nó, fight với helm apply ở upgrade. | `bash scripts/zta-deploy-policy-controller.sh --reset` (script detect webhook unhealthy → xoá `policy.sigstore.dev` webhook configs cluster-scoped → reinstall). |
| Helm install timeout, webhook pod CrashLoop với restartCount cao | Webhook cert chưa generate kịp (cert-manager chưa Ready), hoặc image pull rate-limit ghcr.io. | `kubectl -n cosign-system describe pod -l control-plane=policy-controller-webhook` xem error chính xác. Nếu image-pull: đợi rate-limit clear (~1h) hoặc dùng kind load image. |
| `kubectl get clusterimagepolicy` rỗng sau install | Chart không tự apply CIP — chỉ tạo CRD. CIP nằm ở `infras/k8s-yaml/policy-controller/cluster-image-policies.yaml`. | `bash scripts/zta-deploy-policy-controller.sh --policies-only` để apply CIP riêng. |

### 3.3 Recovery flow chuẩn

```bash
# Cấp 1: auto-recover deployed-but-broken (webhook CrashLoop ≥5 restarts)
bash scripts/zta-deploy-policy-controller.sh --reset

# Cấp 2: full reinstall
bash scripts/zta-deploy-policy-controller.sh --uninstall
bash scripts/zta-deploy-policy-controller.sh

# Cấp 3: nuke bằng tay
helm uninstall policy-controller -n cosign-system 2>/dev/null
kubectl delete validatingwebhookconfiguration policy.sigstore.dev --ignore-not-found
kubectl delete mutatingwebhookconfiguration   policy.sigstore.dev --ignore-not-found
kubectl delete ns cosign-system --ignore-not-found
bash scripts/zta-deploy-policy-controller.sh

# Verify
bash 09-verify-zta.sh | grep "Test 4j" -A 12
```

### 3.4 Logic auto-recovery trong script

`PC_NEEDS_RESET=1` khi GẶP ÍT NHẤT MỘT trong:

1. `--reset` flag
2. Helm release status ∈ `{failed, pending-install, pending-upgrade, uninstalling}`
3. Helm release status = `deployed` nhưng webhook pod có `restartCount ≥ 5`

Khi reset: helm uninstall + delete `policy.sigstore.dev`
{Validating,Mutating}WebhookConfiguration cluster-scoped + force-delete
webhook pod + sleep 5s.

---

## 4. Falco (DEPRECATED — đã gỡ khỏi repo)

Falco runtime detection đã được loại bỏ hoàn toàn khỏi pipeline ZTA và repo
này từ PR-D cleanup (2026-05). Tetragon (`10-deploy-tetragon.sh`) phủ tất cả
runtime use-cases. Xem `doc/31-falco-deprecated.md` +
`doc/incident-falco-tetragon-ram-overcommit.md`.

---

## 5. Hubble flow export — `scripts/zta-deploy-hubble-export.sh`

### 5.1 Flags

| Flag | Tác dụng |
|------|----------|
| (default) | Chỉ deploy filebeat shipper. **KHÔNG** patch cilium-config. AN TOÀN — không restart cilium. |
| `--enable-cilium-export` | Patch cilium-config + rolling restart cilium DS để bật `hubble-export-file`. **RỦI RO**: 5-10 phút network blip; script tự revert config nếu rollout fail. |
| `--uninstall` | Xoá filebeat DS + revert cilium-config. |

### 5.2 Triệu chứng & nguyên nhân hay gặp

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| Cilium DS rolling restart timeout, control-plane CrashLoop cascade | Cilium agents restart song song trên 4 node Kind → control-plane bị starve khi không node nào pass health check. | Đã fix: rollout với `--max-unavailable=1`, timeout 600s, auto-revert config. Nếu vẫn cascade: `kubectl -n kube-system patch cm cilium-config --type=json -p '[{"op":"remove","path":"/data/hubble-export-file-path"}]'` rồi `rollout restart ds/cilium`. |
| `hubble-flow-shipper-XXX  ContainerCreating` mãi không Ready | hostPath `/var/run/cilium/hubble/events.log` chưa tồn tại (cilium-export chưa bật). | Chạy `--enable-cilium-export` để cilium tạo file, hoặc xoá filebeat DS nếu không cần ship flow. |
| Filebeat ship vào ES nhưng `cilium-flows-*` index không có doc | Cilium hubble-export-file format JSON nhưng filebeat parser kỳ vọng từng dòng = 1 JSON object. Nếu cilium config có sai format → filebeat drop dòng. | `kubectl -n kube-system exec ds/cilium -- head /var/run/cilium/hubble/events.log` confirm format. |

---

## 6. SPIRE workload demo — `scripts/zta-spire-onboard-demo.sh`

### 6.1 Mục đích

PR #20: deploy 1 pod `security/spire-demo-workload` mount `csi.spiffe.io`,
chạy `spiffe-helper` daemon, write SVID PEM vào `/svids/`.

### 6.2 Triệu chứng & nguyên nhân hay gặp

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| `spire-demo-workload  CrashLoopBackOff`, image `ghcr.io/spiffe/spire-agent` | Image distroless không có `/bin/sh` → `command: [/bin/sh, -c]` fail. **Đã sửa ở PR #20 commit `b4eb176`**. | Confirm manifest dùng `ghcr.io/spiffe/spiffe-helper:0.8.0`, không phải `spire-agent`. |
| Pod Ready nhưng `/svids/svid.crt` không xuất hiện | Workload chưa được attest — ClusterSPIFFEID chưa register hoặc selector không match. | `kubectl -n spire logs deploy/spire-spire-controller-manager --tail=20`; `kubectl get clusterspiffeid zta-spire-demo-workload -o yaml` confirm `podSelector` match label `app=spire-demo-workload`. |
| `error registering selector: spiffeid is invalid` | Trust domain mismatch (clusterName) | Cluster name phải match `global.spire.clusterName` trong `infras/k8s-yaml/spire/values.yaml` (default `kind-job7189`). |

---

## 7. Pre-flight RAM check — global (2 layers)

Có 2 layer pre-flight, kiểm tra **2 trục pressure khác nhau**:

| Layer | Check | Lý do |
|-------|-------|-------|
| **Host VM** (`require_host_ram_mi`) | `free -m` cột `available` >= ngưỡng (1500-2000Mi tuỳ component) | Kind node share host kernel. Khi host RAM <2Gi → kube-apiserver lease (5s timeout) miss → kube-scheduler / kube-controller-manager / cilium-operator / spire-controller-manager flap leader-election cascade |
| **Per-node** (`require_node_ram_mi`) | `kubectl top node` per Kind node >= ngưỡng (200-450Mi tuỳ component) | Pod-level scheduling — nếu node cgroup hết RAM, pod sẽ Pending hoặc OOM-killed |

Host check chạy **trước** node check. Cả 2 đều có thể bypass riêng lẻ.

### 7.1 Host RAM check fail

```text
[pre-flight] spire wants >=1500Mi available on HOST VM
             host has only 1198Mi available right now
             (Kind nodes share host kernel — apiserver will flap if host is squeezed)
             free more RAM first, e.g.:
               bash scripts/free-ram-for-tetragon.sh
             (set ZTA_HOST_RAM_CHECK_FATAL=0 to bypass)
```

Đây là ngưỡng **bảo vệ control-plane**, không phải pod scheduling. Host RAM dưới ngưỡng nghĩa là kube-apiserver sẽ lag nhịp etcd/lease và toàn bộ control-plane flap.

### 7.2 Node RAM check fail

```text
[pre-flight] spire wants >=450Mi free per node
             worst node kind-job7189-worker3 has only 312Mi free
             free more RAM first, e.g.:
               bash scripts/free-ram-for-tetragon.sh
             (set ZTA_RAM_CHECK_FATAL=0 to bypass)
```

### 7.3 Tùy chọn

```bash
# A) Free RAM rồi retry (recommended)
bash scripts/free-ram-for-tetragon.sh
bash scripts/zta-deploy-spire.sh

# B) Bypass HOST check (nếu chắc chắn cluster nhỏ ổn định, ví dụ test)
ZTA_HOST_RAM_CHECK_FATAL=0 bash scripts/zta-deploy-spire.sh

# C) Bypass NODE check (metrics-server chưa cài / số liệu sai)
ZTA_RAM_CHECK_FATAL=0 bash scripts/zta-deploy-spire.sh

# D) Hạ ngưỡng host (cluster nhỏ hơn nhưng vẫn muốn thử)
SPIRE_REQUIRED_HOST_MI=900 bash scripts/zta-deploy-spire.sh

# E) Hạ ngưỡng node
SPIRE_REQUIRED_NODE_MI=200 bash scripts/zta-deploy-spire.sh
```

Khi metrics-server chưa cài, node check chỉ in warning rồi tiếp tục — không
block. Host check luôn chạy được vì chỉ phụ thuộc `free -m` (có sẵn trên Linux).

### 7.4 Default thresholds (host)

| Script | Ngưỡng default | Override env |
|--------|----------------|---------------|
| `zta-deploy-spire.sh` | 1500Mi | `SPIRE_REQUIRED_HOST_MI` |
| `zta-deploy-policy-controller.sh` | 1200Mi | `PC_REQUIRED_HOST_MI` |
| `zta-rebuild.sh --full-enforcement` | 2000Mi (gate trước heavy phase) | `REBUILD_FULL_REQUIRED_HOST_MI` |
| `10-deploy-tetragon.sh` | 900Mi (auto-runs `free-ram-for-tetragon.sh` nếu thiếu) | `TETRAGON_RAM_TARGET_MI` |

### 7.5 Triệu chứng host RAM exhaustion bị skip pre-flight

Nếu bạn bypass cả 2 check + force install, các triệu chứng cascade sau ~30-60 phút:

```text
kube-scheduler:        Failed to update lease optimistically ... context deadline exceeded
spire-controller-mgr:  leader election lost  (cùng timestamp)
cilium-operator:       Readiness probe failed: 127.0.0.1:9234: read tcp ... read: connection reset by peer
hubble-relay:          0/1 Running, restarts cao
policy-controller-webhook: 0/1 Running, restarts cao
kube-controller-manager: 0/1 Running, restarts cao
```

Tất cả 1 sự kiện: kube-apiserver bị block ≥5s do swap-thrash. Fix: free RAM rồi
delete pods để clean restart (xem § 8).

---

## 8. Cluster-level recovery sau cascade fail

Nếu nhiều thành phần CrashLoop đồng thời (cilium-operator +
kube-controller-manager + kube-scheduler + spire-controller-manager +
policy-controller-webhook + hubble-relay), thứ tự recover:

```bash
# 1. Check tổng quan
free -m
kubectl get pod -A --no-headers | grep -vE 'Running|Completed' | head -30

# 2. Confirm root cause là host RAM
#    (nếu free -m available <1500Mi → 99% là RAM cascade)
free -m | awk '/^Mem:/ {print "available:", $7, "Mi"}'

# 3. Free RAM (giải phóng ~600Mi từ phpmyadmin/grafana/kibana; kafbat removed)
bash scripts/free-ram-for-tetragon.sh

# 4. (Optional) Revert cilium-config patch nếu là nguyên nhân
kubectl -n kube-system patch cm cilium-config --type=json -p '[
  {"op":"remove","path":"/data/hubble-export-file-path"},
  {"op":"remove","path":"/data/hubble-export-file-max-size-mb"},
  {"op":"remove","path":"/data/hubble-export-file-max-backups"}
]' 2>/dev/null || true
kubectl -n kube-system rollout restart ds/cilium

# 5. Đợi apiserver + scheduler stable (2-5 phút)
sleep 180
kubectl get pod -n kube-system | grep -E "scheduler|controller-manager|cilium-operator"

# 6. Force-restart các pod đã CrashLoop để clean state
kubectl -n spire delete pod spire-server-0
kubectl -n kube-system delete pod -l name=cilium-operator
kubectl -n cosign-system delete pod -l app.kubernetes.io/name=policy-controller
kubectl -n kube-system delete pod -l k8s-app=hubble-relay

# 7. Đợi 5-10 phút cho cluster fully recover
sleep 300
kubectl get pod -A --no-headers | grep -vE 'Running|Completed' | head -30

# 8. Nếu vẫn cascade → teardown + rebuild
bash scripts/zta-teardown.sh --yes
bash scripts/zta-rebuild.sh --yes
```

Recovery này **không thay đổi config** — chỉ giải phóng RAM rồi clean restart.
Lý do hợp lý vì root cause là pressure tạm thời (apiserver lease miss), không
phải cấu hình sai.

---

## 9. Maintenance checklist khi viết deploy script mới

Mọi script `scripts/zta-deploy-<feature>.sh` mới PHẢI:

1. `source` `scripts/utils/zta-common.sh` ngay sau set của trap.
2. Step 0: `require_host_ram_mi <mi> <feature>` (1200-1800Mi) **rồi** `require_node_ram_mi <mi> <feature>` (200-450Mi). Host check trước vì nó bảo vệ control-plane; node check thứ hai vì nó bảo vệ pod scheduling.
3. Helm install: `--cleanup-on-fail` mặc định, `--atomic` nếu chart đủ stable.
4. Có flag `--uninstall` xoá: helm release + namespace + cluster-scoped resources (webhook, CRD nếu chart manage) + orphan pod (`--grace-period=0 --force`).
5. Có flag `--reset` cho release "deployed-but-broken" detection (nếu chart có pre-upgrade hook hoặc SSA conflict thường gặp).
6. Detect 3 trạng thái khi release đã tồn tại:
   - `failed | pending-* | uninstalling` → `NEEDS_RESET=1`
   - `deployed` + workload unhealthy (ready replicas mismatch / restart count > N) → `NEEDS_RESET=1`
   - `deployed` + healthy → upgrade bình thường
7. Update `09-verify-zta.sh` thêm Test 4x kiểm 5 PASS criteria.
8. Document trong file này (mục riêng) + `23-rebuild-from-scratch.md` (table phase + recovery row).
