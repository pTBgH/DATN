# Hướng dẫn nhất quán nội dung xuyên suốt Đồ án

## Mục tiêu tổng thể

Đồ án chứng minh rằng kiến trúc Zero Trust (ZTA) chuẩn NIST SP 800-207 có thể được hiện thực hóa cho hệ thống Microservices trên Kubernetes bằng một hệ sinh thái công nghệ mã nguồn mở, thông qua case study hệ thống tuyển dụng JOB7189.

---

## Cấu trúc logic 3 chương: Tại sao → Cái gì → Như thế nào

| Chương | Vai trò | Nội dung cốt lõi | Kết nối |
|--------|---------|-------------------|---------|
| **Chương 1** | **TẠI SAO** — Nền tảng lý thuyết | Mô hình cũ hỏng ở đâu → ZT là gì → NIST 800-207 định nghĩa kiến trúc logic (PE/PA/PEP) → 3 hướng triển khai → Ánh xạ sang công nghệ thực tế → Mô hình đe dọa | Chương 1 chỉ nói lý thuyết thuần, KHÔNG đề cập Kubernetes/Cilium/Vault cụ thể (trừ phần ánh xạ cuối cùng). Kết thúc bằng "cầu nối" sang Chương 2. |
| **Chương 2** | **CÁI GÌ** — Thiết kế kiến trúc | Thách thức bảo mật riêng của Microservices/K8s → Đề xuất khung 5 lớp ZTA → Mô hình chính sách ABAC → **Quy trình triển khai 4 giai đoạn** | Chương 2 đề xuất giải pháp trên giấy, chọn công nghệ cụ thể (Cilium, Vault, Kong, Keycloak, EFK), và đề ra lộ trình triển khai tuần tự (Chuẩn bị → Thí điểm → Mở rộng → Cải tiến). KHÔNG có code/YAML chi tiết. Kết thúc bằng "cầu nối" sang Chương 3. |
| **Chương 3** | **NHƯ THẾ NÀO** — Triển khai thực nghiệm | Mô tả hệ thống JOB7189 → Hiện thực hóa từng lớp bằng code/YAML/script thực tế | Chương 3 là bằng chứng thực nghiệm, toàn bộ nội dung dựa trên mã nguồn thật (bash scripts, YAML manifests, Helm charts). |

---

## Quy tắc tránh trùng lặp

### PE / PA / PEP (Policy Engine / Administrator / Enforcement Point)
- **Định nghĩa chính thức duy nhất:** Chương 1, mục 1.2 (Các nguyên lý cốt lõi ZTA → Mô hình logic bắt buộc).
- **Chương 2:** Chỉ **tham chiếu ngược** ("Như đã trình bày ở Chương 1, PE đóng vai trò..."), KHÔNG định nghĩa lại. Tập trung vào CÁCH ánh xạ PE→OPA/Keycloak, PA→Vault, PEP→Kong+Cilium+Tetragon.
- **Chương 3:** Chỉ trình bày code cụ thể hiện thực hóa từng thành phần.

### 7 Tenets (7 nguyên lý)
- **Liệt kê đầy đủ:** Chỉ ở Chương 1, mục 1.2.1.
- **Chương 2 & 3:** Tham chiếu từng tenet khi cần (ví dụ: "Theo Tenet 3 — per-session access, Vault cấp credential TTL 1h").

### Khái niệm North-South / East-West
- **Giới thiệu:** Chương 2, mục 2.1.1 (Đặc điểm Microservices).
- **Áp dụng cụ thể:** Chương 3 (Kong xử lý North-South, Cilium Policy xử lý East-West).

### Threat Modeling
- **Lý thuyết chung:** Chương 1, mục 1.4 (Attack Surface, MITRE ATT&CK).
- **Thách thức riêng K8s:** Chương 2, mục 2.1.5 (Thách thức triển khai ZTA trên K8s).
- **Baseline cụ thể JOB7189:** Chương 3, mục 3.1.2 (Security Posture Baseline).

---

## Thuật ngữ thống nhất

