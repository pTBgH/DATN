# Danh sách công việc cần làm tiếp theo

**Cập nhật lần cuối:** 2026-06-12  
**Trạng thái hệ thống:** Keycloak ✅ fixed | App pods ✅ 5/5 Running | Cilium policies ✅ áp dụng

---

## 🔴 Ưu tiên cao — cần làm trước

### 1. ~~Migrate legacy namespace label trong CNP~~ — KHÔNG CẦN LÀM ✅
**Phân tích (2026-06-12):** Đã kiểm tra thực tế. Cilium tự gán **cả hai label format** lên mỗi endpoint identity đồng thời:
```
k8s:io.kubernetes.pod.namespace=ingress-nginx                            ← cũ, vẫn hoạt động
k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name=ingress-nginx  ← mới
```
→ 169 CNP dùng label cũ vẫn **match đúng và enforce bình thường**. Không có CNP nào bị `INVALID` do label này.

**Root cause của các lỗi trước** (identity-service/ingress-nginx timeout) là **L7 Envoy loopback trên cùng node**, không liên quan đến format label.

> [!NOTE]
> Nếu muốn migrate sang label mới để future-proof, đó là việc tùy chọn (optional cleanup), không phải urgent. Chỉ migrate khi có thời gian rảnh.

---

### 2. PDP Controller — Đã chạy trong namespace `security` ✅
**Vấn đề:** Tài liệu gốc kỳ vọng PDP chạy trong namespace `pdp-system`, tuy nhiên cấu hình thực tế trong manifests (`infras/k8s-yaml/pdp/`) và script deploy (`scripts/zta-deploy-pdp.sh`) được chỉ định chạy trong namespace `security`. Đây là thiết kế hợp lệ và đã hoạt động ổn định.

**Kết quả (2026-06-12):**
- [x] Xác nhận PDP Controller đang chạy ổn định trong namespace `security` (`zta-pdp-...`).
- [x] Đã kiểm tra nhãn score-bucket được gán động thành công cho tất cả các application pods trong namespace `job7189-apps`.
- [x] Sửa lỗi kiểm thử metrics trong `09-verify-zta.sh` (chuyển sang dùng python3 thay vì `wget` do container minimal không có wget). Hiện tại kiểm thử metrics trả về kết quả `PASS` sạch sẽ.

**Tham khảo:** [`45-upgrade-and-rollback-plan.md § Tier 4`](./45-upgrade-and-rollback-plan.md)

---

