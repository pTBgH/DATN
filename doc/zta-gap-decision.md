# Quyết định kiến trúc — ZTA Gap Resolution

**Ngày chốt:** 2026-05-07.
**Bối cảnh:** kết quả gap analysis ở `doc/33-zta-gap-analysis.md`.
**Trạng thái:** ACCEPTED — căn cứ chính cho mọi PR `PR-I`..`PR-M` (tracking implementation).
**Người ra quyết định:** owner đồ án.
**Mục đích:** chốt scope còn lại của ZTA PoC; bất kỳ PR nào lệch decision này phải tham chiếu lại file này và giải thích.

---

## Quyết định 1 — Trust Score (gap §1)

**Chọn Option A rút gọn.**

Trust Score được implement với **2 input**, không phải 4 như Option A đầy đủ:

| Input | Nguồn | Trạng thái |
|-------|-------|-----------|
| Label coverage | 6 ZTA labels của pod (đã có) | Giữ nguyên `evaluate_labels()` trong `infras/pdp/pdp_controller.py` |
| CVE severity | `VulnerabilityReport` CR do Trivy Operator phát ra | **Thêm mới** — PDP list CR per pod, lấy `report.summary.criticalCount` / `highCount` |

**Output:** label `cilium.zta/score-bucket=high|medium|low` (không phải số 0–100). 3 bucket cho phép Cilium CNP `endpointSelector.matchLabels` sử dụng được — annotation không match được.

**Ngưỡng đề xuất** (có thể tinh chỉnh sau khi chạy thử):

```text
score = max(0, 100
            - 30  * (missing_labels / 6)
            - 50  * has_critical_cve
            - 20  * has_high_cve)
score-bucket = high   if score >= 80
              medium  if score >= 50
              low     else
```

**Loại bỏ khỏi scope PoC:**

- Input **kill event (Tetragon gRPC subscriber)**. Lý do: Tetragon đã `SIGKILL` ở kernel-level — giảm Trust Score thêm là hành động dư thừa với cùng một sự kiện. Để lại như "future work" trong báo cáo.
- Input **IoC match**. Lý do: dynamic CCNP egress deny ở Quyết định 3 đã chặn ở network layer — không cần thêm tầng quyết định ABAC.

Kết quả: Trust Score **thực dùng được** ở 2 chiều — admission (Gatekeeper qua label) + east-west (Cilium CNP qua label).

---

## Quyết định 2 — Alertmanager (gap §6.2)

**Không cài Alertmanager.**

Triển khai:
- ✅ `PrometheusRule` CR (alerting rules) — bắt buộc.
- ✅ Grafana dashboard (panel hiển thị "alert firing" từ Prometheus `ALERTS{...}` query) — bắt buộc.
- ❌ Alertmanager binary — bỏ.

Lý do:
1. Trong PoC, mục đích là **chứng minh observability loop tồn tại**, không phải vận hành 24/7. Grafana panel "alerts firing" đủ chứng minh.
2. Tiết kiệm ~80 MiB RAM trên lab 12 GiB.
3. Alertmanager cần routing config (Slack/PagerDuty/email) — production concern, không thuộc đồ án "Nghiên cứu kiến trúc Zero Trust".

Báo cáo phải nêu rõ: "Alertmanager là production concern, không phải PoC requirement; PrometheusRule + Grafana đã đủ chứng minh observability loop".

---

## Quyết định 3 — Threat Intel feeds (gap §5)

**Hai nguồn không token, miễn phí, không rate-limit gắt:**

| Nguồn | Format | Áp dụng | Tần suất refresh |
|-------|--------|---------|------------------|
| **FireHOL Level1** (`firehol_level1.netset`) | CIDR list | `CiliumClusterwideNetworkPolicy.egressDeny.toCIDRSet` | 1h CronJob |
| **URLhaus hostfile** (abuse.ch) | Hostnames | `CiliumNetworkPolicy.toFQDNs.matchPattern` cho egress namespace `job7189-apps` | 1h CronJob |

**Pipeline:**
1. CronJob `threat-intel-refresh` (namespace `security-cdm`) chạy mỗi giờ.
2. Fetch 2 feed → normalize → ghi `ConfigMap threat-intel-blocklist` (key `cidr-list`, `fqdn-list`).
3. Cùng CronJob `kubectl patch ccnp cnp-threat-intel-egress-deny --type=merge` với CIDR/FQDN từ ConfigMap.
4. Audit lineage: ship CronJob output → ES index `threat-intel-feed-*`.

**Không** dùng AlienVault OTX (cần API key) hoặc AbuseIPDB (rate limit). Giữ scope không phụ thuộc credential ngoài.

---

## Quyết định 4 — RAM Budget

**Lab 12 GiB, không tăng.** Headroom mục tiêu sau khi xong: ≥ 1.3 GiB.

| Stack thêm | RAM thêm | Trạng thái |
|------------|----------|-----------|
| Trivy Operator | ~150 MiB | ✅ In scope |
| Threat-intel CronJob | ~50 MiB peak / ~0 idle | ✅ In scope |
| Grafana dashboard JSON + PrometheusRule | ~0 MiB (tận dụng instance hiện có) | ✅ In scope |
| **Tổng thêm** | **~200 MiB** | |
| Alertmanager | ~80 MiB | ❌ Loại (Quyết định 2) |
| Tetragon gRPC subscriber thread trong PDP | ~0 MiB nhưng cần CNP egress + thread mới | ❌ Loại (Quyết định 1) |
| Kube-bench CronJob | ~50 MiB peak / ~0 idle | ⚠️ Optional Day 7-8 |

