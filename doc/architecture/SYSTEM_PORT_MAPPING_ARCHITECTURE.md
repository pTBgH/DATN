# SƠ ĐỒ KIẾN TRÚC HỆ THỐNG VÀ XẠ XUYÊN PORT (PORT MAPPING ARCHITECTURE)

Tài liệu này mô tả chi tiết sơ đồ hệ thống thực tế đang chạy trên Cluster Kubernetes, bao gồm các dịch vụ phân bổ theo tầng (Layer), cổng giao tiếp nội bộ/bên ngoài (Routing Ports) và luồng dữ liệu (Data flow) giữa chúng.

---

## I. TỔNG QUAN KIẾN TRÚC MẠNG (NETWORK TOPOLOGY)

Hệ thống được chia thành 5 phân lớp (Layers) rõ rệt để cô lập rủi ro và tăng cường bảo mật theo quy chuẩn Microservices & Zero Trust.

### Luồng đi của 1 Request cơ bản (Data Flow):
```text
[Người Dùng/Trình Duyệt] 
        │ (Internet - Cầu nối ngoại biên)
        ▼ (Port 80/443 | NodePort: 30001/30003)
[ 1. Ingress NGINX Controller ]  <─── (Xử lý TLS Termination, Phân giải tên miền)
        │
        ├──► Nếu là gọi Frontend Web ──────────► [ 2. Frontend Layer (Next.js) ]
        │
        └──► Nếu là gọi API /api/v1/* ────────► [ 3. API Gateway / Security Layer (Kong & Oauth2 Proxy) ]
                                                        │     ▲
         (Kiểm tra Token/AuthZ) ────────────────────────┤     │ (Validate JWT / OIDC)
                                                        ▼     │
                                                [ Keycloak (Identity Provider) ]
                                                        │
    ┌───────────────────────────────────────────────────┼────────────────────────────────────────┐
    │                                                   ▼                                        │
    │                      [ 4. Backend Microservices Layer (PHP / Laravel) ]                    │
    │      (Identity | Workspace | Job | Hiring | Candidate | Communication | Storage)           │
    │                                                                                            │
    │       ▲ (Cấp phát Password JIT / Cert tạm)      │ (Ghi/Đọc Dữ Liệu)        │ (Phát Event)  │
    │       │                                         │                          │               │
    │   [ Vault (Secret Management) ]                 ▼                          ▼               │
    │                                     [ 5. Data Persistence Layer ]     [ Message Broker ]   │
    │                                      (MySQL, Redis per service)         (Kafka Cluster)    │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## II. CHI TIẾT ÁNH XẠ CỔNG VÀ DỊCH VỤ (PORT & SERVICE MAPPING)

Dưới đây là bảng phân tách từng dịch vụ, chúng sống trong Namespace nào, phục vụ cổng nội bộ (ClusterIP) nào và lộ ra ngoài (NodePort) như thế nào.

### 1. Tầng Ngoại Biên & Ingress (Edge Layer)
Nơi tiếp nhận toàn bộ băng thông Internet.

| Service Name | Namespace | Target (Cổng Nội bộ) | Public (Cổng Mở ra ngoài) | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| `ingress-nginx-controller` | `ingress-nginx` | 80, 443 | **30003** (HTTP), **30001** (HTTPS) | Phân giải traffic HTTP(S) từ trình duyệt để điều hướng. |
| `kong-proxy` | `gateway` | 8000, 8443 | **30000** (HTTP) | Trung tâm API Gateway bảo vệ Backend Oauth2/Ratelimit. |

---

### 2. Tầng Bảo mật & Định danh (Security & Access Layer)
Nơi xử lý Zero Trust (Authentication, Authorization, Secret Management).

| Service Name | Namespace | Cổng Nội bộ (ClusterIP) | Ghi chú |
| :--- | :--- | :--- | :--- |
| `keycloak` | `security` | **8080** | Máy chủ định danh Identity Provider (OIDC). Cấp phát JWT. |
| `oauth2-proxy` | `security` | **80** (4180 backend) | Tấm khiên SSO bảo vệ các ứng dụng Admin/Management. |
| `vault` | `vault` | **8200** (API), **8201** (Cluster)| Két sắt bảo mật cốt lõi cấp phát JIT Credentials. |
| `vault-dev` | `vault` | **8300** | Transit Engine dùng để Auto-unseal cho Vault Prod. |
| `vault-agent-injector`| `vault` | **443** | Webhook K8s để theo dõi và tiêm Secret vô Pod (`tmpfs`). |

---

### 3. Tầng Giao Diện Người Dùng (Frontend Layer)
Giao diện ứng dụng kết xuất bằng Next.js SSR/CSR.

| Service Name | Namespace | Cổng Nội bộ (ClusterIP) | Ghi chú |
| :--- | :--- | :--- | :--- |
| `fe-candidate` | `frontend` | **3000** | Giao diện mạng tuyển dụng dành cho Ứng viên xin việc. |
| `fe-recruiter` | `frontend` | **3000** | Giao diện nền tảng nội bộ dành cho Nhà tuyển dụng/Employer. |

---

### 4. Tầng Ứng dụng Nòng cốt (Backend Microservices Layer)
Các dịch vụ xử lý nghiệp vụ chính viết bằng Laravel (PHP-FPM/NGINX). Tất cả chạy trong cùng Namespace nhưng được cô lập API, đều mở **Port 80** để Gateway gọi vào.

| Service Name | Namespace | Cổng Nội bộ (ClusterIP) | Nhiệm vụ chính trị (Business Logic) |
| :--- | :--- | :--- | :--- |
| `identity-service` | `job7189-apps`| **80** | Sync quản lý thông tin User từ Keycloak, Phân quyền hệ thống cơ sở. |
| `workspace-service`| `job7189-apps`| **80** | Quản lý Không gian làm việc, Mạng lưới các tổ chức/công ty. |
| `job-service` | `job7189-apps`| **80** | Xử lý Core: Đăng/Sửa việc làm, tra cứu và duyệt Job. |
| `hiring-service` | `job7189-apps`| **80** | Quản lý Quy trình Tuyển dụng (Hiring Pipeline, Từng vòng phỏng vấn).|
| `candidate-service`| `job7189-apps`| **80** | Xử lý Quá trình Nộp hồ sơ (Apply), Nộp CV, và Save Job. |
| `communication-svc`| `job7189-apps`| **80** | Chat realtime, Event gửi Mails, Nhắn tin nội bộ ứng viên - công ty.|
| `storage-service` | `job7189-apps`| **80** | Dịch vụ trung gian quản lý File/Object/CV kết nối vào MinIO. |

---

### 5. Tầng Dữ liệu và Lõi Giao tiếp (Data persistence & Broker)
Tầng lưu trữ trạng thái vật lý chung. (Lưu ý: Theo kiến trúc này, Database được cô lập ở mặt Logic (Khác DB name), nhưng nằm chung 1 Server Cluster).

| Service Name | Namespace | Cổng Nội bộ (ClusterIP) | Ghi chú / Trách nhiệm |
| :--- | :--- | :--- | :--- |
| `mysql` | `data` | **3306** | Cơ sở dữ liệu quan hệ lõi chứa nhiều Logical Database. |
| `*-redis` | `job7189-apps`| **6379** | Hệ thống Cache cho API và Job Queue (Mỗi App có 1 con Redis riêng biệt, VD: `job-service-redis`). |
| `kafka-svc` | `data` | **9092, 9093** | Event Broker. Bus phát tín hiệu Asynchronous phục vụ giao tiếp chéo App (Tránh gọi HTTP chập chờn). |

---

## III. PHÂN TÍCH CHUYÊN SÂU LƯU LƯỢNG GIAO TIẾP TƯƠNG TÁC (DATA & TRAFFIC FLOWS)

Mọi luồng dữ liệu (Data flows) trong hệ thống được thiết kế thận trọng để tách biệt giữa Traffic công khai mang tính bất định (Public/North-South) và Traffic nội bộ có độ tin cậy được kiểm soát (Internal/East-West). Sau đây là phân tích kỹ thuật chi tiết:

### 1. Luồng Người Dùng & Di Động vào Hệ Thống (North-South Traffic - Ingress)
Đây là các Request xuất phát từ trình duyệt (Frontend Next.js) hoặc Mobile App gọi thẳng vào lớp viền ngoại vi (Edge Layer).

*   **Phương thức:** `HTTP/1.1` & `HTTP/2` (RESTful API & GraphQL).
*   **Trạng thái mã hóa (Encryption):** 
    *   **Mã hoá Toàn phần (Full TLS/SSL):** Giao tiếp từ thiết bị người dùng đến Ingress Controller (via Internet) luôn bị ép dùng `HTTPS (Port 443)`. Terminated TLS (giải mã) diễn ra tại Ingress NGINX. 
    *   Sau NGINX, traffic di chuyển thầm lặng, nội vùng cụm K8s xuống Kong (Plaintext trên Virtual Network K8s CNI).
*   **Luồng Thực tế (Routing):**
    1. Trình duyệt gọi POST `/api/v1/jobs` kèm `Bearer Token`.
    2. NGINX Ingress nhận yêu cầu tại `NodePort 30001` -> Chuyển tiếp xuống `Kong Gateway Service (Cổng 8000)`.
    3. Kong Gateway (Đóng vai trò Policy Enforcement Point) sẽ trích xuất Header `Authorization`, móc nối với `Keycloak (Identity Provider)` qua đường OIDC Token Introspection để xác minh JWT Signatures và Audience.
    4. Nếu Keycloak duyệt "Hợp lệ", Kong thực thi proxy-pass đẩy gói tin xuống `job-service:80`.

### 2. Luồng Gọi API Nội Bộ Đồng Bộ (Sync East-West Traffic)
Khi một Microservice không thể tự quyết định mà cần móc nối sang Microservice khác để lấy thông tin. Thiết kế nguyên bản cấm gọi chéo trừ khi cực kì cần thiết (như lấy Profile). Bắt buộc phải thông qua Namespace Router nội bộ thay vì đi vòng ra Ingress.

*   **Phương thức:** `HTTP/REST (GET, POST)`. 
*   **Trạng thái mã hóa:** Bản Rõ (Plaintext TCP/IP). Độ tin cậy được bù đắp bằng **Cilium L7 Microsegmentation** (Network Policies) nhằm tránh rò rỉ nếu bị nghe lén (sniff packet) bên trong Cluster.
*   **Các API nội bộ cốt lõi (Internal Endpoint Schema):**
    *   `job-service` ──(gọi)──► `workspace-service`
        * Endpoint: `GET http://workspace-service/api/v1/internal/workspaces/{id}`
        * Mục đích: Job Service cần xác thực Job_Post này có thuộc Workspace hợp lệ nào không để đính kèm Company Logo. 
        * Bảo mật: Được nhốt giới hạn chỉ đúng GET request bằng eBPF.
    *   `hiring-service` ──(gọi)──► `identity-service`
        * Endpoint: `GET http://identity-service/api/v1/internal/profile/{user_id}`
        * Mục đích: Quy trình tuyển dụng (Hiring Board) cần đổ hồ sơ kèm Tên_thật và Avatar người dùng mà Identity nắm giữ.