### 3. Trivy Operator — Hoàn tất cấu hình và khắc phục OOM/Quét tràn lan ✅
**Vấn đề:** `trivy-operator` đang chạy trong namespace `security-cdm`. Cần xác định tính hợp lý và khắc phục lỗi `OOMKilled` cũng như lỗi quét toàn bộ cụm.
**Kết quả (2026-06-12):**
- [x] Xác nhận: `security-cdm` là namespace chuẩn theo Gap Decision của mô hình ZTA (tách biệt CDM quét ảnh với IAM của `security`).
- [x] Đã giới hạn `targetNamespaces` ở cấp root level của Helm values file ([01-values.yaml](file:///home/ptb/projects/DATN/infras/k8s-yaml/trivy-operator/01-values.yaml)) thay vì đặt nhầm dưới `operator`. Giúp operator chỉ quét 6 namespace được khoanh vùng, loại bỏ hoàn toàn việc quét tràn lan `kube-system`/`monitoring` hệ thống.
- [x] Tắt `configAuditScanner` do lỗi parsing built-in OCI yaml specs dưới dạng Rego của phiên bản cũ. PDP controller chỉ dùng `VulnerabilityReport` nên tính năng này là không cần thiết, tiết kiệm CPU/RAM.
- [x] Nâng limits memory của container scan từ `500Mi` lên `800Mi` trong `01-values.yaml` để tránh lỗi `OOMKilled` khi download/tải Trivy DB. Quá trình quét hiện tại diễn ra ổn định và mượt mà.

---

## 🟡 Ưu tiên trung bình

### 4. ~~Đo latency end-to-end baseline vs enforced~~ — BỎ QUA / ARCHIVED ❌
**Phân tích (2026-06-12):** Không cần đo latency nữa theo yêu cầu của user. Đã lưu trữ tác vụ này xuống phần cuối tài liệu.

---

### 5. Fix oauth2-proxy Cilium policy — label cũ ✅
**Vấn đề:** `allow-oauth2-proxy-ingress` và `allow-oauth2-proxy-egress` trong `12-security.yaml` vẫn dùng `k8s:io.kubernetes.pod.namespace` (dạng cũ).

**Kết quả (2026-06-12):**
- [x] Sửa [12-security.yaml](file:///home/ptb/projects/DATN/infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml) lines 126, 146, 155, 165, 173 sang định dạng label mới: `k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name`.
- [x] Đã apply thành công: `kubectl apply -f infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml`
- [x] Test oauth2-proxy phản hồi nhanh với HTTP 403 (không bị Cilium drop/timeout), chứng minh kết nối thông suốt từ Nginx Ingress.

---

### 6. Hoàn thiện Cilium policy cho các namespace còn thiếu ✅
**Vấn đề:** Cần đảm bảo tất cả các phân vùng của hệ thống đều được áp dụng chính sách eBPF Network Policy bảo vệ.

**Kết quả (2026-06-12):**
- [x] Đã áp dụng bộ chính sách bảo mật vi phân vùng [15-management.yaml](file:///home/ptb/projects/DATN/infras/k8s-yaml/cilium-policies/namespaces/15-management.yaml) cho namespace `management`.
- [x] Xác nhận toàn bộ 7 ZTA namespaces (`data`, `monitoring`, `vault`, `security`, `job7189-apps`, `gateway`, `management`) đều đã được bảo vệ đầy đủ bằng chính sách eBPF mặc định (default-deny) và cho phép có chọn lọc.

---

### 7. Verify SPIRE workload attestation end-to-end
**Vấn đề:** SPIRE server + agents đang Running, nhưng chưa verify các workload thực sự lấy được SVID certificate.

**Việc cần làm:**
- [ ] Check SVID issuance: `kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show`
- [ ] Verify từ app pod: `kubectl exec -n job7189-apps deployment/identity-service -c app -- ls /run/spiffe/`
- [ ] Nếu cert không mount được → kiểm tra `spiffe-csi-driver` và SPIRE agent registration

---

## 🟢 Ưu tiên thấp — polish & documentation

### 8. chapter4.tex — cập nhật số liệu Phase 5.D/5.E/5.F
**Việc cần làm:**
- [ ] §3.3: Confirm Tetragon caveat footnote (kernel BPF incompatibility, v1.7.0 fix) — xem `37-phase5d-followup-todo.md § G`
- [ ] §5.2: Thêm số liệu latency mới sau khi Item J hoàn thành
- [ ] §7 Limitations: Review và cập nhật các row theo trạng thái thực tế 2026-06-12
- [ ] Commit và push lên origin

### 9. Chuẩn bị evidence cho bảo vệ luận văn
**Việc cần làm:**
- [ ] Chụp Hubble UI showing live flows với policy enforcement
- [ ] Screenshot Keycloak OIDC flow hoạt động đầu-cuối (login → token → API)
- [ ] Export `kubectl get cnp -A` — tổng hợp toàn bộ policies đang enforce
- [ ] Screenshot Tetragon Sigkill working (v1.7.0)
- [ ] Gatekeeper admission denial example

### 10. Cleanup duplicate ingress
**Vấn đề:** `security` namespace có 2 ingress trùng host `auth.job7189.local`: `ingress-auth-internal` (proxy-buffer-size: 16k) và `ingress-keycloak` (proxy-buffer-size: 128k). Không gây lỗi nhưng gây nhầm lẫn và nginx có thể chọn rule không tối ưu.

**Việc cần làm:**
- [ ] Xóa `ingress-auth-internal`: `kubectl delete ingress -n security ingress-auth-internal`
- [ ] Giữ `ingress-keycloak` với `proxy-buffer-size: 128k` (đúng cho Keycloak JWT headers)

---

## 📊 Trạng thái hệ thống hiện tại (2026-06-12)

| Component | Namespace | Status | Ghi chú |
|-----------|-----------|--------|---------|
| Keycloak | security | ✅ Running | Cilium L7 loopback fix applied |
| oauth2-proxy | security | ✅ Running | Đã cập nhật labels mới thành công |
| App microservices (6 svc) | job7189-apps | ✅ Running | Toàn bộ 6 dịch vụ hoạt động tốt |
| ingress-nginx | ingress-nginx | ✅ Running | L4-only to Keycloak (fix applied) |
| Vault | vault | ✅ Running | vault-0 + agent-injector |
| Tetragon | kube-system (DS) | ✅ Running v1.7.0 | Sigkill verified |
| Gatekeeper | gatekeeper-system | ✅ Running | Admission webhook active |
| SPIRE | spire | ✅ Running | Server + agents, SVID unverified |
| Trivy Operator | security-cdm | ✅ Running | Đã cấu hình và nâng memory limit quét thành công |
| PDP Controller | security | ✅ Running | Đã cấu hình và gán nhãn thành công |
| Threat Intel | security-cdm | ✅ CronJob active | `0 * * * *` schedule |
| Sigstore Policy | cosign-system | ✅ Running | Image verification active |

---

## 📁 Files quan trọng cần theo dõi

| File | Mô tả |
|------|-------|
| [`30-l7-keycloak-oidc.yaml`](../infras/k8s-yaml/cilium-policies/30-l7-keycloak-oidc.yaml) | L7 OIDC policy — đã fix split L4/L7 |
| [`12-security.yaml`](../infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml) | Security namespace policy — oauth2-proxy labels cần fix |
| [`45-upgrade-and-rollback-plan.md`](./45-upgrade-and-rollback-plan.md) | Chi tiết deploy/rollback từng Tier |
| [`46-cilium-l7-same-node-loopback.md`](./46-cilium-l7-same-node-loopback.md) | Root cause L7 timeout — đọc trước khi thêm L7 rule mới |
| [`37-phase5d-followup-todo.md`](./37-phase5d-followup-todo.md) | Thesis chapter4 items còn pending |

---

## 🗄️ Archived & Deprecated Tasks

### Tác vụ: Đo latency end-to-end baseline vs enforced (Phase 5.F Item J) — Bỏ qua theo yêu cầu (2026-06-12)
- `[ ]` Verify Vault auth ổn: `kubectl exec -n vault vault-0 -- vault status`
- `[ ]` Chạy latency baseline (không ZTA): tắt tạm OPA/Cilium enforcement → đo throughput
- `[ ]` Chạy latency enforced (ZTA đầy đủ): đo với Kong+OPA+Cilium active
- `[ ]` Ghi nhận số liệu vào `chapter4.tex §5.2` và `37-phase5d-followup-todo.md`
- `[ ]` Dùng `hey -z 60s -c 20` qua Kong port 8000: các path `/api/health`, `/api/public/jobs`, `/api/jobs`

