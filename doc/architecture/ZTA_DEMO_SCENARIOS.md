# Kịch Bản Demo Zero Trust Architecture (ZTA) Chuyên Sâu

Tài liệu này cung cấp các kịch bản demo (Demonstration Scenarios) thực tế để chứng minh giá trị cốt lõi của **Zero Trust Architecture (ZTA)** trong hệ thống của bạn so với kiến trúc truyền thống bảo vệ theo vành đai (Perimeter-based).

> 💡 **Khái niệm then chốt:** ZTA không phải là một công cụ mua sẵn, mà là một **triết lý thiết kế** (Philosophy) bãi bỏ sự tin tưởng (Trust) mặc định dánh cho Mạng nội bộ hay IP. Nó xoay quanh "Danh tính (Identity)" làm vành đai mới.

---

## Kịch Bản 1: Đột nhập từ mạng nội bộ (Lateral Movement & Trust Assumption)

**Tình huống giả định:** Một hacker, mã độc gián điệp, hoặc một nhân viên nội bộ có quyền truy cập vào mạng VPN/Mạng LAN của công ty. Họ phát hiện được IP của các dịch vụ Backend và cố gắng gọi trực tiếp thẳng vào API (By-pass Gateway từ bên trong).

### ❌ Kiến trúc truyền thống (Không có ZTA)
- **Cách hoạt động:** Mạng nội bộ (Internal Network/K8s Cluster) được mặc định là "Vùng an toàn" (Trusted Zone). Firewalls và WAF chỉ được đặt ở lớp ngoài cùng chặn Internet. Các dịch vụ Backend thường mở cửa API không xác thực hoặc xác thực cực kỳ lỏng lẻo cho các request đến từ dải IP nội bộ `10.x.x.x`.
- **Hậu quả:** Hacker ngồi từ một máy chủ (hoặc container bị nứt) dễ dàng dùng lệnh ping và cào (crawl) toàn bộ dữ liệu hệ thống mà không vướng phải chướng ngại vật nào thắc mắc họ là ai. Hàng chục triệu bản ghi bị tuồn ra ngoài thầm lặng.

### ✅ KHI CÓ ZTA (Nguyên tắc: "Never trust, always verify")
- **Cách hoạt động:** ZTA bãi bỏ hoàn toàn "Vùng mạng an toàn". Bất kì luồng dữ liệu nào (traffic) dù đi từ ngoài Internet vào (North-South) hay gọi nhau giữa các dịch vụ trong cùng 1 máy chủ ảo (East-West) đều bị coi là **"Nghi Ngờ"**. Mọi request bắt buộc phải đi qua Điểm thực thi chính sách (Kong API Gateway kết hợp Keycloak). Phải trình diện Identity Token hợp lệ đã được ký điện tử.
- **Cách Demo:**
  1. Login vào bất cứ một máy hoặc Pod nào bên trong mạng:
     ```bash
     kubectl exec -it -n job7189-apps deploy/candidate-service -- bash
     ```
  2. Đóng vai nội gián, thử gọi trộm thẳng vào backend nội bộ mà **không có token**:
     ```bash
     curl -i http://api.thanhbinh.local/api/v1/jobs   # Hoặc gọi qua Service ClusterIP
     ```
  3. **Kết quả mỹ mãn:** Yêu cầu bị chặn đứng tàn nhẫn với mã `HTTP 401 Unauthorized` từ Gateway hoặc Oauth2 Proxy. Bạn ở đâu không quan trọng, quan trọng là bạn không có Danh Tính điện tử.

---

## Kịch Bản 2: Lấy cắp Mật khẩu Database (Static vs Ephemeral Credentials)

**Tình huống giả định:** Một Lập trình viên sơ ý đẩy (push) nhầm file `.env` lên kho lưu trữ GitHub công khai, hoặc mã độc đọc trộm được biến môi trường `DB_PASSWORD=r00t_secReT` lọt ra ngoài.

### ❌ Kiến trúc truyền thống (Không có ZTA)
- **Cách hoạt động:** Các ứng dụng thường sử dụng "Tài khoản tĩnh" (Static Credentials). Một tài khoản User DB tồn tại vĩnh viễn (nhiều năm), được cấp quyền (Grant) toàn năng (Root), và được dùng đi dùng lại trên cả chục máy chủ.
- **Hậu quả:** Hacker tìm thấy mật khẩu bị lộ. Chỉ cần có mạng luồn sâu vào hệ cơ sở dữ liệu, chúng sẽ dùng tài khoản này kiểm soát (Takeover) toàn bộ kho dữ liệu, có thể drop bảng tống tiền (Ransomware) hoặc nằm vùng sao chép dữ liệu âm thầm suốt nhiều tháng mà không ai thay pass.

