# ZTA Gap Analysis — Doc vs Code

**Phạm vi:** đối chiếu kiến trúc tham chiếu trong `documents/latex/` (chap 1, 2, 3, kết luận, `bosung.md`) với mã nguồn thực tế (`infras/`, `scripts/zta-deploy-*.sh`, `09-verify-zta.sh`, `scripts/zta-rebuild.sh` STEPS).
**Mục tiêu:** liệt kê các hợp phần ZTA đã được cam kết trong tài liệu nhưng **chưa hiện diện trong cluster**, và đưa ra lộ trình triển khai từng phần.
**Format:** một trang, không yapping. Mỗi phần đều có (a) bằng chứng, (b) cách triển khai, (c) verify.
**Decision đi cùng:** `doc/zta-gap-decision.md` — chốt các câu hỏi ở §9; mọi PR `PR-I`..`PR-M` đều tham chiếu file đó.

---

## 0. TL;DR — bảng tổng hợp

| # | Hợp phần | Tài liệu nói | Code thực tế | Trạng thái |
|---|----------|--------------|--------------|------------|
| 1 | **Trust Score là attribute thực dùng cho PE/PEP** | chap2 §2.3.2, §2.3.4: Trust Score là input ABAC; observ. anomaly → giảm score → PEP ngắt kết nối | `infras/pdp/pdp_controller.py` chỉ tính score = % label coverage; **không có PEP nào đọc annotation `cilium.zta/trust-score`** | ⚠️ Implemented-as-name-only |
| 2 | **CDM (PIP 4)** | chap1 §1.2.2, chap2 §2.3.2 (Posture/Threat Intel layer) | 0 deployment; `doc/16-pip-data-sources.md` tự thừa nhận ❌/⚠️ | ❌ Missing |
| 3 | **Trivy** | chap2, chap3, kết luận: "Trivy scan image, CVE > 7.0 → deny" | 0 reference trong `infras/`, `scripts/`, `09-verify-zta.sh` | ❌ Missing |
| 4 | **Kube-bench** | chap2 §2.3.2 + §2.4 (Bảng pillar): "Kube-bench baseline" | 0 reference | ❌ Missing |
| 5 | **External Threat-Intel feeds → OPA/Cilium** | chap2 §2.3.2: "IoC feed → PE/PEP cập nhật Deny realtime" | 0 ingestion, 0 FQDN/IP blocklist policy động, 0 STIX/TAXII consumer | ❌ Missing |
| 6 | **UEBA / anomaly detection** | chap2 feedback loop: "100 req /admin trong 1s → giảm Trust → cut" | 0 detector, 0 PrometheusRule, 0 Alertmanager | ❌ Missing |
| 7 | **Alertmanager / PrometheusRule** | chap3 §3.6 (Adaptive), kết luận §kế hoạch | `infras/k8s-yaml/08-prometheus.yaml` không có `PrometheusRule`, không cài Alertmanager; Grafana không có dashboard JSON | ❌ Missing |
| 8 | **Trust Score visibility (Grafana/Kibana)** | chap3: PDP metrics → Prom; audit drift → ES | Gauge `pdp_trust_score` có expose, nhưng **không có Grafana dashboard provisioned**, không có Kibana saved-search | ⚠️ Half-wired |
| 9 | **Tetragon → PDP closed loop** | `doc/24-adaptive-security-loop.md` §6: kill event → giảm trust → policy update | PDP chỉ watch label, **không subscribe Tetragon events** (`pdp_controller.py` chỉ có `kopf.on.create/update` cho Pod) | ⚠️ Open loop |
| 10 | **CAEP / ITDR** | `chaterketluan.tex` §hạn chế | Đã được khai báo là "kế hoạch" — không tính là gap mới | ❌ Out-of-scope đồ án |
| 11 | **MDM/EDR (PIP 5 Devices)** | chap2, kết luận §hạn chế | Khai báo là "Initial" pillar — không tính là gap mới | ❌ Out-of-scope đồ án |

> Diễn giải: 5 gap user nêu (Trust Score, CDM, Trivy, kube-bench, external feeds) đều là **vacant** ở mức enforcement. PDP hiện tại là **label compliance auditor**, không phải Policy Decision Point theo nghĩa NIST 800-207 (không tổng hợp Identity + Posture + Threat + Behavior thành quyết định).

