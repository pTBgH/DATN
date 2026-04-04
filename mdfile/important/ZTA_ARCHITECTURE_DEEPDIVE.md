# TÀI LIỆU CHUYÊN SÂU: ZERO TRUST ARCHITECTURE VÀ CÁC THỰC THỂ CỐT LÕI (PEP, PDP, PE, PA)
> **Mức độ:** Trình diễn cấp cao (Bảo vệ đồ án / Pitching doanh nghiệp)
> **Khuyến nghị:** Sử dụng tài liệu này để phân tích chuyên sâu cho hội đồng giám khảo hiểu cách hệ thống của chúng ta thoả mãn hoàn toàn bộ tiêu chuẩn NIST SP 800-207 về Zero Trust.

---

## 1. BẢN ĐỒ KIẾN TRÚC NHỎ GIỌT THEO CHUẨN ZTA (NIST SP 800-207)

Một kiến trúc Zero Trust không phải là một món đồ mua sẵn, mà là một cỗ máy gồm 4 thành phần cốt lõi tương tác với nhau để bóp nghẹt mọi luồng đi đáng ngờ. Dưới đây là cách hệ thống của chúng ta lắp ráp các mảnh ghép này:

### A. Công cụ Quyết định Chính sách (Policy Decision Point - PDP)
Đây là "Bộ não" của hệ thống. Nhờ có nó, mạng lưới được sống và suy nghĩ độc lập. PDP bao gồm 2 thành phần nhỏ, và trong kiến trúc này chúng ta đang dùng nhiều hệ thống hỗn hợp làm việc cùng nhau:

*   **PE - Policy Engine (Động cơ Chính sách):** 
    *   *Nhiệm vụ:* Người cấp phép tối cao. Nó chịu trách nhiệm giải phương trình: *Identity X có được phép chọc vào Tài nguyên Y dưới Điệu kiện Z hay không?*
    *   *Thực tại hệ thống:* 
        *   **Keycloak (User PE):** Xét duyệt Identity tĩnh, cấp phát và đánh giá quyền Role/Scopes của Người Dùng (Ví dụ: Thằng cấp Candidate mà đòi xoá Job là fail).
        *   **Vault (Machine PE):** Đánh giá nhân thân của Workload. Token K8s của Namespace `job7189-apps` có thoả policy để chọc vào file `/database/creds` hay không.
        *   **Cilium (Network PE):** Đối chiếu bảng định tuyến eBPF để xem gói tin Network có được phép đi ngang East-West.

*   **PA - Policy Administrator (Quản trị viên Chính sách):**
    *   *Nhiệm vụ:* Kẻ thực thi mệnh lệnh của PE, làm nhiệm vụ phân phát (compile) các quyết định đó thành mã máy, mã ngắt dội thẳng xuống hạ tầng thiết bị.
    *   *Thực tại hệ thống:*
        *   **Cilium Operator:** Dịch file YAML `CiliumNetworkPolicy` (CNP) ngôn ngữ người đọc hiểu thành thuật toán máy eBPF ghim trực tiếp vào nhân Kernel Linux của máy chủ.
        *   **Vault Agent Injector:** Truyền động lệnh từ Core Vault thọc thẳng mã hóa ngầm `tmpfs` vào bụng RAM Pod.

### B. Điểm thực thi Chính sách (Policy Enforcement Point - PEP)
Đây là các gã "Bảo kê" hay "Lính đánh thuê" đứng gác cửa cho Cổng vào (Edge) và Lõi hệ thống (Core). Chúng nhận lệnh (Yes/No) từ PDP và thẳng tay trừng phạt lưu lượng (Drop Packet / 401 / 403).
*   **Kong API Gateway (Edge PEP):** Tương tác với Oauth2 Plugin và Keycloak PDP. Tước cổ bẻ gãy mọi HTTP Traffic nếu sai JWT token. Chặn lưu lượng North-South (Từ ngoài mạng Internet vào).
*   **Cilium eBPF Agent (Datapath PEP):** Đứng gác ở tầng L4 (Network) tới L7 (HTTP / API). Cản tất cả lượng TCP/UPD Traffic chui rúc bên trong, ngăn di chuyển ngang (East-West) mà không cần bẻ khóa SSL nhờ thuật toán BPF nằm sát đáy hạ tầng. Không có chữ ký hợp lệ ở lớp mạng => Thả gói tin trượt trôi (DROP Packet).

