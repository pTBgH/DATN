# Gap Analysis: LaTeX Chapters vs NIST SP 800-207 & SP 1800-35

**Ngày:** 2026-06-12  
**Phạm vi:** So sánh 4 chương `documents/latex/chapters/` + `chaterketluan.tex` với hai tài liệu gốc NIST SP 800-207 (Zero Trust Architecture) và NIST SP 1800-35 (Implementing a Zero Trust Architecture).

---

## Tổng quan phương pháp

Mỗi chương được đối chiếu theo 3 trục:
1. **Nội dung thiếu (Missing)** — khái niệm/mục quan trọng trong NIST mà chương chưa đề cập.
2. **Nội dung chưa chính xác hoặc thiếu chiều sâu (Incomplete/Inaccurate)** — đã đề cập nhưng chưa đúng hoặc thiếu so với NIST.
3. **Nội dung cần bổ sung hạ tầng/kỹ thuật (Infra Gap)** — thiết kế/mã chưa triển khai để khớp với cam kết trong văn bản.

---

## Chương 1 — Tổng quan về Kiến trúc Zero Trust

### Đã làm tốt
- 7 tenets NIST SP 800-207 §2.1 — đầy đủ.
- Phân biệt ZT / ZTA / ZTE đúng theo NIST §2.
- Kiến trúc logic PE/PA/PEP/PIP đúng theo NIST §3 Figure 2.
- Trust algorithm 2 trục phân loại đúng theo NIST §3.3.
- CISA ZTMM 2.0 (5 pillars, 4 maturity levels) chính xác.

### Gap 1.1 — Thiếu hoàn toàn phần "Data Sources / Supporting Components" (NIST §3, Figure 2)

**NIST 800-207 §3 liệt kê 7 data sources / supporting components:**
1. CDM system (Continuous Diagnostics & Mitigation)
2. Industry compliance system
3. Threat intelligence feed(s)
4. Network and system activity logs
5. Data access policies
6. Enterprise PKI
7. ID management system
8. SIEM system

**Hiện trạng chương 1:** Chỉ nêu PE, PA, PEP, PIP nhưng **không liệt kê chi tiết 7+ data sources** mà NIST mô tả là đầu vào cho PE. Đây là phần quan trọng vì nó giải thích *PE lấy dữ liệu từ đâu* để ra quyết định.

**Khuyến nghị:** Thêm bảng/danh sách 7 data sources (1 đoạn ngắn) ngay sau mục 1.2.2 (PIP), trích dẫn NIST §3 Figure 2.

### Gap 1.2 — Thiếu phần "Deployed Variations" (NIST §3.2)

**NIST 800-207 §3.2 mô tả 4 mô hình triển khai cụ thể:**
1. Device Agent/Gateway-Based (§3.2.1)
2. Enclave-Based (§3.2.2)
3. Resource Portal-Based (§3.2.3)
4. Device Application Sandboxing (§3.2.4)

**Hiện trạng:** Chương 1 §1.2.4 liệt kê 4 "hướng tiếp cận" (EIG, Microsegmentation, SDP, SASE) — đây là **deployment approaches** (§3.1), KHÔNG phải **deployment variations** (§3.2). Hai khái niệm khác nhau trong NIST nhưng chương 1 gộp/nhầm lẫn:
- §3.1 = *approaches* (EIG, Micro-seg, SDP) — cách tổ chức chính sách
- §3.2 = *variations* (Agent/Gateway, Enclave, Portal, Sandbox) — cách đặt PEP vào hạ tầng

**Khuyến nghị:** Tách rõ 2 mục: (a) Approaches = §3.1 (đã có ở §1.2.4), (b) Bổ sung Deployed Variations = §3.2 với mô tả ngắn 4 mô hình. Quan trọng vì chương 3 dùng mô hình Agent/Gateway (Cilium agent trên mỗi node) — cần có cơ sở lý thuyết ở chương 1.

### Gap 1.3 — Thiếu phần "Network/Environment Components" & "Network Requirements" (NIST §3.4)

NIST §3.4 bàn về yêu cầu hạ tầng mạng cho ZTA: tách control plane vs data plane, yêu cầu mã hóa mọi lưu lượng, PKI enterprise, v.v. Chương 1 hoàn toàn không đề cập control plane vs data plane separation — một khái niệm nền tảng cho thiết kế ở chương 3.

**Khuyến nghị:** Thêm 1 đoạn ngắn về network requirements (control/data plane separation, encryption all traffic).

