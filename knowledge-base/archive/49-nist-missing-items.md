# Những gì còn thiếu so với NIST 800-207 & NIST 1800-35

**Ngày:** 2026-06-12
**Nguồn đối chiếu:** `knowledge-base/NIST800207.md` (NIST SP 800-207, 08/2020) và `knowledge-base/NIST180035.md` (NIST SP 1800-35, High-Level Document).
**Trạng thái:** Sau khi PR #6 đã vá các gap của Chương 2 và Chương 3 (phần văn bản), tài liệu này liệt kê **những gì VẪN CÒN THIẾU** — gồm 3 nhóm: (A) thiếu trong luận văn, (B) thiếu trong hệ thống thực tế (theo kết quả audit 12/06), (C) thiếu về hạ tầng/phần cứng.

---

## A. Thiếu trong luận văn (chưa được vá ở PR #6)

### Chương 1 — 7 mục còn thiếu

| # | Thiếu gì | NIST ref | Vì sao quan trọng | Ưu tiên |
|---|----------|----------|-------------------|---------|
| A1 | **7 Data Sources / Supporting Components** cho Policy Engine (CDM, Industry Compliance, Threat Intelligence, Activity Logs, Data Access Policies, Enterprise PKI, ID Management, SIEM) | 800-207 §3, Figure 2 | Giải thích PE lấy dữ liệu từ đâu để ra quyết định — nền tảng cho toàn bộ thiết kế PIP ở Ch3 | P0 |
| A2 | **4 Deployed Variations** (Device Agent/Gateway §3.2.1, Enclave §3.2.2, Resource Portal §3.2.3, App Sandboxing §3.2.4). Ch1 §1.2.4 hiện đang nhầm *approaches* (§3.1) với *variations* (§3.2) | 800-207 §3.2 | Ch2 (sau PR #6) đã biện luận chọn model Agent/Gateway — nhưng Ch1 chưa có cơ sở lý thuyết cho 4 model này | P1 |
| A3 | **Network Requirements**: tách control plane / data plane, mã hóa toàn bộ lưu lượng | 800-207 §3.4 | Khái niệm nền cho thiết kế Cilium (data plane) vs K8s API/SPIRE server (control plane) ở Ch3 | P1 |
| A4 | **5 Deployment Scenarios** (Satellite, Multi-cloud, Contractor, Cross-enterprise, Public-Facing) | 800-207 §4 | Job7189 thuộc scenario "Enterprise with Public-Facing Services" (§4.5) — cần nêu để biện luận lựa chọn kiến trúc | P2 |
| A5 | **7 Threats riêng của ZTA** (Subversion of Decision Process, DoS lên PEP/PA, Stolen Credentials, Network Visibility, Storage of Network Info, Proprietary Formats, NPE in Administration) | 800-207 §5 | Ch2 chỉ có MITRE ATT&CK cho K8s (threats chung), chưa có threats đặc thù ZTA. KB10 (tấn công PDP) thực chất là threat §5.1 nhưng không được gọi tên | P0 |
| A6 | **3 quy trình vận hành R()/I()/S()** ở mức lý thuyết | 1800-35 §3.1 | Ch3 (sau PR #6) đã có bảng đối chiếu R/I/S — nhưng Ch1 chưa giới thiệu khái niệm này trước | P2 |
| A7 | Vị trí bảng **7 bước migration**: đang ở cuối Ch2, nên tham chiếu chéo từ Ch1 | 800-207 §7.3 | Cấu trúc | P2 |

### Chương 3 — 3 mục còn thiếu (phần văn bản)

| # | Thiếu gì | NIST ref | Vì sao quan trọng | Ưu tiên |
|---|----------|----------|-------------------|---------|
| A8 | **Sơ đồ kiến trúc vật lý chi tiết**: node placement, service→node mapping, resource allocation per node, sơ đồ Tailscale CGNAT + Cilium VXLAN overlay | 1800-35 §3.5 (ZTA Laboratory Physical Architecture) | NIST dành riêng §3.5 mô tả physical architecture (VLAN, firewall, management domain). Ch3 §3.7 chỉ có 3 dòng "4 VMs, 15.5 GiB, Tailscale" | P1 |
| A9 | **Tách control plane vs data plane** trong Ch3: liệt kê rõ thành phần nào thuộc plane nào (K8s API, Cilium operator, SPIRE server, Hubble relay = control; pod-to-pod eBPF = data) | 800-207 §3.4 | "ZTA logical components use a separate control plane" — yêu cầu kiến trúc bắt buộc, hiện không được chứng minh trong văn bản | P1 |
| A10 | **Roadmap Cosign WARN → ENFORCE**: điều kiện chuyển (tỉ lệ image đã ký 100%, thời gian chạy WARN không false-positive), kế hoạch thời gian | 1800-35 §5.3 (endpoint compliance findings) | Hiện chỉ ghi "đang ở WARN mode" mà không có lộ trình — người đọc không biết bao giờ/điều kiện gì thì enforce | P2 |

### Chương 4 — 5 mục còn thiếu

| # | Thiếu gì | NIST ref | Vì sao quan trọng | Ưu tiên |
|---|----------|----------|-------------------|---------|
| A11 | **KB1 (Impossible Travel + MFA) bị bỏ sót khỏi bảng tổng hợp 4.4** (chỉ có KB2–KB10) | — | Thiếu nhất quán: kịch bản mô tả chi tiết nhưng không có trong bảng kết quả | P1 |
| A12 | **Demonstration Methodology**: nêu rõ phương pháp thử nghiệm (manual demonstration vs automated — NIST dùng Mandiant Security Validation) | 1800-35 §6.1 | NIST yêu cầu mô tả methodology trước khi trình bày kết quả; Ch4 vào thẳng kịch bản | P1 |
| A13 | **Ánh xạ 10 kịch bản KB1–KB10 → 8 Use Cases chuẩn A–H** (A: Discovery, B: Enterprise-ID, C: Federated-ID, D: Other-ID, E: Guest No-ID, F: Confidence Level, G: Service-Service, H: Data Level Security) | 1800-35 §6.2 | Chứng minh coverage: KB của đồ án phủ được những use case chuẩn nào, thiếu use case nào (vd: C Federated-ID và E Guest hiện KHÔNG có kịch bản tương ứng) | P1 |
| A14 | **Số liệu latency baseline vs enforced** (P50/P99 qua Kong) | 1800-35 §5 (findings về overhead) | §4.1 hứa đánh giá hiệu năng nhưng chưa có số liệu. Script `zta-latency-benchmark.sh` đã sẵn — đang chờ chạy đúng mode | P0 |
| A15 | **Risk & Compliance Mapping**: ánh xạ security capabilities → NIST CSF subcategories / SP 800-53 controls | 1800-35 §7.2 (ZTA Security Mappings) | NIST 1800-35 có hẳn §7 về mapping; luận văn không có bất kỳ mapping compliance nào — điểm yếu lớn về academic rigor | P2 |

### Kết luận

| # | Thiếu gì | Ưu tiên |
|---|----------|---------|
| A16 | Cập nhật hạn chế: Tetragon ghi "chưa triển khai" nhưng thực tế đã chạy v1.7.0 (Sigkill verified); Cilium mTLS "tạm tắt" cần ghi rõ Tailscale WireGuard đang mã hóa L3 thay thế | P1 |

---

## B. Thiếu trong hệ thống thực tế (theo audit 12/06/2026)

Đây là khoảng cách giữa **những gì luận văn cam kết** và **những gì cluster đang chạy** — đối chiếu với yêu cầu NIST:

| # | Thiếu gì | NIST ref | Hiện trạng | Việc cần làm |
|---|----------|----------|------------|--------------|
| B1 | **Vòng lặp PDP chưa đóng (closed loop)**: PE phải nhận input liên tục từ CDM/threat intel để tái đánh giá | 800-207 §3.3 (Trust Algorithm), 1800-35 §3.1 S() | `zta-pdp` đang Running (ns `security`) nhưng **0 VulnerabilityReports** từ Trivy → PDP không có dữ liệu CVE để tính điểm | Sửa Trivy scan jobs (đang Init:0/1 fail), xác nhận PDP đọc được report, verify nhãn `score-bucket` được gán |
| B2 | **Trivy Operator sai chỗ + scan fail**: CDM system là 1 trong 7 data sources bắt buộc | 800-207 §3 (CDM) | Chạy ở `security-cdm` (kế hoạch là `trivy-system`), scan pods Init fail → 0 report | Debug init container của scan pods; quyết định giữ `security-cdm` (cập nhật docs) hay migrate |
| B3 | **169 legacy label trong live CNPs** — policy có thể không match đúng → bypass hoặc block sai | 800-207 tenet 4 (policy quyết định mọi truy cập) | Source đã migrate (PR #7) nhưng cluster chưa apply | Chạy `zta-audit-and-remediate.sh --apply` trên 7189srv01 |
| B4 | **Namespace `management` (phpMyAdmin) có 0 CNP** — tài nguyên quản trị không được PEP bảo vệ | 800-207 tenet 1 (mọi tài nguyên đều là resource), §5.7 (NPE admin risk) | phpMyAdmin truy cập trực tiếp MySQL mà không qua policy nào | Viết CNP default-deny + allow rõ ràng cho `management` |
| B5 | **SPIRE SVID chưa xác minh end-to-end**: 49 entries trên server nhưng chưa chứng minh workload thực sự nhận SVID | 800-207 §3 (ID management), tenet 6 | `/run/spiffe/` trong identity-service rỗng — chưa rõ sai đường mount hay CSI driver lỗi | Chạy audit script bản mới (probe 4 đường dẫn + in volumes) để chẩn đoán |
| B6 | **Latency chưa đo được**: benchmark trước chạy vào sai endpoint (Kong NodePort là 30000, không phải 8000) → 0 request thành công | — | Script đã fix (PR #7), tự detect endpoint | Chạy lại `enforced`; mode `baseline` cần gỡ tạm 13 CNP trong `job7189-apps` trước (có thể dùng Helmfile rollback theo Ch3 giai đoạn 3) |
| B7 | **Threat intelligence feed chưa sync** (FireHOL) — 1 trong 7 data sources | 800-207 §3 (Threat intelligence) | CronJob active nhưng feed chưa được xác nhận sync vào policy | Verify output CronJob; nối kết quả vào PDP hoặc CNP |
| B8 | **Cosign vẫn WARN mode** — chưa cưỡng chế image signing | 1800-35 §5.3 | policy-controller chạy nhưng chỉ cảnh báo | Theo roadmap A10: ký đủ 100% image rồi chuyển ENFORCE |

---

## C. Thiếu về hạ tầng / phần cứng (đối chiếu 1800-35 §3.5)

NIST 1800-35 §3.5 mô tả physical architecture chuẩn của lab NCCoE. So với đó, hệ thống hiện thiếu (hoặc chưa được tài liệu hóa):

| # | Thiếu gì | Ghi chú |
|---|----------|---------|
| C1 | **Management network tách biệt**: NIST lab có management domain riêng cho quản trị thiết bị. Hiện SSH/quản trị đi chung Tailscale mesh với data traffic | Chấp nhận được ở quy mô lab, nhưng cần ghi nhận là hạn chế trong Ch4 §7 |
| C2 | **HA cho các thành phần PDP/PA**: NIST §5 cảnh báo DoS lên policy components (threat §5.2). Hiện single replica cho Keycloak, Vault, spire-server, kong, zta-pdp — bất kỳ pod nào chết là mất khả năng cấp quyết định | Không đủ RAM để chạy HA (15.5 GiB tổng) — ghi nhận hạn chế + nêu phương án scale |
| C3 | **Tài nguyên giám sát chịu tải**: ES single node, không có alerting (Alertmanager chưa có) — SIEM function (data source #8) chỉ đạt mức thu thập, chưa đạt mức cảnh báo | Bổ sung Alertmanager hoặc ghi nhận hạn chế |
| C4 | **Backup/DR cho policy store và Vault**: NIST threat §5.5 (storage of system info) yêu cầu bảo vệ chính nơi lưu policy/secrets. Chưa có backup etcd/Vault snapshot định kỳ được tài liệu hóa | Thêm CronJob `etcdctl snapshot` + `vault operator raft snapshot`, hoặc ghi nhận hạn chế |
| C5 | **Sơ đồ topology vật lý** (trùng A8): chưa có diagram node ↔ Tailscale IP ↔ workload placement trong cả repo lẫn luận văn | Vẽ 1 diagram (draw.io/tikz) dùng chung cho Ch3 và tài liệu vận hành |

---

## Tóm tắt ưu tiên

- **P0 (làm trước):** A1, A5 (Ch1 — data sources + threats), A14/B6 (latency), B1+B2 (đóng vòng lặp PDP: sửa Trivy scan → có VulnerabilityReports → PDP gán nhãn), B3 (apply policy đã migrate)
- **P1:** A2, A3, A8, A9, A11, A12, A13, A16, B4, B5
- **P2:** A4, A6, A7, A10, A15, B7, B8, C1–C5

**Việc trên cluster cần anh chạy (theo thứ tự):**
1. `bash scripts/zta-audit-and-remediate.sh --apply` → gửi log (xử lý B3, chẩn đoán B5)
2. `kubectl describe pod -n security-cdm -l app.kubernetes.io/name=trivy-operator` + describe 1 scan pod Init fail → gửi output (xử lý B1/B2)
3. `bash scripts/zta-latency-benchmark.sh enforced` → gửi kết quả (xử lý A14/B6)