---

## 2. KỊCH BẢN THỰC CHIẾN MICROSEGMENTATION QUA CILIUM (L4 & L7 ZTA)

Vì chúng ta làm Zero Trust, việc nhốt luồng API tại Gateway (Kong) là chưa đủ. Nếu Hacker chiếm quyền được Container trong lòng máy chủ thì sao? **"Cilium Microsegmentation"** sẽ là câu trả lời triệt để. Hành động này sẽ khóa cổ từng Microservice vào cái cũi (Jail) chuyên biệt.

Mình đã phân tích luồng API hệ thống và chuẩn bị **Bộ 5 mạn lưới cấm cản đa tầng** dưới mục: `infras/k8s-yaml/cilium-policies/`.
Luồng chính sẽ bao gồm cấm tất tần tật (Default Deny) và lập chính sách Trắng (Whitelist):

- `00-default-deny.yaml` : PEP Cilium chặn mọi lối vào/ra. Cấm cả các Pod trong cùng một Namespace trò chuyện với nhau.
- `01-allow-egress-dns.yaml` : Mảnh ghép Whitelist cho phép các Pod tra cứu IP máy qua Coredns của K8s.
- `02-allow-egress-data.yaml` : PEP Cilium thả chốt cho phép Pod cắm TCP chuẩn vào Vault (Tầng bảo mật cấp 2) và MySQL / Redis. 
- `03-allow-ingress-kong.yaml`: Chỉ có **duy nhất** danh tính đến từ namespace `kong` nằm ở Lớp Edge (Xác thực L7) mới được phép chọc vào API. Các Pod cố tình Ping lẫn nhau là vô ích.
- `04-allow-internal-api-strict.yaml` : **(L7 Microsegmentation chấn động):** Nâng cấp eBPF thành Thanh Tra Viên L7 giỏi nhất. 
  Ví dụ chính sách chúng ta đã viết: Yêu cầu Request vào thư mục gốc `workspace-service` **CHỈ** được phép xuất phát từ `job-service`, và chỉ được quyền dùng giao thức `GET`, dứt khoát tại địa chỉ cố định `/api/v1/internal/workspaces/.*`. Một gã khác (VD như Pod Lừa  đảo) ở cùng máy mà chọc vào `DELETE` là đứt tay.

---

## 3. KỊCH BẢN DEMO "CHÁY MÁY" (PITCHING ĐÁNH BẠI ĐỐI KHẢO)

Bạn có thể tự tin mời thầy/cô (hoặc đối tác) tham gia theo hành trình Tấn Công (Red Team) vs Phòng Thủ (Blue Team) sau.

### Bước 1: RED TEAM - Khi Microsegmentation tắt (Tình trạng Mạng truyền thống)

1. Để nguyên mạng mở rộng.
2. Thâm nhập vào một Pod làm nội gián:
   ```bash
   kubectl exec -it -n job7189-apps deploy/communication-service -- bash
   ```
3. "Cào thẳng API" của nội bộ mà không cần đi qua Kong chặn JWT:
   ```bash
   curl -i http://workspace-service/api/v1/internal/workspaces
   ```
   > **Kết quả Red Team ăn điểm:** Trả mã HTTP 200 OK. Dữ liệu nhạy cảm Workspace bị moi ra từ một máy nhánh vốn dùng để gửi Mail. Đây là lỗi chết người của mạng ngang hàng (Lateral Movement Exploitation) cực kì phổ biến trên Docker Swarm hoặc K8s cũ.