### Gap 1.4 — Thiếu phần "Deployment Scenarios / Use Cases" (NIST §4)

NIST §4 mô tả 5 deployment scenarios:
1. Enterprise with Satellite Facilities
2. Multi-cloud/Cloud-to-Cloud
3. Contracted Services / Nonemployee Access
4. Collaboration Across Enterprise Boundaries
5. Public-/Customer-Facing Services

Chương 1 không đề cập. Điều này quan trọng vì hệ thống job7189 rơi vào **scenario 5** (Public-Facing Services) — cần nêu ở lý thuyết để biện luận lựa chọn kiến trúc.

**Khuyến nghị:** Thêm 1 bảng tóm tắt 5 scenarios, đánh dấu scenario áp dụng cho đồ án.

### Gap 1.5 — Thiếu phần "Threats Associated with ZTA" (NIST §5)

NIST §5 liệt kê 7 mối đe dọa đặc thù cho hệ thống ZTA:
1. Subversion of ZTA Decision Process
2. DoS / Network Disruption
3. Stolen Credentials / Insider Threat
4. Visibility on the Network
5. Storage of System and Network Information
6. Reliance on Proprietary Data Formats
7. Use of Non-person Entities in ZTA Administration

**Hiện trạng:** Chương 1 hoàn toàn không đề cập threats riêng của ZTA. Chương 2 phân tích MITRE ATT&CK cho containers (tốt), nhưng đây là **threats chung cho K8s** chứ không phải **threats riêng cho ZTA** theo NIST §5.

**Khuyến nghị:** Thêm 1 mục (hoặc bảng) tóm tắt 7 threats theo NIST §5 ở cuối chương 1, trước cầu nối sang chương 2.

### Gap 1.6 — Thiếu phần "Migration Steps" (NIST §7)

NIST §7.3 mô tả 7 bước migration:
1. Identify Actors
2. Identify Assets
3. Identify Key Processes / Evaluate Risks
4. Formulate Policies
5. Identify Candidate Solutions
6. Initial Deployment and Monitoring
7. Expanding the ZTA

**Hiện trạng:** Chương 2 §2.6 có bảng 7 bước nhưng **đặt sai chương** (thuộc lý thuyết NIST, nên nằm ở chương 1 hoặc ít nhất cần tham chiếu chéo).

**Khuyến nghị:** Nên giữ bảng 7 bước ở cuối chương 1 (hoặc đầu chương 2 với ghi chú đây là roadmap NIST). Hiện nó nằm cuối chương 2 — vị trí hợp lý nhưng cần reference rõ NIST §7.3.

### Gap 1.7 — Thiếu NIST SP 1800-35 Reference Architecture Operations (Resource Mgmt, Session Initiation, Session Mgmt)

NIST SP 1800-35 §3.1 mô tả 3 quy trình vận hành kiến trúc ZTA:
- R() — Resource Management steps
- I() — Session Initiation steps (I(1)..I(5))
- S() — Session Management steps

Đây là quy trình **vận hành** kiến trúc, mô tả cách PDP/PEP hoạt động theo thời gian thực. Chương 1 chỉ nêu các thành phần tĩnh mà không mô tả luồng vận hành.

**Khuyến nghị:** Thêm 1 mục ngắn mô tả 3 process groups từ NIST 1800-35 §3.1, vì đây là cơ sở để thiết kế luồng runtime ở chương 3.

---

## Chương 2 — Ứng dụng Zero Trust bảo mật hệ thống Microservices

### Đã làm tốt
- Phân tích bề mặt tấn công MITRE ATT&CK Container Matrix — rất tốt, chi tiết.
- Khung 5 thành phần logic — ánh xạ rõ ràng sang PE/PA/PEP/PIP.
- Trust Score formula với biện luận toán học.
- Bảng mapping thành phần ↔ NIST ↔ Công nghệ ↔ Rủi ro.
- ABAC policy model.

### Gap 2.1 — Thiếu "Assumptions for ZTA Network" (NIST §2.2)

NIST §2.2 liệt kê 6 giả định nền tảng cho mạng ZTA:
1. Enterprise private network is NOT implicit trust zone
2. Devices may not be owned/configurable by enterprise
3. No resource inherently trusted
4. Not all resources on enterprise infrastructure
5. Remote subjects cannot trust local network
6. Consistent security policy across enterprise/nonenterprise

Chương 2 nêu thách thức K8s nhưng **không ánh xạ ngược về 6 assumptions** của NIST. Nên thêm 1 bảng mapping 6 assumptions → hiện thực K8s tương ứng.