---

## 1. Trust Score — biến tên, không phải biến giá trị

### Bằng chứng
- `infras/pdp/pdp_controller.py` `evaluate_labels()` — score = `round(100 * (6 − missing) / 6)`. Input duy nhất là **set 6 label** (`cilium.zta/{tier,source,destination,role,owner,sensitivity}`).
- `grep -r "trust.score" infras/` → chỉ trả về chính file ConfigMap PDP. Không Cilium CNP nào, không Kong plugin, không Gatekeeper Constraint, không Tetragon TracingPolicy đọc annotation `cilium.zta/trust-score`.
- Annotation Pod **không** xuất hiện trong identity của Cilium (CNP `endpointSelector` chỉ match label, không match annotation).
- chap2 §2.3.2 và §2.3.4 mô tả Trust Score là **continuous attribute** chịu tác động của: SVID validity, image posture (Trivy), behavior (UEBA), context (time/IP). Code thực tế chỉ có 1 trong các đầu vào đó (label completeness, ~ Workload Identity proxy).

### Hướng triển khai (ưu tiên P0)
**Option A — Real PDP với weighted score (đúng tinh thần chap2):**
1. Mở rộng `pdp_controller.py` thành một aggregator:
   - Input 1 — label coverage (đã có).
   - Input 2 — image posture: `kubectl get pod -o json` → image digest → Trivy scan kết quả từ ConfigMap `pdp-image-cve` (do Trivy operator ghi).
   - Input 3 — runtime: subscribe Tetragon `EventTracingPolicyKill` qua gRPC → giảm score 50 trong 5 phút.
   - Input 4 — threat-intel: load `threat-intel-blocklist` ConfigMap (IP/FQDN/SHA256), match identity / image digest.
2. Score formula đề xuất: `score = 100 - 30*missing_label_ratio - 50*has_critical_cve - 30*recent_kill_event - 100*ioc_match` (clamp 0..100).
3. **Bind score vào enforcement** (chỗ đang hoàn toàn thiếu):
   - **Cilium**: PDP patch label `cilium.zta/score-bucket=high|medium|low` (3 bucket, không phải số) → CNP dùng `endpointSelector.matchLabels.cilium.zta/score-bucket=high` cho high-sensitivity routes.
   - **Kong**: PDP expose `/decision/<sub>` → Kong custom plugin (Lua) gọi để gate route nhạy cảm.
   - **Gatekeeper**: thêm ConstraintTemplate `K8sBlockLowTrust` admission deny pod create nếu owner namespace có `score-bucket=low`.
4. Audit: mọi thay đổi score → JSON line stdout (đã có `audit()`); thêm field `inputs` với breakdown.

**Option B — Giảm scope, không refactor PDP:**
- Đổi tên `pdp_trust_score` → `pdp_label_coverage` ở `pdp_controller.py` + `25-pdp-controller.md` để khớp với cái đang đo.
- Giữ Trust Score đúng nghĩa NIST là **kế hoạch** trong chap kết luận. Đây là cách dễ nhất để báo cáo không bị lệch code.

### Verify (cho Option A)
- `kubectl -n job7189-apps annotate pod $POD test/inject-cve=critical --overwrite` → trong 60s thấy score giảm + Cilium label `score-bucket=low` được patch.
- Tetragon kill demo: `bash scripts/zta-tetragon-demo.sh` → Prometheus `pdp_trust_score` drop từ 100→50 trong cửa sổ 5 phút.

---

## 2. CDM (Continuous Diagnostics & Mitigation) — PIP 4 vắng mặt

### Bằng chứng
- `doc/16-pip-data-sources.md` §"PIP 4: CDM" tự đánh dấu **⚠️ Partial — Trivy manual, kube-bench chưa deploy**.
- chap2 §2.3.2 mô tả CDM là PE input ngang hàng IdP/SVID. Code không có:
  - `apiGroups: aquasecurity.github.io` (Trivy Operator CRDs: VulnerabilityReport, ConfigAuditReport, ClusterComplianceReport).
  - Job/CronJob nào chạy kube-bench / Trivy / kube-hunter.
