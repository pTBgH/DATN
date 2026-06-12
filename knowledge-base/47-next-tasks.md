# Danh sách công việc cần làm tiếp theo

**Cập nhật lần cuối:** 2026-06-12  
**Trạng thái hệ thống:** Keycloak ✅ fixed | App pods ✅ 5/5 Running | Cilium policies ✅ áp dụng

---

## 🔴 Ưu tiên cao — cần làm trước

### 1. Migrate toàn bộ legacy namespace label trong CNP
**Vấn đề:** Vẫn còn **169 dòng** dùng selector cũ `k8s:io.kubernetes.pod.namespace` trong các `CiliumNetworkPolicy` đang deploy trên cluster. Cilium mới ưu tiên `k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name`. Selector cũ có thể không match đúng gây policy bypass hoặc block sai.

**Việc cần làm:**
- [ ] Chạy audit toàn bộ CNP đang live trên cluster: `kubectl get cnp -A -o yaml | grep -n "io.kubernetes.pod.namespace"`
- [ ] So sánh với file source trong `infras/k8s-yaml/cilium-policies/` — file nào chưa migrate?
- [ ] Đặc biệt kiểm tra các file chưa sửa:
  - `12-security.yaml` — rule `allow-oauth2-proxy-ingress` (line 126) và `allow-oauth2-proxy-egress` vẫn dùng label cũ
  - Các policy trong namespace `monitoring`, `management`, `data`, `vault`
- [ ] Apply lại tất cả file đã sửa: `kubectl apply -f infras/k8s-yaml/cilium-policies/namespaces/`

**Tham khảo:** [`46-cilium-l7-same-node-loopback.md`](./46-cilium-l7-same-node-loopback.md)

---

### 2. PDP Controller — chưa deploy
**Vấn đề:** Namespace `pdp-system` tồn tại nhưng **không có pod nào**. PDP Controller là thành phần cốt lõi của Adaptive Security Loop — nó đọc Trivy vuln reports → tính điểm tin cậy → gán nhãn `zta.job7189/score-bucket` cho pods → Tier 2 CNP mới có thể enforce đúng.

**Việc cần làm:**
- [ ] Kiểm tra lý do PDP chưa chạy: manifest có sẵn chưa? `ls infras/k8s-yaml/pdp/`
- [ ] Deploy PDP controller: `bash scripts/zta-deploy-pdp.sh`
- [ ] Verify: `kubectl get pods -n pdp-system` → Running
- [ ] Verify labels được gán: `kubectl get pods -n job7189-apps -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.labels.zta\.job7189/score-bucket}{"\n"}{end}'`

**Tham khảo:** [`45-upgrade-and-rollback-plan.md § Tier 4`](./45-upgrade-and-rollback-plan.md)

---

### 3. Trivy Operator — đang chạy ở sai namespace
**Vấn đề:** `trivy-operator` đang chạy trong namespace `security-cdm`, không phải `trivy-system`. Namespace `trivy-system` không có pod nào. Cần xác nhận đây là cấu hình có chủ đích hay deploy nhầm.

**Việc cần làm:**
- [ ] Xác nhận: `kubectl get all -n security-cdm | grep trivy` — đây có phải đúng chỗ không?
- [ ] Kiểm tra VulnerabilityReport đang được scan: `kubectl get vulnerabilityreport -A | head -20`
- [ ] Kiểm tra 2 scan pods bị `Init:0/1`: `kubectl describe pod -n security-cdm scan-vulnerabilityreport-*` — lý do init fail
- [ ] Nếu sai namespace: migrate về `trivy-system` theo kế hoạch (`45-upgrade-and-rollback-plan.md § Tier 11`)

---

## 🟡 Ưu tiên trung bình

### 4. Đo latency end-to-end baseline vs enforced (Phase 5.F Item J)
**Vấn đề:** Đây là phép đo quan trọng nhất cho luận văn nhưng vẫn BLOCKED. Trước đây blocked do Vault init fail, hiện tại Vault đã Running và app pods đã 5/5 Ready.

**Việc cần làm:**
- [ ] Verify Vault auth ổn: `kubectl exec -n vault vault-0 -- vault status`
- [ ] Chạy latency baseline (không ZTA): tắt tạm OPA/Cilium enforcement → đo throughput
- [ ] Chạy latency enforced (ZTA đầy đủ): đo với Kong+OPA+Cilium active
- [ ] Ghi nhận số liệu vào `chapter4.tex §5.2` và `37-phase5d-followup-todo.md`
- [ ] Dùng `hey -z 60s -c 20` qua Kong port 8000: các path `/api/health`, `/api/public/jobs`, `/api/jobs`

**Target:** P50 < 500ms, P99 < 2s cho Enforced mode

---

### 5. Fix oauth2-proxy Cilium policy — label cũ
**Vấn đề:** `allow-oauth2-proxy-ingress` và `allow-oauth2-proxy-egress` trong `12-security.yaml` vẫn dùng `k8s:io.kubernetes.pod.namespace` (dạng cũ). oauth2-proxy đang trên srv03, ingress-nginx trên srv02 — khác node nên có thể chưa ảnh hưởng nhưng cần fix để nhất quán.

**Việc cần làm:**
- [ ] Sửa `12-security.yaml` lines 126, 146, 155, 165, 173: thay `k8s:io.kubernetes.pod.namespace: <ns>` → `k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name: <ns>`
- [ ] Apply: `kubectl apply -f infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml`
- [ ] Test oauth2-proxy vẫn hoạt động: `curl -H "Host: grafana.job7189.local" http://100.108.231.127:30003/oauth2/` → redirect to Keycloak

---

### 6. Hoàn thiện Cilium policy cho các namespace còn thiếu
**Vấn đề:** Một số namespace vẫn chưa có hoặc chưa đầy đủ Cilium NetworkPolicy:

**Việc cần làm:**
- [ ] Audit: `kubectl get cnp -A -o wide` — namespace nào thiếu policy?
- [ ] Đặc biệt kiểm tra: `data` (MySQL, Kafka), `monitoring` (Prometheus, Grafana, Kibana), `management` (phpMyAdmin)
- [ ] Verify `allow-prometheus-scrape-*` policies đang hoạt động đúng

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
| oauth2-proxy | security | ✅ Running | Policy labels cũ, cần fix |
| App microservices (6 svc) | job7189-apps | ✅ 5/5 Running | All healthy |
| ingress-nginx | ingress-nginx | ✅ Running | L4-only to Keycloak (fix applied) |
| Vault | vault | ✅ Running | vault-0 + agent-injector |
| Tetragon | kube-system (DS) | ✅ Running v1.7.0 | Sigkill verified |
| Gatekeeper | gatekeeper-system | ✅ Running | Admission webhook active |
| SPIRE | spire | ✅ Running | Server + agents, SVID unverified |
| Trivy Operator | security-cdm | ⚠️ Running | Namespace sai? Scan Init:0/1 fail |
| PDP Controller | pdp-system | ❌ Not deployed | Cần deploy |
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