### Gap 2.2 — Thành phần 1 (Identity) thiếu "Enterprise PKI" role

NIST §3 liệt kê Enterprise PKI là data source riêng biệt. Chương 2 đề cập SPIRE/SVID nhưng không nêu rõ vai trò của **cert-manager** (TLS certificate management) như một Enterprise PKI component. Thực tế hệ thống có `cert-manager` namespace nhưng chương 2 không đề cập.

**Khuyến nghị:** Bổ sung cert-manager vào bảng mapping (Tab 2.5) ở cột Identity/PKI.

### Gap 2.3 — Thành phần 2 (Posture) thiếu "Industry Compliance System" data source

NIST §3 liệt kê "Industry compliance system" — đảm bảo tuân thủ regulatory. Chương 2 chỉ nói Trivy (CVE) + Gatekeeper (labels) nhưng thiếu khái niệm compliance scanning (kube-bench CIS Benchmark). Đây là gap đã biết từ `33-zta-gap-analysis.md` nhưng chưa được phản ánh trong chương 2.

### Gap 2.4 — Thành phần 5 (Observability) thiếu "SIEM" role rõ ràng

NIST §3 yêu cầu SIEM as data source for PE. Chương 2 nêu "thu thập log tập trung" nhưng không gọi tên SIEM role. Thực tế EFK (Elasticsearch) đóng vai trò SIEM nhưng cần được ánh xạ rõ ràng.

### Gap 2.5 — Lộ trình chuyển đổi §2.6 thiếu liên kết với NIST §7.3

Bảng 7 bước trong §2.6 nêu nội dung đúng nhưng:
- Thiếu sub-section number reference đến NIST §7.3.1-7.3.7
- Thiếu đề cập "Hybrid ZTA" (NIST §7.2) — hầu hết tổ chức sẽ vận hành hybrid

### Gap 2.6 — Thiếu biện luận lựa chọn "Deployment Variation" cho job7189

Chương 2 chọn Cilium agent-per-node (= Device Agent/Gateway-Based model theo NIST §3.2.1) nhưng **không biện luận tại sao chọn model này** thay vì Enclave-Based hoặc Resource Portal-Based. NIST 1800-35 §3.4 mô tả Microsegmentation approach uses "gateway security components and/or software agents on endpoint assets" — cần biện luận rõ đây là host-based microsegmentation.

---

## Chương 3 — Triển khai thực nghiệm

### Đã làm tốt
- Cấu trúc rõ ràng theo 5 thành phần.
- Mô tả chi tiết kỹ thuật: Keycloak Dual-Realm, SPIRE attestation, Cilium CNP, Vault JIT, EFK.
- Pipeline 5 giai đoạn.
- Namespace isolation map.

### Gap 3.1 — CRITICAL: Thiếu hoàn toàn "Deployment/Implementation Process"

**Đây là gap lớn nhất.** Chương 3 mô tả *các thành phần* đã triển khai nhưng **không mô tả quá trình triển khai**:
- Không có mô tả thứ tự các bước cài đặt cụ thể
- Không có mô tả cách resolve dependencies giữa các thành phần
- Không mô tả quá trình chuyển từ cluster trống → ZTA đầy đủ
- Không có mapping nào giữa 7 bước NIST §7.3 → các giai đoạn triển khai thực tế

NIST SP 1800-35 §4 (Build Implementation Instructions) là toàn bộ về việc **hướng dẫn triển khai từng bước**. Chương 3 cần được mở rộng đáng kể.

**Khuyến nghị:** Thêm section mới "Quy trình triển khai chi tiết" bao gồm:
1. **Pre-flight requirements** — cấu hình phần cứng, network, kernel requirements
2. **Phase 1: Foundation** — cluster bootstrap, CNI (Cilium), cert-manager, PKI
3. **Phase 2: Identity Foundation** — Keycloak, SPIRE, Vault
4. **Phase 3: Application Deployment** — microservices, DB, messaging
5. **Phase 4: Policy Hardening** — default-deny, allow-explicit CNP, Kong JWT
6. **Phase 5: Advanced ZTA** — Cosign, Gatekeeper, Trivy, Tetragon, PDP
7. **Phase 6: Observability** — EFK, Prometheus, Grafana, Hubble
8. Mỗi phase: inputs, outputs, verify steps, rollback strategy

### Gap 3.2 — Thiếu mô tả "Discovery" phase (NIST 1800-35 §3.6, §8.1)