- `documents/latex/chapters/chapter2.tex:171` viết "Tích hợp Trivy, Kube-bench" — claim này không có evidence trong `09-verify-zta.sh`.

### Hướng triển khai (ưu tiên P0)
1. **Trivy Operator** (`aquasecurity/trivy-operator` Helm chart, ~150 MiB RAM):
   - Namespace mới: `security-cdm`.
   - Tự động scan mỗi image trong cluster, ghi `VulnerabilityReport` + `ConfigAuditReport` CR per pod.
   - Thêm `STEPS` mới `28-trivy-operator|Deploy Trivy Operator|bash scripts/zta-deploy-trivy.sh` trong `scripts/zta-rebuild.sh`.
2. **Kube-bench** (`aquasecurity/kube-bench` Job):
   - Một-shot Job mỗi ngày (CronJob) ghi report ra ConfigMap `kube-bench-report` namespace `security-cdm`.
   - Filebeat ship report → ES index `kube-bench-*`.
   - Step mới `29-kube-bench|Deploy kube-bench CronJob|bash scripts/zta-deploy-kube-bench.sh`.
3. **PE consume CDM**:
   - Cách đơn giản: PDP controller (sau Option A §1) periodic list `VulnerabilityReport` CR → cập nhật trust score per pod.
   - Cách Gatekeeper: thêm ConstraintTemplate `K8sBlockCriticalCVE` đọc Trivy CR qua external data provider (Gatekeeper external-data) → admission deny image có CVE critical (block ở admission, không cần PE).
4. **Verify trong `09-verify-zta.sh`** — thêm Test 4m:
   - Đếm `VulnerabilityReport` CR ≥ 1 trong cluster.
   - Đếm CronJob `kube-bench` last-run ≤ 24h.
   - PDP trust score của 1 pod test với image cố tình lỗi thời (e.g. `nginx:1.14`) phải < 60.

### Tài nguyên
- Trivy Operator: ~150 MiB RAM (1 deploy, scan offline DB).
- Kube-bench: ~50 MiB peak khi job chạy, idle 0.
- Tổng thêm: ~200 MiB. Lab 12 GiB hiện chiếm ~10.5 GiB → **cần test pre-flight gate trước khi enable**.

---

## 3. Trivy — đã gộp ở §2 (CDM). Không tách step.

Lý do gộp: Trivy chính là cái cài đặt CDM cho image posture. Kube-bench cài CDM cho cluster-config posture.

---

## 4. Kube-bench — đã gộp ở §2 (CDM).

Đặc thù riêng nếu tách:
- Phải mount `hostPath: /var/lib/etcd` + `/etc/kubernetes` để scan master config → Kind đặt 4 node (1 control-plane), Job `kube-bench` cần `nodeSelector: node-role.kubernetes.io/control-plane=`.
- CIS profile cho Kind: `--benchmark cis-1.7` hoặc `--targets master,etcd,controlplane,node`.

---

## 5. External Threat-Intel Feeds — vắng mặt hoàn toàn

### Bằng chứng
- chap2 §2.3.2: "IoC feed (IP đen, mã độc, cert thỏa hiệp) → PE/PEP cập nhật Deny realtime".
- chap2 Bảng §2.4: "Threat Intelligence | External Feeds → OPA/Cilium | Bổ sung | Lớp 2".
- `grep -r "stix\|taxii\|misp\|otx\|ioc" infras/ scripts/` → 0 hit.
- Cilium hỗ trợ FQDN/CIDR-based egress policy nhưng các CNP hiện tại trong `infras/k8s-yaml/cilium-policies/` **không** lấy danh sách động từ feed nào — chúng là static allowlist.

### Hướng triển khai (P1 — sau khi PDP/CDM đã ổn)
**Pattern: feed → ConfigMap → Cilium dynamic policy.**
1. **Feed source khả thi cho PoC** (free, không cần token):
   - AbuseIPDB blacklist (có rate limit free).
   - URLhaus/MalwareBazaar (abuse.ch).
   - FireHOL Level1 (CIDR aggregate).
   - AlienVault OTX (cần đăng ký free key).