### Bước 2: BLUE TEAM - Thiển triển ZTA Microsegmentation (Nhốt lồng lưới)

Bạn đọc câu châm ngôn: *"ZTA tuyên bố: Cả mạng LAN K8s cũng là mạng rác không thể tin tưởng!"*. Dùng Console chạy lệnh sau để kéo áo giáp eBPF xuống bảo kê tận đáy Kernel:

```bash
cd infras/k8s-yaml/cilium-policies
./apply-zta-microsegmentation.sh
```
> **Điều gì diễn ra phần ngầm:** PA (Cilium Operator) truyền lệnh từ API K8s, dịch file YAML qua Datapath, đúc thành các chương trình C tĩnh và nhét vào eBPF Agent. Các PEP trên các node Worker K8s đang ngầm phong tỏa mọi ngã 4.

### Bước 3: TEST NGƯỢC - Mớ lý thuyết có thật hay không?

Từ terminal của Hacker làm lại chuyện khi nãy (Pod communication-service gọi Workspace API nội bộ):

```bash
kubectl exec -it -n job7189-apps deploy/communication-service -- \
  curl -i --connect-timeout 5 http://workspace-service/api/v1/internal/workspaces
```

> **🔥 KẾT QUẢ BOOM TẤN:** Lệnh `curl` đứng đơ, báo lỗi Timeout hoặc Lên bảng `Connection Refused / Drop Packet`. Bằng mắt thường, Hacker ko thấy tường lửa nào trong container của anh ta! Bỏ lỡ toàn bộ Traffic. Ngay từ lúc ra khỏi cổ thẻ mạng `veth`, Gói tin (Packet) đã bị gạt phăng và thả trôi (packet DROP) ở cấp độ vòng lặp Network Layer bởi Datapath PEP. 

### Bước 4: KIỂM CHỨNG TÍNH L7 NGHIÊM NGẶT CỦA CILIUM
Thế Pod `job-service` (Đã được cấp phép ở File YAML 04) thì sao? Liệu có phải là nó cầm thẻ lệnh cấm cự là vào được mọi thứ không?
```bash
# Thử hàm GET cho phép (Sẽ cho qua - HTTP 200)
kubectl exec -it -n job7189-apps deploy/job-service -- curl -i -X GET http://workspace-service/api/v1/internal/workspaces/info

# Thử hành vi phá hoại (DELETE - Hàm không có trong whitelist L7)
kubectl exec -it -n job7189-apps deploy/job-service -- curl -i -X DELETE http://workspace-service/api/v1/internal/workspaces/info
```
> **🔥 KẾT QUẢ TÀN KHỐC HƠN:** HTTP 403 Access Denied nhả về từ tầng Network (Không phải do Code App chặn). Zero Trust PEP đã hoạt động xuất sắc kiểm duyệt từng giao thức đến độ hạt mịn tận method API (L7 HTTP parsing) chứ không chỉ chơi cấm cản Port L4 rỗng tuếch như IPtables / Ngắn Firewall truyền thống.

---

### BƯỚC 5: Hủy bỏ Demo
Khi đồ án kết thúc, hoặc bị lỗi các luồng API lạ, trả lại trạng thái mở (hủy Cilium Security):
```bash
cd infras/k8s-yaml/cilium-policies
./destroy-zta-microsegmentation.sh
```

---
**TÓM LƯỢC CHO HỘI ĐỒNG:** Bằng sự phân ly rõ rệt giữa Quyết định (PDP/PE - Vault, Keycloak, Cilium Control Plane) và Chấp Pháp (PEP - Kong Gateway, Env In Memory, eBPF Kernel Datapath), Hệ thống này đạt chuẩn ZTA tuyệt đối. Đánh sập vành đai bảo mật lớp ngoài cũng không thể phá chốt Lõi lớp trong. Mũ bảo hiểm đội trên đầu máy bay ném bom thay vì chỉ xây thành giữ lũy.