NIST 1800-35 nhấn mạnh **discovery** là bước đầu tiên: "Given the importance of discovery to the successful implementation of a ZTA, we initially deployed it to continuously observe the environment." Chương 3 bỏ qua hoàn toàn bước inventory/discovery — không mô tả cách xác định assets, communication flows, attack surface trước khi triển khai.

**Khuyến nghị:** Thêm mục "Khảo sát và phân loại tài sản" trước mục thiết kế, mapping NIST §7.3.1-7.3.3.

### Gap 3.3 — Thiếu mô tả "Policy Formulation" (NIST §7.3.4)

Chương 3 nêu các CNP đã deploy nhưng **không mô tả quá trình xây dựng policy**:
- Ai là actors? (user roles, service accounts) — NIST §7.3.1
- Tài sản nào cần bảo vệ? — NIST §7.3.2
- Luồng dữ liệu nào được phép? — NIST §7.3.3
- Policy rules được xây dựng dựa trên gì? — NIST §7.3.4

**Khuyến nghị:** Thêm mục mô tả quá trình phân tích luồng dữ liệu → xây dựng policy matrix → chuyển thành CNP YAML.

### Gap 3.4 — Thiếu Hardware/Infrastructure Topology chi tiết

Chương 3 §3.7 chỉ nêu "4 VMs, 15.5 GiB RAM, Tailscale" nhưng thiếu:
- Sơ đồ mạng vật lý (node placement, Tailscale mesh topology)
- Node role assignment (service → node mapping)
- Resource allocation per node
- Network diagram showing Tailscale CGNAT + Cilium VXLAN overlay

NIST 1800-35 §3.5 cung cấp **chi tiết physical architecture** bao gồm VLAN layout, firewall placement, management domain. Chương 3 cần tương tự.

### Gap 3.5 — Thiếu mô tả Control Plane vs Data Plane separation

NIST §3.4: "ZTA logical components use a separate control plane to communicate, while application data is communicated on a data plane." Chương 3 không mô tả rõ:
- Control plane: K8s API Server, Cilium operator, Hubble relay, SPIRE server
- Data plane: Pod-to-pod traffic qua Cilium eBPF

### Gap 3.6 — Cosign WARN mode chưa được giải thích đầy đủ

Chương 3 §3.5.1 nêu Cosign ở WARN mode nhưng không giải thích **roadmap chuyển sang ENFORCE**. NIST 1800-35 §5.3 nhấn mạnh endpoint compliance enforcement.

### Gap 3.7 — PDP closed-loop chưa đóng

Chương 3 §3.5.2 mô tả PDP reconcile loop nhưng:
- `PDP_CVE_INPUT=false` — không nhận input từ Trivy
- CNP block-low-trust chưa deploy ("Pending Rollout")
- Tetragon events không feed vào PDP

Đây là gap **thực thi**, không chỉ gap tài liệu.

---

## Chương 4 — Thử nghiệm và Đánh giá

### Đã làm tốt
- 10 kịch bản attack simulation chi tiết.
- Evidence từ thực tế (Hubble logs, Tetragon events, Vault agent logs).
- Bảng tổng hợp kết quả rõ ràng.
- Hạn chế thừa nhận trung thực (Cosign WARN, FireHOL chưa sync, GitOps chưa deploy).

### Gap 4.1 — Thiếu KB1 (Gateway/MFA) trong bảng tổng hợp

Bảng 4.4 tổng hợp KB2-KB10 nhưng **bỏ sót KB1** (Impossible Travel + MFA). Kịch bản 1 được mô tả chi tiết nhưng không xuất hiện trong bảng kết quả.

### Gap 4.2 — Thiếu "Functional Demonstration Methodology" theo NIST 1800-35 §6.1

NIST 1800-35 §6.1 mô tả 2 phương pháp demo: manual và automated (Mandiant MSV). Chương 4 không nêu methodology — các kịch bản là manual nhưng không nói rõ. Cần 1 đoạn ngắn mô tả phương pháp thử nghiệm.

### Gap 4.3 — Thiếu Use Cases theo NIST 1800-35 §6.2

NIST 1800-35 §6.2 định nghĩa 8 Use Cases chuẩn:
- A: Discovery and Identification
- B: Enterprise-ID Access
- C: Federated-ID Access
- D: Other-ID Access
- E: Guest No-ID Access
- F: Confidence Level
- G: Service-Service Interaction
- H: Data Level Security

