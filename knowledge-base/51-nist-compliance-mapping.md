# Bảng Ánh xạ Tuân thủ Tiêu chuẩn ZTA (NIST CSF & SP 800-53 rev 5)

Tài liệu này cung cấp bảng ánh xạ chi tiết các giải pháp kỹ thuật đã triển khai trong cụm Zero Trust Laboratory của đồ án đối chiếu với các mục tiêu kiểm soát của **NIST CSF (Cybersecurity Framework)** và các biện pháp kiểm soát của **NIST SP 800-53 Rev. 5** (đối chiếu tiêu chuẩn NIST SP 1800-35 §7.2).

Bảng ánh xạ này đóng vai trò quan trọng trong Chương 4 / Chương 5 của luận văn để chứng minh tính khoa học và thực tiễn của giải pháp.

---

## 1. Ánh xạ vào danh mục kiểm soát NIST CSF (Cybersecurity Framework)

| NIST CSF Category | Subcategory | Capability kỹ thuật ZTA đã triển khai | Diễn giải thực tế trong hệ thống |
|-------------------|-------------|---------------------------------------|----------------------------------|
| **Identify (ID)**<br>Quản lý tài nguyên | **ID.AM-1**: Kiểm kê thiết bị vật lý/ảo | Kubernetes Discovery & Tailscale Engine | Quản lý vòng đời tất cả các VM Nodes và container chạy trên cụm qua K8s API và danh sách Tailscale Device Admin. |
| | **ID.AM-5**: Thiết lập phân vùng mạng | Tailscale VPN + Cilium VXLAN | Phân tách mạng LAN vật lý thành mạng overlay bảo mật và chia nhỏ phân vùng mạng logic (Namespaces). |
| **Protect (PR)**<br>Các biện pháp bảo vệ | **PR.AC-3**: Quản lý truy cập vật lý/logic | Keycloak OpenID Connect (OIDC) | Xác thực danh tính người dùng qua OIDC Flow (Access Token, ID Token), phân quyền bằng OAuth2 scopes. |
| | **PR.AC-4**: Thực thi kiểm soát truy cập | Cilium Network Policy (eBPF) + OPA | Chặn hoàn toàn lưu lượng ngang (East-West) giữa các Pod. Thực thi chính sách kiểm soát L3/L4/L7 ở mức Kernel. |
| | **PR.AC-6**: Quản lý đặc quyền tối thiểu | Vault Dynamic Credentials (JIT) | Cấp quyền kết nối Database động có thời hạn (TTL) và tự động thu hồi, ngăn ngừa lộ mật khẩu tĩnh. |
| | **PR.DS-2**: Mã hóa dữ liệu truyền tải | Tailscale WireGuard L3 + Cilium mTLS | Mã hóa toàn bộ gói tin đi giữa các node vật lý. Thực thi mã hóa mTLS ở mức Service-to-Service qua SPIRE SVIDs. |
| | **PR.DS-5**: Bảo vệ tính toàn vẹn của phần mềm | Sigstore Cosign Webhook (Gatekeeper) | Chỉ cho phép deploy ảnh container đã được ký số bởi khóa riêng tư của nhóm vận hành, chặn tải ảnh trôi nổi. |
| **Detect (DE)**<br>Phát hiện sự cố | **DE.AE-1**: Thiết lập baseline giám sát | Prometheus metrics + Hubble flows | Xây dựng baseline cho lưu lượng mạng và log hành vi hệ thống. Trực quan hóa bằng Hubble UI và Grafana. |
| | **DE.CM-1**: Giám sát an ninh mạng | eBPF Tetragon Event Stream | Giám sát liên tục các sự kiện gọi hàm hệ thống (syscalls), phát hiện thực thi file binary lạ hoặc leo thang đặc quyền. |
| | **DE.CM-8**: Quét lỗ hổng liên tục | Trivy Operator (CDM) + PDP | Định kỳ quét lỗ hổng các ảnh container đang chạy. PDP Controller tự động chấm điểm và hạ nhãn trust nếu có CVE mới. |

---

## 2. Ánh xạ vào các biện pháp kiểm soát NIST SP 800-53 Rev. 5