2. **Ingestion CronJob** (`scripts/zta-deploy-threat-intel.sh`):
   - CronJob mỗi 1h: fetch feed → normalize sang JSON → write ConfigMap `threat-intel-blocklist` (namespace `security-cdm`).
   - Ngân sách: 1 CronJob × ~50 MiB peak → idle 0.
3. **Cilium Dynamic Policy**:
   - Tạo `CiliumClusterwideNetworkPolicy` `cnp-threat-intel-egress-deny` với `egressDeny: toCIDRSet:` populated bằng `cidr-list` ConfigMap.
   - Update bằng cách patch CCNP từ CronJob (script gọi `kubectl patch ccnp ... --type=merge`).
   - Hoặc dùng Cilium FQDN policy với `matchPattern` cho domain blocklist (URLhaus).
4. **PE consume Threat Intel** (kết hợp với §1 Option A):
   - PDP load ConfigMap `threat-intel-blocklist` → match image digest / SPIFFE ID / source IP.
   - Trust score dùng input `ioc_match` (multiplier 100% deny).
5. **Audit**: ship CronJob output → ES index `threat-intel-feed-*` để có lineage (feed nào, version nào, được áp ngày nào).

### Verify
- ConfigMap `threat-intel-blocklist` có `data.cidr.list` ≥ 100 entries.
- `kubectl get ccnp cnp-threat-intel-egress-deny -o yaml` chứa CIDR khớp ConfigMap.
- Test: deploy 1 pod cố tình curl 1 IP trong blocklist → Hubble drop log `traffic-direction: EGRESS, drop_reason: POLICY_DENIED`.

---

## 6. Phần phụ — closed loop (Tetragon → PDP) + visibility

Hai gap sau không nằm trong câu hỏi user nhưng cần điều kiện đủ để Trust Score §1 hoạt động.

### 6.1. Tetragon → PDP gRPC subscriber
- Tetragon expose gRPC stream `tetragon.io/grpc/v1`. PDP cần thêm thread subscribe `GetEvents` filter `event_set: PROCESS_KILL` → enqueue `(ns, pod, ts)` → push vào in-memory cache `recent_kills` với TTL 5 phút → input `recent_kill_event` cho score formula §1 Option A.
- Manifest: thêm CNP egress allow `pdp` → `tetragon` namespace `kube-system` port 54321.

### 6.2. Grafana dashboard + Alertmanager
- File mới `infras/k8s-yaml/grafana-dashboards/zta-overview.json` — panels:
  - `pdp_trust_score` heatmap by namespace.
  - `pdp_label_drift_total` rate.
  - Cilium policy drops (Hubble) per CNP.
  - Trivy `aquasecurity_vulnerabilityreports` count by severity.
- Provision qua ConfigMap đã có (`grafana-dashboard-providers`, dir `/var/lib/grafana/dashboards`).
- `infras/k8s-yaml/prometheus-rules.yaml` thêm `PrometheusRule`:
  - `alert: ZTATrustScoreDropped` `expr: pdp_trust_score < 60 for 2m`.
  - `alert: ZTACVECriticalImage` `expr: count(aquasecurity_vulnerabilityreports{severity="CRITICAL"}) > 0`.
- Cài Alertmanager (Bitnami chart, ~80 MiB) → route ra stdout (PoC) hoặc webhook nội bộ.

---

## 7. Đề xuất thứ tự triển khai

| Sprint | Step | Mục tiêu | RAM thêm | Rủi ro |
|--------|------|----------|----------|--------|
| **S1** | Đặt tên đúng (Option B §1) hoặc giữ Trust Score → công bố lộ trình rõ ràng | — | 0 | Thấp — chỉ sửa doc + rename metric |
| **S2** | Trivy Operator (§2) | Trust Score có nguyên liệu thật | ~150 MiB | TB — cần update pre-flight RAM gate |
| **S3** | Kube-bench CronJob (§4) | Posture cluster-level | ~0 idle | Thấp |
| **S4** | PDP refactor weighted score + bind label `score-bucket` (§1 Option A) | Trust Score thực dùng được | ~0 | Cao — refactor logic; thêm test E2E |
| **S5** | Threat-Intel feed + CCNP dynamic egress deny (§5) | PIP 6 closed | ~50 MiB peak | TB — feed có thể down |
| **S6** | Tetragon gRPC subscriber + Grafana dashboard + PrometheusRule (§6) | Closed loop trông thấy được | ~80 MiB | Thấp |