### ✅ KHI CÓ ZTA (Nguyên tắc: JIT Access & Ngăn chặn bán kính nổ)
- **Cách hoạt động:** ZTA áp dụng Quản lý Mật khẩu Động (Dynamic Ephemeral Credentials - qua HashiCorp Vault). Ứng dụng không hề có mật khẩu thật. Khi ứng dụng khởi động, nó xin Vault cấp phát một tài khoản DB **tạm thời, tạo ra ngẫu nhiên (dạng `usr_xyz123`)**, có vòng đời (TTL) thu hẹp chỉ vài giờ đồng hồ.
- **Cách Demo:**
  1. Trích xuất mật khẩu mà Service Backend đang chạy thật sự:
     ```bash
     kubectl exec -it -n job7189-apps deploy/job-service -- cat /vault/secrets/.env.db
     ```
  2. Lấy thông tin `DB_USERNAME` và `DB_PASSWORD` (Ví dụ Username: `usr_abc987`). Hacker có được chuỗi mã này vui mừng ra trò.
  3. Kỹ sư SecOps ngay lập tức áp dụng **"Khoá tức thì - Panic Button"** khi nghi ngờ lộ lọt (Revoke Session):
     ```bash
     kubectl exec -n vault vault-0 -- vault lease revoke -prefix database/creds/job-service
     ```
  4. **Kết quả mỹ mãn:** Nút bấm đã lập tức xóa sổ User `usr_abc987` ra khỏi MySQL ở tầng sâu nhất. Bất kỳ nỗ lực kết nối nào bằng mật khẩu đó sẽ lập tức báo `Access Denied`. Hacker bị cắt đứt phiên ngay tắp lự. Đặc biệt: App của bạn sẽ nhận ra bị cắt, nó tự liên hệ lại Vault xin một user JIT MỚI `usr_def456` và app lại chạy tiếp bình thường, không gây sập chuyền hệ thống (Downtime).

---

## Kịch Bản 3: Mạo danh máy móc (Machine Identity Impersonation)

**Tình huống giả định:** Hệ thống của bạn có 10 microservices. Dịch vụ `communication-service` (Dùng gửi email marketing) bị hacker chèn lỗ hổng RCE (Thực thi mã từ xa) và chiếm được quyền điều khiển.

### ❌ Kiến trúc truyền thống (Không có ZTA)
- **Cách hoạt động:** Mật khẩu kết nối CSDL, API Key hệ thống thanh toán (Billing),.. thường được lưu trữ bằng Kuberenetes Secret gốc (Chỉ Base64 sơ sài). Do thói quen phân quyền tiện lợi, mọi container ở cùng một không gian (Namespace) thường có chung đặc quyền kết nối Service Account chung.
- **Hậu quả:** Từ "Bàn đạp" của Service Email, Hacker có thể quét (Scan) và gọi lệnh trích xuất toàn bộ bí mật của Service Ngân Hàng, Service Hồ sơ y tế, Cloud Storage. Khủng hoảng cục bộ biến thành sự sụp đổ toàn diện.

### ✅ KHI CÓ ZTA (Nguyên tắc: Đặc quyền Tối thiểu - Least Privilege)
- **Cách hoạt động:** ZTA cung cấp Danh tính độc lập cho Máy (Workload Identity). Mỗi Microservice sẽ có thẻ căn cước (ServiceAccount Token) riêng biệt, được ký JWT ràng buộc mạnh. Vault căn cứ đúng danh tính của Pod đó (Policy) mới cho phép mở tủ (Path).
- **Cách Demo:**
  1. Mở terminal chui vào bên trong Pod bị hack `communication-service`:
     ```bash
     kubectl exec -it -n job7189-apps deploy/communication-service -- sh
     ```
  2. Đóng vai Hacker, cố gắng mạo danh gọi API nội bộ sang Vault lấy chìa khoá bí mật `MINIO_SECRET` chuyên dụng cho `storage-service`:
     ```bash
     # Hacker cố gắng gọi hàm (hoặc dùng curl)
     # Vault kiểm tra chữ ký ở Token của communication-service
     ```
  3. **Kết quả mỹ mãn:** Trả về lỗi `403 Permission Denied`. Danh tính của Mailer hoàn toàn không có cửa (Policy) để thò tay chạm vào tủ tài liệu của Storage. Phân mảnh rủi ro (Microsegmentation Jailing) thành công rực rỡ, hacker chỉ có thể quẩn quanh ở Mailer.

---

## Kịch Bản 4: Bí mật tàng hình (No Secret on Disk - Zero Imprint)

**Tình huống giả định:** Đối thủ xâm nhập vật lý (Tháo trộm ổ cứng từ Data Center) hoặc hacker Root được máy ảo Host (Node K8s) sau đó dùng lệnh Dump File System lên các Cloud Provider.

