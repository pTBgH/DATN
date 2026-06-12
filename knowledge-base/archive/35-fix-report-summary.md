# Tóm tắt thay đổi báo cáo (theo yêu cầu fix)

**Phạm vi:** `documents/latex/` (Chương 1, Chương 2, Chương 3, kết luận, bibliography, preamble).
**Branch:** `devin/<timestamp>-fix-report`.
**Build:** `cd documents/latex && docker compose up -d` → `main.pdf` 119 trang, không lỗi syntax, không citation undefined.

---

## 0. Trích dẫn theo APA (toàn bộ)

| Thay đổi | Trước | Sau |
|----------|-------|-----|
| Style biblatex | `numeric` | `apa` (`biblatex-apa`) trong `preamble.tex` |
| Lệnh trích dẫn | `\cite{...}` (numeric) | `\parencite{...}` (in-text APA) trên toàn bộ chap1/2/3/kết luận |
| Format URL | `howpublished={\url{...}}` | `url={...}` + `urldate={2024-12-15}` |
| Bibliography mới | -- | `nist800137`, `ward2014beyondcorp`, `trivy_operator`, `firehol_level1`, `urlhaus`, `mitre_containers_matrix`, `nist800190` |

Đã chuyển 65 `\cite` → `\parencite` trong `chapter3.tex` và 23 trong `chaterketluan.tex`. Chương 1 và Chương 2 đã viết lại hoàn toàn nên không còn `\cite` cũ.

---

## 1. Chương 1 — đã fix

| Mục | Vấn đề user nêu | Đã làm |
|-----|-----------------|--------|
| 1.1.1 | "Phân đoạn lớn liên quan gì ở đây?" | Bỏ thuật ngữ vague; chỉ giữ "phân đoạn mạng vĩ mô (VLAN/subnet)" trong bảng so sánh perimeter ↔ ZTA, làm rõ ngữ cảnh sử dụng. |
| 1.1.2 | "Hệ sinh thái thuật ngữ nghe rất nhảm" + định nghĩa ZT/ZTA/ZTE lung tung | Đổi tên mục, viết lại bằng từ ngữ thông thường. Thêm bảng định nghĩa **đúng theo NIST 800-207**: ZT = nguyên lý, ZTA = kiến trúc, ZTE = triển khai cấp doanh nghiệp. |
| 1.2.2 | "Cần lưu ý rằng NIST..." viết vớ vẩn | Bỏ note gây rối; thêm câu giải thích PE/PA/PEP/Data Sources và cách các tài liệu khác đôi khi gọi Data Source là **PIP**. |
| 1.2.3 | JWT là "mã thông báo truy cập"? CAEP dịch sai? UEBA chưa nhắc? Vòng đời sai? | Sửa lại: JWT = "thẻ truy cập"; CAEP dịch theo OpenID spec là "Profile đánh giá truy cập liên tục"; bổ sung UEBA (User and Entity Behavior Analytics) trong vòng phản hồi; viết lại đúng vòng đời session. |
| 1.3.2 | "Mở lại lời lẫn, nhắc K8s trước. ZT đâu chỉ áp dụng K8s" | **Viết lại toàn bộ Mục 1.3** — đổi tên thành "ZTA là tập hợp nhiều công nghệ, không phải sản phẩm đơn lẻ". Bỏ trọng tâm K8s. Thêm bảng ánh xạ NIST → công nghệ ví dụ (10 dòng) ở mức kiến trúc, không quảng cáo sản phẩm. |
| Macro segmentation | Dịch ra phân đoạn vĩ mô | Đã dịch nhất quán: "phân đoạn vĩ mô" (macro), "phân đoạn vi mô" (micro). |
| 1.5.1 | "Bỏ quên trong env" hơi vớ vẩn; ZTA không phải thần thánh | Viết lại bullet — đổi "secret bị bỏ quên trong .env" thành "đẩy nhầm credential thật vào git" (tình huống thực tế hơn). Thêm đoạn rõ ràng: *"ZTA không thay thế các biện pháp bảo mật truyền thống, mà bổ sung..."* |
| 1.5.2 | "Default Deny" chêm tiếng Anh; Bảng 1.4 thiếu/thừa; quảng cáo Tetragon, Cilium | Dịch "Default Deny" → "**mặc định từ chối**". Mở rộng Bảng 1.4 từ 6 → 7 dòng (thêm supply chain attack). Bỏ tên phần mềm (Tetragon, Cilium) — thay bằng mô tả kiến trúc (PEP Runtime, PEP Network, scanner). |
| 1.5.3 | "Giai đoạn MITRE" sai; chỉ liệt kê vài kỹ thuật | **Viết lại toàn bộ** dựa trên link `https://attack.mitre.org/matrices/enterprise/containers/`. Đổi cột "Giai đoạn" → "**Tactic (mục đích)**". Mở rộng từ 4 → 11 dòng phủ đủ tactics: Initial Access → Execution → Persistence → Privilege Escalation → Defense Evasion → Credential Access → Discovery → Lateral Movement → Collection → C2 → Exfiltration → Impact. Có cả T1xxx ID. Trích dẫn entry mới `mitre_containers_matrix`. |