Tổng thêm sau khi xong: **~280 MiB**. Lab 12 GiB hiện ~10.5 GiB → cần PR-E (đã merge) RAM pre-flight + cần khả năng tắt Trivy/kube-bench bằng env flag `ZTA_REBUILD_SKIP=28-trivy,29-kube-bench` cho chế độ thấp tài nguyên.

---

## 8. Mức độ phải đụng vào code & doc

| Khu vực | Phạm vi sửa |
|---------|-------------|
| `infras/pdp/pdp_controller.py` | Refactor lớn (S4) — thêm input pluggable: cve, kill, ioc |
| `infras/k8s-yaml/pdp/20-configmap.yaml` | Regenerate sau S4 |
| `infras/k8s-yaml/cilium-policies/` | Thêm `cnp-threat-intel-egress-deny.yaml` (S5); thêm CNP egress PDP→Tetragon (S6) |
| `infras/k8s-yaml/opa-gatekeeper/` | Thêm template `K8sBlockCriticalCVE` (S2 hoặc S4) |
| `infras/k8s-yaml/grafana-dashboards/` | **Tạo mới** — dir chưa tồn tại |
| `infras/k8s-yaml/prometheus-rules.yaml` | **Tạo mới** — file chưa tồn tại |
| `scripts/zta-deploy-trivy.sh` `…-kube-bench.sh` `…-threat-intel.sh` | **Tạo mới** |
| `scripts/zta-rebuild.sh` STEPS array (line 165) | Thêm 28/29/30 trước `90-verify` |
| `09-verify-zta.sh` | Thêm Test 4m (CDM), 4n (Threat Intel feed freshness), 4o (Trust Score with score-bucket label) |
| `documents/latex/chapters/chapter3.tex` | Thêm subsection mô tả CDM/threat intel sau §3.6 |
| `documents/latex/chapters/chapter4.tex` | Cập nhật bảng đánh giá khi xong |
| `documents/latex/chapters/chaterketluan.tex` | Bỏ bullet "Trivy/Kube-bench lý thuyết" khỏi §hạn chế |

---

## 9. Câu hỏi cần user xác nhận trước khi code

1. Chọn **Option A** (làm Trust Score thật, refactor PDP) hay **Option B** (đổi tên metric, giữ scope hiện tại)?
2. Có muốn deploy Alertmanager không, hay chỉ PrometheusRule + Grafana panel là đủ cho đồ án?
3. Threat-intel feed nên chọn 1-2 nguồn nào (gợi ý: FireHOL Level1 + URLhaus, không cần token)?
4. Lab 12 GiB còn ~1.5 GiB headroom — có chấp nhận thêm ~280 MiB cho stack đầy đủ, hay phải giữ chế độ "low-RAM" (chỉ cài Trivy + threat-intel, bỏ kube-bench Cron + Alertmanager)?

---

## Phụ lục — bằng chứng grep

```text
$ grep -rln -i "trivy\|kube-bench\|kubebench" --include='*.sh' --include='*.yaml' --include='*.py' .
(no matches)

$ grep -rln -i "stix\|taxii\|misp\|external.feed" --include='*.sh' --include='*.yaml' --include='*.py' .
(no matches)

$ grep -rln "trust.score\|trust_score" --include='*.yaml' --include='*.go' --include='*.lua' --include='*.rego' .
infras/k8s-yaml/pdp/20-configmap.yaml   # (chỉ nội bộ PDP)

$ grep -rln "PrometheusRule\|kind: TracingPolicy" infras/k8s-yaml/
infras/k8s-yaml/tetragon-policies/block-suspicious-exec.yaml
infras/k8s-yaml/tetragon-policies/block-suspicious-exec-t1.yaml
infras/k8s-yaml/tetragon-policies/monitor-sensitive-files.yaml
# Không có PrometheusRule
```

`scripts/zta-rebuild.sh:165-188` STEPS hiện tại: **không có** step nào cho Trivy / kube-bench / threat-intel / alertmanager. Pipeline kết thúc ở `27-pdp` rồi nhảy thẳng `90-verify`.