### ❌ Kiến trúc truyền thống (Không có ZTA)
- **Cách hoạt động:** Các đoạn mã nhạy cảm (Secret, TLS Cert) thường được nạp thành các biến trực tiếp hoặc nằm chết (At Rest) trên các tệp tin lưu trên Hard Disk, Volume (HostPath, File System). Thậm chí lịch sử terminal `.bash_history` từng gõ lệnh nhúng có tồn tại.
- **Hậu quả:** Sử dụng công cụ chẩn đoán ổ cứng rà soát văn bản plain-text (strings dump, grep filesystem) tìm ra toàn bộ "vừng ơi mở ra" của công ty dù máy chủ đang TẮT. Lỗ hổng lưu trữ (Data at rest leakage).

### ✅ KHI CÓ ZTA (Nguyên tắc: Giao hàng Mật mã tận Bộ nhớ - In-Memory Secrets)
- **Cách hoạt động:** ZTA qua cơ chế Vault Agent Injector sẽ can thiệp vào quá trình đẻ ứng dụng. Bí mật từ Core Vault được truyền tải Encrypted (Mã hoá HTTPS) và tiêm trực tiếp vào khu vực bộ đệm ảo RAM (Virtual Memory) của Container theo định dạng `tmpfs`, không được ghi trượt dãi một Kilobyte nào xuống đĩa cứng (SSD/HDD).
- **Cách Demo:**
  1. Tra cứu ổ đĩa cấu hình Secret của ứng dụng đang chạy thật:
     ```bash
     kubectl exec -it -n job7189-apps deploy/identity-service -- df -h /vault/secrets
     ```
  2. **Kết quả mỹ mãn:** Cửa sổ in ra cột `Filesystem` là báo tên `tmpfs` (Temporary File System trong Linux RAM) với dung lượng cực nhỏ. Khi App bị hủy, hoặc Máy chủ bị cắt điện, tắt nguồn hoặc thu hồi (Crashed/Terminated) thì vùng RAM lập tức giải phóng (Wiped). Chìa khóa hóa thành bong bóng bốc hơi ko để lại dấu tích pháp y nào để trích xuất vật lý. 

---

## Kịch Bản 5: Cuộc tấn công trộm Token (Token Hijacking)

**Tình huống giả định:** Bằng kỹ thuật Phishing (Lừa đảo) hoặc XSS, hacker đã chôm được cục JWT Token hợp lệ đang diễn ra của người dùng "Candidate" (Ứng viên quèn).

### ❌ Kiến trúc truyền thống (Không có ZTA)
- **Cách hoạt động:** Lớp xác thực của hệ thống (Authentication) chỉ làm duy nhất một việc: Bạn có Pass/Token là nó coi bạn là "Người trong nhà" và mở cửa cho bạn xài hết những tính năng mà bạn biết API endpoint để gõ.
- **Hậu quả:** Hacker lấy Token Candidate đó, viết curl API xoá tin tuyển dụng `/api/v1/jobs/id-nhay-cam` (Thuộc quyền hạn của nhà tuyển dụng - Employer) hoặc mò vào API lấy xuất sổ sách Billing Manager. Hệ thống Backend gật đầu phê duyệt lệnh vì: "Thấy có cầm Token xịn của nhà cấp". (Chết vì thiếu kiểm tra Ủy Quyền - AuthZ).

### ✅ KHI CÓ ZTA (Nguyên tắc: Đánh giá chi tiết Phân Quyền - Fine-Grained AuthZ & Scopes)
- **Cách hoạt động:** Keycloak Role mapping hoạt động chặt chẽ ở từng thao tác. Identity JTW không phải là chiếc thẻ vạn năng (Master Key). Tại bất kì Controller/Endpoint nào trên Backend, hệ thống đều yêu cầu Giấy phép nhỏ (Scopes/Role) tương ứng với hành động đang chèn ép.
- **Cách Demo:**
  1. Mở cửa sổ lệnh, trích xuất Token của App ứng viên (Ví dụ User Role: `candidate`).
  2. Gọi thử đúng quyền hạn được giao: Lấy thông tin cá nhân.
     ```bash
     # curl GET /candidates/me -> Ra HTTP 200 OK bình thường.
     ```
  3. Đóng vai hacker, lấy chính Token đó để thực hiện hành vi lạm quyền (Privilege Escalation):
     ```bash
     curl -i -X DELETE -H "Authorization: Bearer <Candidate_Token_Bi_Hack>" http://api.thanhbinh.local/api/v1/jobs/14
     ```
  4. **Kết quả mỹ mãn:** API Gateway API Kong/Backend tự động cản ném ra lỗi mã **`403 Forbidden`**. Trạng thái xác thực (Authentication = Token Zin) vẫn không thể thắng được Kiểm duyệt ủy quyền Hành Động (Authorization = Mày làm gì có Role 'employer' mà rờ vô Job). Đây gọi là ZTA rà soát vi mô tận từng Endpoint. Ngăn thảm hoạ leo thang đặc quyền.