Chương 4 có 10 kịch bản tự định nghĩa. **Cần ánh xạ** 10 kịch bản → 8 use cases NIST để thể hiện coverage.

### Gap 4.4 — Thiếu Performance/Latency Benchmarks

Chương 4 §4.1 nói sẽ đánh giá hiệu năng nhưng **không có kết quả latency**. `47-next-tasks.md` Item 4 xác nhận đây vẫn BLOCKED. Cần latency baseline vs enforced.

### Gap 4.5 — Thiếu "Risk and Compliance Mapping" (NIST 1800-35 §7)

NIST 1800-35 §7 yêu cầu mapping security capabilities → NIST CSF / SP 800-53. Chương 4 không có mapping nào. Đây là yêu cầu quan trọng cho academic rigor.

---

## Kết luận (chaterketluan.tex)

### Gap KL.1 — Hạn chế cần cập nhật

Danh sách hạn chế cần cập nhật:
- **Tetragon:** Kết luận nói "chưa triển khai" nhưng thực tế đã deploy v1.7.0 với Sigkill verified (theo 47-next-tasks.md). Cần cập nhật.
- **Cilium mTLS:** Nói "tạm tắt" — đúng nhưng cần nêu rõ Tailscale WireGuard đang encrypt L3 thay thế.

---

## Bảng tổng hợp Gaps và Mức ưu tiên

| # | Chương | Gap | NIST Reference | Ưu tiên | Loại |
|---|--------|-----|----------------|---------|------|
| 1.1 | Ch1 | Data Sources / Supporting Components | 800-207 §3 | P0 | Missing |
| 1.2 | Ch1 | Deployed Variations (Agent/Gateway, Enclave, Portal, Sandbox) | 800-207 §3.2 | P1 | Missing |
| 1.3 | Ch1 | Network Requirements (control/data plane) | 800-207 §3.4 | P1 | Missing |
| 1.4 | Ch1 | Deployment Scenarios | 800-207 §4 | P2 | Missing |
| 1.5 | Ch1 | Threats specific to ZTA | 800-207 §5 | P0 | Missing |
| 1.6 | Ch1 | Migration Steps placement | 800-207 §7 | P2 | Structural |
| 1.7 | Ch1 | ZTA Operations (R/I/S processes) | 1800-35 §3.1 | P2 | Missing |
| 2.1 | Ch2 | ZTA Network Assumptions | 800-207 §2.2 | P1 | Missing |
| 2.2 | Ch2 | Enterprise PKI (cert-manager) | 800-207 §3 | P2 | Incomplete |
| 2.3 | Ch2 | Industry Compliance (kube-bench) | 800-207 §3 | P2 | Missing |
| 2.4 | Ch2 | SIEM role mapping | 800-207 §3 | P2 | Incomplete |
| 2.5 | Ch2 | Migration steps NIST §7.3 reference | 800-207 §7 | P2 | Incomplete |
| 2.6 | Ch2 | Deployment Variation justification | 800-207 §3.2 | P1 | Missing |
| 3.1 | Ch3 | **Deployment process (biggest gap)** | 1800-35 §4 | **P0** | Missing |
| 3.2 | Ch3 | Discovery phase | 1800-35 §3.6, §8.1 | P0 | Missing |
| 3.3 | Ch3 | Policy formulation process | 800-207 §7.3.4 | P0 | Missing |
| 3.4 | Ch3 | Hardware/network topology detail | 1800-35 §3.5 | P1 | Incomplete |
| 3.5 | Ch3 | Control/Data plane separation | 800-207 §3.4 | P1 | Missing |
| 3.6 | Ch3 | Cosign ENFORCE roadmap | 1800-35 §5.3 | P2 | Incomplete |
| 3.7 | Ch3 | PDP closed-loop (infra gap) | 800-207 §3.3 | P0 | Infra |
| 4.1 | Ch4 | KB1 missing from summary table | — | P1 | Structural |
| 4.2 | Ch4 | Test methodology description | 1800-35 §6.1 | P1 | Missing |
| 4.3 | Ch4 | NIST Use Case mapping | 1800-35 §6.2 | P1 | Missing |
| 4.4 | Ch4 | Latency benchmarks | — | P0 | Infra |
| 4.5 | Ch4 | Risk/Compliance mapping (CSF, 800-53) | 1800-35 §7 | P2 | Missing |
| KL.1 | KL | Update limitations (Tetragon deployed, Tailscale) | — | P1 | Inaccurate |

**Tổng: 26 gaps. P0: 6, P1: 9, P2: 11.**