*   **Bảo mật Xác thực tầng App:** Mọi lệnh gọi nội bộ `/api/v1/internal/*` yêu cầu một `Internal-API-Secret` (Shared HMAC Key - Cấp phát bởi Vault) đính trong Header `X-Internal-Token` để App Framework xác nhận không phải request ma.

### 3. Luồng Giao Tiếp Bất Đồng Bộ & Giải Phóng Tải (Async Event-Driven East-West)
Nhằm giữ cho hệ thống "High Availability" (Độ sẵn sàng cao) & "Decoupling" (Giảm phụ thuộc). Luồng Event-driven là xương sống xử lý các hành động trễ.

*   **Phương thức:** `TCP Binary Protocol` qua **Kafka**.
*   **Trạng thái mã hóa:** Plaintext Kafka Protocol nội bộ (Port 9092).
*   **Luồng Thực tế Hành vi Đăng Ký (Candidate Apply Pattern):**
    1. Người dùng bấm Nộp hồ sơ: `candidate-service` tiếp nhận File CV, lưu File qua `storage-service` gởi vô MinIO. DB candidate được cập nhật trạng thái "Applied".
    2. `candidate-service` hoàn thành API -> Trả HTTP 200 về cho trình duyệt gần như ngay lập tức (~100ms).
    3. Bối cảnh ngầm: Nó quăng (Publish) 1 Event tin nhắn `candidate_applied_event` vào `Kafka Topic`.
    4. **Các Consumer âm thầm hành động:** 
       - `hiring-service` bốc message từ Kafka -> Kéo CV tạo 1 Card mới trên Board Kanban của Nhà tuyển dụng.
       - `communication-service` bốc message từ Kafka -> Soạn một Template HTML -> Kích hoạt Server SMTP để quăng Email *"Cám ơn bạn đã nộp đơn"*.
    *(Vì chúng giao tiếp qua Kafka, kể cả lúc đó hệ thống Gửi Email có chết (Down), CV của ứng viên vẫn được nộp thành công. Kafka sẽ giữ thông báo đó chờ ngày Communication sống lại để gửi bù)*.