| Mã Kiểm Soát | Tên Biện Pháp Kiểm Soát | Giải pháp ZTA đã triển khai | Mô tả chi tiết cách thực thi trên Cluster |
|--------------|-------------------------|------------------------------|-------------------------------------------|
| **AC-2** | Account Management | Keycloak IAM Server | Quản lý tập trung tài khoản người dùng, phân quyền truy cập thông qua nhóm (Groups) và vai trò (Roles). |
| **AC-3** | Access Enforcement | Cilium CNP / Gateway PEP | Thực thi kiểm soát truy cập ở ranh giới biên (Kong API Gateway) và lõi vi phân vùng (Cilium Network Policy). |
| **AC-4** | Information Flow Enforcement | Cilium L7 Policies & mTLS | Chặn đứng luồng thông tin trái phép. Chỉ cho phép các API hợp lệ (GET/POST trên URI xác định) thông qua Envoy Proxy. |
| **AC-6** | Least Privilege | Vault Database Engine (JIT) | Hạn chế tối đa quyền hạn của Microservice. Tài khoản SQL chỉ được tạo khi dịch vụ cần gọi và tự động hủy sau 1 giờ. |
| **AC-17** | Remote Access | Tailscale WireGuard VPN | Mã hóa toàn bộ kết nối từ máy trạm của quản trị viên/lập trình viên đến cụm máy ảo thông qua giao thức WireGuard. |
| **CA-7** | Continuous Monitoring | PDP Controller + Tetragon | PDP Reconcile loop liên tục theo dõi sự thay đổi nhãn của các pod và báo cáo lỗ hổng để cập nhật điểm tin cậy thời gian thực. |
| **CP-9** | System Backup | [zta-backup-dr.sh](file:///home/ptb/projects/DATN/scripts/zta-backup-dr.sh) | Tập lệnh sao lưu tự động định kỳ, đóng gói toàn bộ chính sách bảo mật (Cilium, Gatekeeper) và bản sao lưu Secrets store của Vault. |
| **IA-2** | Identification and Authentication | Keycloak + SPIRE (SVID) | Xác thực đa nhân tố cho con người (Keycloak MFA) và định danh mật mã học cho máy (SPIRE Cryptographic Workload Attestation). |
| **IA-3** | Device Identification and Authentication | SPIRE CSI Driver | Đảm bảo mỗi Pod khi khởi động phải tự động thực hiện attestation dựa trên UUID và thuộc tính của Kernel để lấy SVID. |
| **RA-5** | Vulnerability Monitoring and Scanning | Trivy Operator | Quét liên tục các lỗ hổng của thư viện mã nguồn và hệ điều hành container, xuất báo cáo dưới dạng CRD VulnerabilityReport. |
| **SC-7** | Boundary Protection | Kong API Gateway + Cloudflare | Thiết lập biên giới bảo vệ ứng dụng (Edge PEP). Bẻ gãy các gói tin độc hại trước khi chúng đi sâu vào mạng nội bộ. |
| **SI-4** | System Monitoring | Tetragon Kernel Monitoring | Theo dõi tính toàn vẹn của tiến trình lúc chạy. Phát hiện các hành vi bất thường như Namespace Escape hay Process Injection. |

---

## 3. Tổng kết mức độ đáp ứng CISA ZTMM 2.0 (Zero Trust Maturity Model)

Dựa trên các cấu hình kỹ thuật đã chạy thực tế trên cluster, mức độ trưởng thành của hệ thống đạt được như sau:

1.  **Identity (Định danh)**: **Optimal**
    *   *Lý do*: Xác thực đa nhân tố (MFA) tích hợp Keycloak, liên kết mật mã máy (SPIRE SVIDs), kết hợp với đánh giá điểm tin cậy liên tục từ PDP Controller.
2.  **Devices (Thiết bị)**: **Advanced**
    *   *Lý do*: Attestation thiết bị thông qua SPIRE Agent chạy trên từng node vật lý, gán thuộc tính an toàn trước khi cấp SVID.
3.  **Networks (Mạng)**: **Advanced+**
    *   *Lý do*: Vi phân vùng hoàn toàn ở mức ứng dụng (Cilium eBPF), mã hóa toàn bộ đường truyền L3 (Tailscale) và L7 (mTLS).
4.  **Applications (Ứng dụng)**: **Optimal**
    *   *Lý do*: Xác thực chữ ký số ảnh container trước khi triển khai (Sigstore Cosign Webhook), API Gateway chặn ở biên, L7 CNP lọc chi tiết URI.
5.  **Data (Dữ liệu)**: **Advanced**
    *   *Lý do*: Vault bảo mật dữ liệu nhạy cảm thông qua cơ chế JIT Dynamic Credentials và mã hóa RAM ảo (tmpfs).