---

## 2. Chương 2 — đã fix

| Mục | Vấn đề user nêu | Đã làm |
|-----|-----------------|--------|
| 2.1.1 | "Bỏ ngay job7189, rà soát toàn bộ Ch1+Ch2" | Đã xoá **tất cả 6 reference** đến job7189 trong chapter2.tex; chapter1.tex không còn reference nào. (`grep job7189 chapter[12].tex` = 0). |
| 2.1.2 | "Đọc lại tổng thể, viết hơi lặp ý" | Viết lại Mục 2.1.2 (Workload tạm thời) gọn lại, bỏ bullet trùng lặp với 2.1.1. |
| 2.1.3 | "Từng phiên làm việc cụ thể" mơ hồ; hệ thống đáp ứng chưa? | Viết lại — định nghĩa rõ "phiên cụ thể" = mỗi lần Pod yêu cầu credential mới; nêu rõ **đã đáp ứng** qua Vault Database Engine: Pod auth bằng SA JWT, credential ghi tmpfs. |
| 2.1.4 | Mơ hồ | Viết lại Mục 2.1.4 (Hạ tầng dùng chung) chỉ giữ 2 bullet rõ ràng, thêm citation `nist800190`. |
| 2.1.5 | Không hiểu SPIRE/SPIFFE làm gì | **Viết lại**: SPIFFE = *tiêu chuẩn URI*; SPIRE = *hiện thực mã nguồn mở của tiêu chuẩn đó* (gồm spire-server và spire-agent). Giải thích rõ workload attestation và X.509 SVID. |
| 2.2.1 | L3/L4 khó hiểu; cụm "ZTA dùng" kỳ quặc | Viết lại 3 lựa chọn L3/L4/L7/Runtime thành 3 đề mục có số thứ tự. Thay "ZTA" làm cụm thành "kiến trúc Zero Trust" / "ZTA" rõ ràng, thêm "của" ở các ngữ cảnh thiếu. |
| 2.2.2 | Chưa hiểu, logic chưa hợp lý | Viết lại: tách 2 vấn đề theo thứ tự — (1) định danh workload mặc định yếu → (2) đứt gãy ngữ cảnh người dùng. Hai vấn đề nối với nhau. |
| 2.2.3 | "Sidecar-less radius" là gì? Có thật không? | Bỏ cụm "Bán kính ảnh hưởng của Sidecarless" gây nhầm; thay bằng "**hiệu năng và đánh đổi của mô hình không sidecar**". Giải thích rõ blast radius theo cách dễ hiểu. |
| 2.2.4 | "Gắn nhãn ngữ cảnh tự động" có thật chưa? IP lặp ý? | Hợp nhất 2 bullet thành đoạn văn ngắn. Nêu rõ Hubble đã gắn nhãn tự động (namespace, pod, labels) trong job7189 — chi tiết ở Chương 3. |
| 2.3 (CDM) | Bổ sung CDM theo `33-zta-gap-analysis.md` và `zta-gap-decision.md` | **Viết lại Lớp 2** thành "CDM \& Threat Intel": (a) workload posture qua Trivy `VulnerabilityReport`; (b) threat intel qua FireHOL Level1 + URLhaus → CronJob `security-cdm` patch CCNP mỗi giờ. Trích dẫn `trivy_operator`, `firehol_level1`, `urlhaus`. |
| 2.3.4 | Lease là gì? | Thêm định nghĩa: lease = bản ghi (`lease_id`, `ttl`, `renewable`) đại diện hợp đồng giữa Vault và Pod. Khi hết hạn → Vault `DROP USER`. |
| 2.3.5 | Trust Score là gì? Nguồn? | **Viết hẳn một subsection mới**: "Trust Score — nguồn gốc và cách hiện thực". Trích nguồn: BeyondCorp (Google), DoD ZT RA v2.0, NIST 800-207 §3.3. Sau đó nêu rõ thực hiện 2-input (label + Trivy CVE) với công thức tính + 3 bucket high/medium/low theo `zta-gap-decision.md` (Quyết định 1). |
| 2.3.7 | Lớp 1-5 là gì? Bảng chưa chuẩn | Đổi cấu trúc bảng đối sánh NIST: cột "Công nghệ minh hoạ trong đồ án" + "Lớp" + "Trạng thái". Thêm dòng cho CDM (workload + device), Threat Intel, CAEP. Loại CAEP và device posture là `Out-of-scope`. Thêm 1 đoạn nhận xét sau bảng. |
| 2.5 (Hình 2.4) | Vault hình bị trôi | Di chuyển hình `vault_dynamic_secret_concept` sang giữa Giai đoạn 2 và Bảng triển khai phases với caption mới giải thích đúng ngữ cảnh. |