| Thuật ngữ | Viết tắt | Lần đầu xuất hiện |
|-----------|----------|-------------------|
| Zero Trust Architecture | ZTA | Chương 1, mục 1.1.3 |
| Policy Engine | PE | Chương 1, mục 1.2.2 |
| Policy Administrator | PA | Chương 1, mục 1.2.2 |
| Policy Enforcement Point | PEP | Chương 1, mục 1.2.2 |
| Attribute-Based Access Control | ABAC | Chương 2, mục 2.4.1 |
| Mutual TLS | mTLS | Chương 2, mục 2.1.2 |
| Just-In-Time credentials | JIT | Chương 2, mục 2.3.4 |
| Time To Live | TTL | Chương 2, mục 2.3.4 |

---

## Mạch truyện xuyên suốt (Narrative Thread)

1. **Mở đầu (Chương 1):** Mô hình "Lâu đài & Hào nước" đã thất bại → SolarWinds chứng minh → NIST đề ra Zero Trust → 7 nguyên lý + kiến trúc PE/PA/PEP → 3 hướng triển khai → ZT là hệ sinh thái, không phải sản phẩm → Ánh xạ sơ bộ sang công nghệ CNCF → Mô hình đe dọa.

2. **Phát triển (Chương 2):** Microservices có những thách thức bảo mật riêng (East-West, ephemeral, secrets, shared infra) → Kubernetes làm vấn đề phức tạp thêm (PEP placement, identity, sidecar tax, observability) → Đề xuất khung 5 lớp (Identity, Posture, Enforcement, Secrets, Observability) → Mô hình chính sách ABAC + Deny-All/Allow-Explicit → **Quy trình triển khai 4 giai đoạn** (Chuẩn bị → Thí điểm → Mở rộng → Cải tiến liên tục) theo NIST SP 800-207 Mục 7.

3. **Chứng minh (Chương 3):** Hệ thống JOB7189 (7 services, 5 namespace) → Trước ZTA: flat network, static creds → Sau ZTA: Keycloak OIDC + Vault JIT + Kong JWT + Cilium L3-L7 Policy + EFK → Code thực tế từ 5 bash scripts → Kết quả.

---

## Checklist nhất quán

- [ ] Không có "Ghi chú: Bạn có muốn mình..." trong bất kỳ chapter nào
- [ ] PE/PA/PEP chỉ được định nghĩa đầy đủ 1 lần (Chương 1)
- [ ] Không có ALL CAPS trong tiêu đề subsection
- [ ] Mỗi section kết thúc bằng `\cite{}` thay vì "Nguồn trích dẫn:" bullet list
- [ ] Tất cả figure đều có `\label{}` và được `\ref{}` trong văn bản
- [ ] Không có placeholder text kiểu "[Hình ảnh minh họa: ...]" (trừ Chương 3 đã xử lý riêng)

---

## Cầu nối giữa các chương

### Cuối Chương 1 → Chương 2
> "Chương 1 đã xác lập nền tảng lý luận về kiến trúc Zero Trust và ánh xạ sơ bộ các thành phần logic NIST sang công nghệ mã nguồn mở. Tuy nhiên, việc triển khai ZTA trong môi trường Microservices đặt ra những thách thức đặc thù mà lý thuyết chung chưa thể giải đáp. Chương 2 sẽ phân tích những thách thức này và đề xuất một khung kiến trúc ZTA 5 lớp cụ thể."

### Cuối Chương 2 → Chương 3
> "Chương 2 đã hoàn tất việc thiết kế khung kiến trúc Zero Trust 5 lớp và quy trình triển khai 4 giai đoạn trên phương diện lý thuyết. Chương 3 sẽ chứng minh tính khả thi của khung kiến trúc này thông qua việc triển khai thực nghiệm trên hệ thống tuyển dụng JOB7189 — một ứng dụng Microservices gồm 7 backend service vận hành trên cụm Kubernetes 4 node — theo đúng lộ trình 4 giai đoạn đã đề xuất."