**Hệ quả thiết kế:** mọi script deploy mới phải có hỗ trợ `ZTA_REBUILD_SKIP=...` để chế độ low-RAM tắt được Trivy/threat-intel mà không vỡ pipeline.

---

## Thứ tự sprint

Triển khai tuần tự (mỗi PR ≤ 1 module). Bullet "ngày" chỉ ước lượng; ưu tiên thực thi đúng thứ tự, không bám deadline.

| Phase | PR | Phạm vi |
|-------|----|---------|
| 1 | **PR-I** | Trivy Operator deploy (`scripts/zta-deploy-trivy.sh` + `infras/k8s-yaml/trivy-operator/*` + step `28-trivy` trong `scripts/zta-rebuild.sh` + Test 4m trong `09-verify-zta.sh`). Điều kiện done: `kubectl get vulnerabilityreport -A` ≥ 1 CR sau pipeline. |
| 2 | **PR-J** | Refactor `infras/pdp/pdp_controller.py`: thêm method `read_image_cve()` + công thức score 2-input + patch label `cilium.zta/score-bucket`. Thêm CNP `cnp-block-low-trust-to-vault` (mẫu) gating namespace `vault` chỉ nhận traffic từ pod có `score-bucket=high`. Test 4o trong verify. |
| 3 | **PR-K** | Threat-intel: `scripts/zta-deploy-threat-intel.sh`, manifests CronJob + ConfigMap rỗng + CCNP `cnp-threat-intel-egress-deny`, Filebeat ship log CronJob. Test 4n. |
| 4 | **PR-L** | `infras/k8s-yaml/grafana-dashboards/zta-overview.json` (provisioned ConfigMap) + `infras/k8s-yaml/prometheus-rules.yaml` (`PrometheusRule` CR). |
| 5 | **PR-M** | Kube-bench CronJob *hoặc* nếu hết thời gian thì viết subsection chap3 mô tả CDM architecture đầy đủ và đánh dấu kube-bench là *"validated design, not yet deployed"*. |

---

## Hai câu hội đồng hay hỏi (chuẩn bị câu trả lời)

**Q1: "Trust Score tính từ cái gì thật sự?"**

A: Trust Score được tính bằng công thức weighted 2-input — (a) tỉ lệ ZTA label coverage (6 label bắt buộc) và (b) số lượng CVE Critical/High trong `VulnerabilityReport` CR do Trivy Operator phát ra. Output là label `cilium.zta/score-bucket` chia 3 mức `high`/`medium`/`low`. Cilium CNP và Gatekeeper Constraint match label này để enforce ở 2 chiều: admission (Gatekeeper deny pod create) và east-west (CNP cấm pod `score-bucket=low` truy cập namespace `vault`).

**Q2: "PEP có thực sự enforce dựa vào Trust Score không?"**

A: Có. PEP đầu tiên là Cilium — CNP `cnp-block-low-trust-to-vault` dùng `endpointSelector.matchLabels.cilium.zta/score-bucket=high` ở `fromEndpoints`, drop traffic từ mọi pod có bucket `medium`/`low` tới namespace `vault`. PEP thứ hai là Gatekeeper — Constraint `K8sBlockLowTrust` deny admission cho pod có bucket `low`. Bằng chứng: trong `09-verify-zta.sh` Test 4o, gỡ 1 label của 1 pod → PDP downgrade bucket → CNP block traffic tới `vault` (Hubble drop log) trong < 60 giây.

---

## Tham chiếu

- Gap analysis nguyên gốc: `doc/33-zta-gap-analysis.md`.
- PIP reference: `doc/16-pip-data-sources.md` (PIP 4 CDM, PIP 6 Threat Intel).
- Adaptive loop: `doc/24-adaptive-security-loop.md`.
- PDP architecture (sẽ cần update trong PR-J): `doc/25-pdp-controller.md`.
- Resource budget: `doc/06-resource-budget.md`.
- Tracking implementation: file này sẽ được update ở cuối mỗi PR (mục "Tiến độ thực thi") để khớp với những gì đã merge.

---

## Tiến độ thực thi (cập nhật theo từng PR)

| PR | Branch | Trạng thái | Ghi chú |
|----|--------|-----------|---------|
| PR-I | `devin/1778171244-pr-i-trivy-cdm` | đang chờ test trên lab | Trivy Operator (chart `aquasecurity/trivy-operator` v0.22) + step `28-trivy` (timeout 1200s) + Test 4m. Chỉ bật `vulnerabilityScannerEnabled` + `configAuditScannerEnabled`; tắt sbom/rbac/infra/exposedSecret để giữ ~150 MiB RAM. Manifests: `infras/k8s-yaml/trivy-operator/{00-namespace,01-values,02-cnp}.yaml`. Namespace mới `security-cdm` có default-deny + dns + trivy-egress + monitoring-ingress CNP. |
| PR-J | `devin/<ts>-pr-j-pdp-score-bucket` | chưa | |
| PR-K | `devin/<ts>-pr-k-threat-intel` | chưa | |
| PR-L | `devin/<ts>-pr-l-grafana-prom-rule` | chưa | |
| PR-M | `devin/<ts>-pr-m-kube-bench` | chưa | optional |