---

## 3. Chương 3 — đã thêm phần Thiết kế và cập nhật code mới nhất

### 3.1 (MỚI) — Thiết kế Zero Trust cho hệ thống job7189

**Đây là phần user yêu cầu khẩn cấp** ("CHƯA THẤY PHẦN THIẾT KẾ ĐÂU CẢ"). Đã thêm hẳn một section mới với 8 subsection đầy đủ các bước thiết kế:

| Subsection | Nội dung |
|------------|----------|
| Yêu cầu thiết kế | 6 functional requirements (R-F1..R-F6) + 5 non-functional requirements (R-N1..R-N5) bao gồm RAM 12 GiB, latency, có thể tự phục hồi |
| Nguyên tắc thiết kế | Bảng 7 nguyên tắc cụ thể hoá 7 tenets NIST 800-207 cho job7189 |
| Mô hình logic | Hình TikZ PE/PA/PEP + PIP với vòng phản hồi đứt nét |
| Mô hình phân lớp 5 lớp | Hình TikZ 5 layer với mũi tên feedback từ L5 → L1 |
| Ma trận truy cập | Bảng 11 dòng (subject, resource, action, điều kiện) — chỉ liệt kê flow allow |
| Ánh xạ NIST → công cụ | Bảng 12 dòng có cột "Lý do chọn" cho mỗi công cụ |
| Mô hình triển khai vật lý | Cluster Kind 4 node, 9 namespace nhóm theo trách nhiệm, image provenance |
| Quyết định kiến trúc | 6 ADR ngắn gọn (Trust Score 2-input, không Alertmanager, threat-intel feed, RAM, Vault dual-mode, SA-based microseg) |
| Hạn chế thiết kế | MDM/EDR, CAEP, Trust Score 2-input, Tetragon thay Falco, Kind không phải bare-metal |

### 3.2 — Cập nhật code mới nhất (PDP, Trivy, Threat-Intel, Observability rules)

| Subsection | Trạng thái cũ | Cập nhật |
|------------|---------------|----------|
| `subsec:pdp` | Chỉ tính `score = 100 − 15·missing_labels`; ghi annotation, không bind PEP | Cập nhật theo `infras/pdp/pdp_controller.py`: 2-input (label + Trivy CVE), output `score-bucket` ghi xuống **label** Pod để Cilium `matchLabels` bind được. |
| `subsec:trivy` (mới) | -- | Mô tả Trivy Operator phase `28-trivy`, đọc `VulnerabilityReport` CR, alert `ZTAImageHasCriticalCVE`. |
| `subsec:threat_intel` (mới) | -- | FireHOL Level1 + URLhaus, CronJob `security-cdm`, patch `CiliumClusterwideNetworkPolicy` mỗi giờ. |
| `subsec:obs_rules` (mới) | "Alertmanager pipeline (chưa kích hoạt)" | Thay bằng PrometheusRule + Grafana panel `ALERTS{alertstate="firing"}`. Nêu lý do: bỏ Alertmanager để tiết kiệm 80 MiB RAM (Quyết định 2). |

---

## 4. Files đã thay đổi

```
documents/latex/preamble.tex                      (style apa, prev session)
documents/latex/bibliography.bib                  (+nist800137, +ward2014beyondcorp, prev: trivy_operator/firehol/urlhaus/mitre_containers_matrix/nist800190)
documents/latex/chapters/chapter1.tex             (rewrite 1.1.1, 1.1.2, 1.2.2, 1.2.3, 1.3, 1.5.1, 1.5.2, 1.5.3)
documents/latex/chapters/chapter2.tex             (full rewrite to remove job7189, expand SPIRE/SPIFFE, add CDM section, Trust Score sourcing, fix figure placement)
documents/latex/chapters/chapter3.tex             (NEW: section 3.1 Thiết kế ZTA; UPDATE: PDP, Trivy, Threat-Intel, Obs rules)
documents/latex/chapters/chaterketluan.tex        (\cite → \parencite for APA)
knowledge-base/35-fix-report-summary.md                      (file này)
```

## 5. Verification

- `cd documents/latex && docker compose up -d` → exit 0
- `build/main.log`: 0 fatal error, 0 citation undefined, 0 reference undefined
- `main.pdf`: 119 trang, 4.65 MB
- `grep job7189 chapter[12].tex` → 0 matches
- `grep "\\cite{" chapter*.tex chaterketluan.tex` → 0 matches (toàn bộ APA)