### 4. Luồng Xác Dạng Dữ Liệu và Bí Mật Điện Tử (Infrastructure Persistence & Secrets Flow)
Toàn bộ Microservice trên Cluster đều sinh ra trong trạng thái "Mù" (Không biết mật khẩu DB, không biết Auth Key). Chúng phải "Thỉnh cầu" từ Hệ sinh thái Data.

*   **Giao tiếp Pod ↔ Két Vault:**
    *   Giao thức: `HTTPS (REST API)` qua Port 8200 (Vault gốc).
    *   Trạng thái: Hoàn toàn được mã hoá kẹp TLS In-Transit (Có CA Cert tự sinh bằng Cert-Manager).
    *   Bên trong pod Microservice, `Vault Agent Injector` (Init Container) sẽ khởi động sớm dâng `ServiceAccount Token` của K8s lên cho Vault để xin phép. Nếu Policy đồng ý, Vault tạo kết nối riêng đến MySQL, sinh username/pass dùng 1 lần (TTL 1hr) rồi tiêm thằng vào đĩa RAM `/vault/secrets/.env.db` của Microservice đo.
*   **Giao tiếp Pod ↔ Cơ Sở Dữ Liệu (MySQL/Redis):**
    *   Giao thức: `TCP 3306 (MySQL)` và `TCP 6379 (Redis)`.
    *   Trạng thái mã hoá: Plaintext Binary (Hệ thống tin tưởng mạng con được khóa chốt tại Layer 4 thông qua Policy của Cilium - `02-allow-egress-data`).
    *   App dùng mật khẩu do Vault vừa cấp để chui vô Data lấy thông tin. Khi Hết thời hạn quy định (Lease expired), Vault sẽ đá văng Session khỏi MySQL.

---
*(Sơ đồ kiến trúc & Phân tích Giao thức này định danh rõ trạng thái của toàn bộ hệ thống Port-Binding hiện tại đang thực thi trên Cluster Kubernetes, tuân thủ tuyệt đối Tầm nhìn Zero Trust Architecture - ZTA)*
