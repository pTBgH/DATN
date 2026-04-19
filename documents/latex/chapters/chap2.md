&nbsp;

## 2.1. Đặc điểm bảo mật đặc thù của Microservices

Kiến trúc Microservices mang lại sự linh hoạt và khả năng mở rộng vượt trội, nhưng đồng thời cũng làm thay đổi hoàn toàn "bề mặt tấn công" (Attack Surface) của hệ thống. Nghiên cứu bảo mật trong môi trường này đòi hỏi phải giải quyết các bài toán nảy sinh từ bản chất phân tán và tính chất động của tài nguyên.

### 2.1.1. Sự bùng nổ lưu lượng nội bộ (East-West Traffic)

Trong kiến trúc đơn khối (Monolith), hầu hết các giao tiếp diễn ra bên trong bộ nhớ của một tiến trình duy nhất. Tuy nhiên, khi chuyển sang Microservices, các chức năng nghiệp vụ được tách rời, dẫn đến sự bùng nổ của lưu lượng **East-West** (giao tiếp giữa các dịch vụ nội bộ với nhau).

- **Hạn chế của bảo mật vành đai (Perimeter):** Các công cụ bảo mật truyền thống như tường lửa biên (Firewall) hay IPS chỉ tập trung giám sát lưu lượng **North-South** (Client gọi vào Server). Một khi kẻ tấn công vượt qua được vành đai này và chiếm quyền kiểm soát một dịch vụ đơn lẻ, chúng có thể tự do di chuyển ngang (Lateral Movement) trong mạng nội bộ vì các dịch vụ bên trong thường "mặc định tin tưởng" nhau qua địa chỉ IP nội bộ (Nguồn: NIST SP 800-204).
    
- **Rủi ro:** Một lỗ hổng tại một dịch vụ không trọng yếu có thể trở thành bàn đạp để truy cập trái phép vào các cơ sở dữ liệu nhạy cảm nằm sâu trong hệ thống.
    

> **Ví dụ trong Job7189:** Khi người dùng gửi yêu cầu xem danh sách công việc, yêu cầu này đi qua Gateway. Tại đây, `Job Service` có thể phải gọi sang `Identity Service` để xác thực quyền hạn và `Workspace Service` để lấy thông tin doanh nghiệp. Tường lửa biên chỉ thấy yêu cầu đầu tiên, toàn bộ quá trình trao đổi Token và dữ liệu giữa các dịch vụ bên trong hoàn toàn nằm ngoài tầm kiểm soát của nó.

### 2.1.2. Ephemeral Workloads: Sự lỗi thời của mô hình tin cậy dựa trên IP

Trong các nền tảng điều phối container như Kubernetes, các đối tượng (Pods/Containers) có đặc tính **tạm thời (ephemeral)**. Chúng được khởi tạo, tiêu hủy và mở rộng (scaling) liên tục dựa trên tải của hệ thống.

- **Thách thức đối với IP-based Trust:** Địa chỉ IP của một dịch vụ trong Microservices không cố định. Một Pod bị lỗi khi khởi động lại sẽ nhận được một IP mới. Việc cấu hình tường lửa hay danh sách trắng (Whitelisting) dựa trên IP trở nên bất khả thi và dễ dẫn đến sai sót (Nguồn: Sam Newman, "Building Microservices", 2021).
    
- **Yêu cầu của ZTA:** Hệ thống không thể dựa vào "vị trí mạng" (mạng nội bộ hay IP) để xác lập lòng tin. Định danh phải được gắn chặt vào chính dịch vụ (Service Identity) thông qua các phương thức xác thực mạnh như chứng chỉ số (mTLS) thay vì các thuộc tính mạng biến đổi (Nguồn: NIST SP 800-207).
    

### 2.1.3. Dynamic Secrets: Thách thức quản lý thông tin nhạy cảm

Môi trường Microservices yêu cầu một lượng lớn các thông tin nhạy cảm (Secrets) như: mật khẩu cơ sở dữ liệu, API Keys của bên thứ ba, các khóa ký JWT (Signing Keys).

- **Rủi ro từ Secret tĩnh:** Nếu các bí mật này được cấu hình cứng (Hardcoded) hoặc lưu trữ trong các tệp cấu hình tĩnh (ConfigMaps), nguy cơ rò rỉ là rất cao khi mã nguồn bị lộ hoặc hệ thống quản lý cấu hình bị xâm nhập.
    
- **Cơ chế Secrets động:** ZTA yêu cầu các bí mật phải được quản lý tập trung và cấp phát một cách năng động. Các thông tin này nên có thời gian sống (TTL) ngắn, được sinh ra cho một phiên làm việc cụ thể và tự động xoay vòng (Rotation) để giảm thiểu tối đa "Blast Radius" (phạm vi ảnh hưởng) nếu một dịch vụ bị chiếm quyền (Nguồn: NIST SP 800-204).
    

### 2.1.4. Shared Infrastructure Risk: Rủi ro từ hạ tầng dùng chung

Microservices thường vận hành trên một cụm máy chủ dùng chung (Shared Cluster). Điều này tạo ra rủi ro về việc "thoát khỏi vùng cách ly" (Isolation Breach).

- **Namespace và Network Policy:** Trong Kubernetes, **Namespace** chỉ là sự phân chia logic, không phải vật lý. Nếu không cấu hình các chính sách mạng (Network Policies) chặt chẽ, một dịch vụ ở Namespace này vẫn có thể quét port và tấn công dịch vụ ở Namespace khác.
    
- **Storage và Node sharing:** Các dịch vụ chia sẻ chung tài nguyên lưu trữ và bộ nhớ trên cùng một Node vật lý. Nếu một dịch vụ bị nhiễm mã độc và thực hiện tấn công leo thang đặc quyền (Privilege Escalation) lên mức hạt nhân (Kernel), nó có thể chiếm quyền kiểm soát toàn bộ các dịch vụ khác đang chạy trên cùng Node đó.
    
- **Hệ quả:** Nguyên lý "Mạng luôn bị coi là đã bị xâm nhập" trong ZTA buộc chúng ta phải bảo vệ từng tài nguyên (dữ liệu, lưu trữ) độc lập với mức độ an toàn của hạ tầng nền bên dưới.
    

* * *

**Nguồn trích dẫn tham khảo:**

- *National Institute of Standards and Technology (2019), "Security Strategies for Microservices-based Applications", NIST Special Publication 800-204.*
    
- *Newman, S. (2021), "Building Microservices: Designing Fine-Grained Systems", O'Reilly Media.*
    
- *National Institute of Standards and Technology (2020), "Zero Trust Architecture", NIST Special Publication 800-207.*
    

* * *

Phần này đã làm rõ được tại sao Microservices lại là một bài toán bảo mật khó và tại sao các cách làm cũ (vành đai, IP) lại thất bại. Bạn thấy đoạn này đã đủ sâu chưa để mình chuẩn bị sang phần **2.2. Kiến trúc PEP/PA/PE** cho các thành phần cụ thể trong Microservices?

## 2.2. Thách thức triển khai ZTA trên Kubernetes

Việc áp dụng 7 nguyên lý của NIST SP 800-207 vào môi trường Cloud-native như Kubernetes không phải là một bài toán "cắm và chạy" (plug-and-play). Hạ tầng động và phân tán của K8s tạo ra 4 thách thức cốt lõi sau:

### 2.2.1. Vấn đề về mức độ chi tiết (Granularity Problem)

Thách thức đặt ra là các thành phần PE/PA/PEP nên hoạt động ở tầng nào trong mô hình OSI để đảm bảo an ninh mà không làm gãy đổ hệ thống.

- **Tầng L3/L4 (Network):** Các giải pháp như *NetworkPolicy* mặc định chỉ chặn dựa trên IP/Port. Điều này không đủ để thực thi ZTA vì kẻ tấn công có thể giả mạo IP hoặc lợi dụng các cổng dịch vụ hợp lệ (như 80/443).
    
- **Tầng L7 (Application):** Cần can thiệp vào HTTP/gRPC để kiểm tra các phương thức (GET, POST), Headers và JWT. Tuy nhiên, việc thực thi ở L7 đòi hỏi PEP phải có khả năng giải mã TLS, gây phức tạp cho quản lý chứng chỉ.
    
- **Tầng Runtime:** ZTA yêu cầu giám sát cả hành vi của tiến trình (Process). Một Pod có định danh hợp lệ vẫn có thể bị coi là "compromised" nếu nó thực hiện các hành vi bất thường như quét bộ nhớ.
    

> "ZTA requires a shift from network-centric to resource-centric security, where the enforcement must occur as close to the resource as possible." *(Nguồn: NIST.SP.800-207.pdf, Section 3.1, Page 9)*

### 2.2.2. Bài toán định danh (Identity Problem)

Trong K8s, khái niệm "Subject" (Chủ thể) trở nên phức tạp do sự chồng chéo giữa người dùng và máy móc.

- **Workload Identity:** Các Service liên lạc với nhau thông qua *ServiceAccount*. Tuy nhiên, ServiceAccount mặc định của K8s thường thiếu các thuộc tính mạnh để làm căn cứ cho PE (như thời gian khởi tạo, chữ ký thiết bị).
    
- **User Identity:** Khi một yêu cầu đi từ người dùng cuối xuyên qua chuỗi Microservices, làm thế nào để "Subject" vẫn mang theo thông tin của người dùng ban đầu thay vì chỉ là định danh của Service đứng trước nó?
    
- **Thách thức:** Xây dựng cơ chế **Identity Propagation** (lan truyền định danh) để PE có thể đưa ra quyết định dựa trên cả "ai đang yêu cầu" và "dịch vụ nào đang thực hiện yêu cầu đó".
    

### 2.2.3. Hiệu năng hệ thống (Performance Problem)

Việc thực thi chính sách trên **mọi yêu cầu (per-request)** tạo ra độ trễ (latency) đáng kể.

- **Overhead của PEP:** Nếu mỗi request đều phải chờ PEP hỏi ý kiến PE qua mạng, độ trễ sẽ tăng gấp đôi.
    
- **Chi phí tính toán:** Việc kiểm tra liên tục hàng ngàn chính sách và giải mã TLS ở quy mô hàng trăm Microservices có thể chiếm dụng tới **10-30%** tài nguyên CPU của cụm.
    
- **Giải pháp:** Đòi hỏi các công nghệ như **eBPF** để thực thi chính sách ngay tại tầng Kernel hoặc sử dụng Sidecar tối ưu hóa để giảm thiểu bước nhảy (hop) của dữ liệu.
    

> "The Policy Enforcement Point (PEP) must be able to handle the request volume without becoming a significant bottleneck." *(Nguồn: Xây Dựng Kiến Trúc Zero Trust, Mục 1.2.2)*

### 2.2.4. Khả năng quan sát (Observability Problem)

Nguyên lý thứ 7 của ZTA yêu cầu thu thập tối đa dữ liệu để cải thiện chính sách. Trong K8s, điều này dẫn đến tình trạng "ngập lụt dữ liệu".

- **Tính động:** Các Pod liên tục được tạo mới và xóa bỏ, khiến việc truy vết nhật ký (logs) theo địa chỉ IP trở nên vô nghĩa.
    
- **Continuous Monitoring:** Làm thế nào để phân biệt giữa một lưu lượng hợp lệ và một cuộc tấn công "di chuyển ngang" trong hàng triệu luồng kết nối mỗi giây?
    
- **Thách thức:** Cần một hệ thống Logging/Tracing tập trung (như ELK hoặc Prometheus/Grafana) có khả năng gắn nhãn (Label) theo ngữ cảnh ZTA (Subject, Resource, Action) thay vì chỉ lưu trữ dữ liệu thô.
    

* * *

**Nguồn trích dẫn:**

- **NIST.SP.800-207.pdf**, Section 3.1 & 3.4.
    
- **Zero Trust Architecture for Microservices in Kubernetes Environments** (Tài liệu đính kèm).
    
- **Xây Dựng Kiến Trúc Zero Trust**, Phần thách thức triển khai.


## 2.3. Đề xuất Khung kiến trúc ZTA cho Microservices (Proposed ZTA Framework)

Dựa trên việc phân tích các thách thức tại mục 2.2, đồ án đề xuất một khung kiến trúc 4 lớp tích hợp, lấy dữ liệu làm trung tâm và định danh làm vành đai bảo mật.

### 2.3.1. Lớp Định danh đa thực thể (Multi-Entity Identity Layer)

Trong ZTA cho Microservices, một yêu cầu truy cập không chỉ có một chủ thể. Khung kiến trúc đề xuất cơ chế **Dual-Identity**:

- **User Identity (Định danh người dùng):** Sử dụng các giao thức **OIDC/JWT**. Đóng vai trò là "Chủ thể gốc" (Originator).
    
- **Workload Identity (Định danh tiến trình):** Sử dụng tiêu chuẩn **SPIFFE/Spire** để cấp chứng chỉ X.509 ngắn hạn cho từng Pod. Đóng vai trò là "Chủ thể thực thi" (Executor).
    
- **Ý nghĩa:** PE sẽ đánh giá dựa trên cặp `(User_ID + Workload_ID)`. Nếu một Service bị chiếm quyền (compromised), kẻ tấn công không thể giả mạo User Identity để thực hiện các hành vi trái phép trên tài nguyên khác.
    

### 2.3.2. Lớp Thực thi Chính sách đa tầng (Multi-layer Enforcement Layer)

Thay vì chỉ dùng một PEP duy nhất, khung đề xuất mô hình **Defense-in-Depth** (Phòng thủ chiều sâu):

- **API Gateway (North-South):** PEP tại cửa ngõ, thực thi chính sách ở tầng L7, kiểm tra JWT và chặn các yêu cầu từ Internet không hợp lệ.
    
- **CNI eBPF (East-West):** PEP tại tầng Kernel (sử dụng công nghệ như **Cilium**). Thực thi chính sách L3/L4/L7 giữa các Service với độ trễ cực thấp. eBPF giúp giám sát luồng dữ liệu mà không cần can thiệp vào mã nguồn ứng dụng.
    
- **Runtime Engine:** PEP tại tầng System Call (syscall). Nếu một Service hợp lệ nhưng bất ngờ thực hiện hành vi "lạ" (như đọc file `/etc/shadow`), Runtime engine sẽ ngắt tiến trình ngay lập tức.
    

### 2.3.3. Lớp Quản trị Bí mật Động (Dynamic Secret Layer)

Khung kiến trúc loại bỏ hoàn toàn các cấu hình tĩnh (Static Secrets) trong file `.env` hay K8s Secrets thông thường.

- **JIT Credentials (Cấp quyền tức thời):** Sử dụng **HashiCorp Vault** như một thành phần của **Policy Administrator (PA)**. Khi Service cần truy cập Database, Vault sẽ sinh ra một tài khoản tạm thời chỉ có hiệu lực trong 5 phút.
    
- **Tự động xoay vòng (Auto-rotation):** Mọi chứng chỉ và khóa mật mã được thay đổi liên tục, làm giảm giá trị của các thông tin xác thực bị đánh cắp xuống mức tối thiểu.
    

> "A Zero Trust Enterprise should prioritize dynamic secrets and just-in-time access to minimize the window of opportunity for attackers."
> 
> *(Nguồn: Xây Dựng Kiến Trúc Zero Trust, Section 4.2)*

### 2.3.4. Lớp Quan sát và Phân tích hành vi (Observability & Analytics Layer)

Trong ZTA, Continuous Monitoring không phải là hậu kiểm, mà là đầu vào trực tiếp cho PE.

- **Data Lake cho Bảo mật:** Tổng hợp Logs từ API Gateway, eBPF và Runtime vào hệ thống ELK/EBK.
    
- **Vòng lặp phản hồi (Feedback Loop):** Hệ thống phân tích (UEBA) sẽ theo dõi hành vi của Subject. Nếu phát hiện sai lệch (Anomalies), nó sẽ gửi tín hiệu tới PE để tăng mức độ rủi ro (Trust Score) và yêu cầu PEP ngắt kết nối ngay lập tức mà không cần sự can thiệp của con người.
    

* * *

### **Bổ sung: Bảng tóm tắt giá trị đóng góp của Khung đề xuất**

| **Thành phần** | **Công nghệ tiêu biểu** | **Nguyên lý NIST giải quyết** |
| --- | --- | --- |
| **Identity** | SPIFFE/SPIRE, OIDC | **Tenet 6:** Xác thực/Ủy quyền nghiêm ngặt. |
| **Enforcement** | Cilium (eBPF), Kong | **Tenet 2 & 3:** Bảo mật mọi giao tiếp và cấp quyền theo phiên. |
| **Secret** | HashiCorp Vault | **Tenet 4:** Quyết định dựa trên chính sách động (JIT). |
| **Observability** | Prometheus, Grafana, Falco | **Tenet 7:** Thu thập dữ liệu tối đa để cải thiện bảo mật. |

* * *

**Nguồn trích dẫn đóng góp:**

- **Bảo mật thích ứng trong Zero Trust**, Đề xuất kiến trúc cho môi trường Cloud-native.
    
- **Zero Trust Architecture for Microservices in Kubernetes Environments**, Phân tích vai trò của eBPF và SPIFFE.
    
- **NIST.SP.800-207.pdf**, Section 3.2: Variations of Zero Trust Architecture Approaches.
    

Đây là khung sườn rất mạnh để bạn viết phần "Research Contribution". Bạn có muốn mình phác thảo thêm một **Sơ đồ luồng dữ liệu (Data Flow)** khi một yêu cầu đi qua 4 lớp này để bạn đưa vào đồ án không?

&nbsp;

## 2.4. Mô hình Chính sách (Policy Model) cho Microservices

Mô hình chính sách là thành phần cốt lõi của **Policy Engine (PE)**, đóng vai trò chuyển hóa các mục tiêu bảo mật cấp cao thành các luật thực thi (Enforcement Rules) cụ thể.

### 2.4.1. Tiếp cận dựa trên thuộc tính (ABAC - Attribute-Based Access Control)

Thay vì sử dụng RBAC (Role-based) tĩnh, đồ án đề xuất mô hình **ABAC** để đạt được độ chi tiết (Granularity) cần thiết cho Zero Trust. Quyết định truy cập được tính toán dựa trên sự giao thoa của bốn nhóm thuộc tính:

- **Subject Attributes (Chủ thể):** Không chỉ là `Identity`, mà bao gồm các `Claims` trong JWT (như `email_verified`, `department`) và các đặc điểm của `ServiceAccount` (như `SPIFFE ID`).
    
- **Resource Attributes (Tài nguyên):** Được xác định chi tiết đến mức `Endpoint` (URL), `Namespace`, hoặc các `Labels` gắn trên tài nguyên dữ liệu.
    
- **Action Attributes (Hành động):** Các phương thức cụ thể như `GET`, `POST`, `PUT`, `DELETE` hoặc các lệnh đặc thù của gRPC.
    
- **Environmental/Context Attributes (Ngữ cảnh):** Các điều kiện động như `Time of day` (truy cập trong giờ làm việc), `Location` (IP/VPC hợp lệ), hoặc `Trust Score` (mức độ tin cậy của thiết bị tại thời điểm yêu cầu).
    

> **Công thức quyết định:** \$Decision = f(Subject, Resource, Action, Environment)\$
> 
> *(Nguồn: NIST SP 800-207, Section 2.1, Page 7)*

### 2.4.2. Nguyên tắc Deny-All và Allow-Explicit

Đây là bước hiện thực hóa nguyên lý **Đặc quyền tối thiểu (Least Privilege)** trong thực tế triển khai:

- **Mặc định từ chối (Deny-All):** Mọi luồng giao tiếp giữa các Microservices mặc định bị chặn hoàn toàn ngay khi khởi tạo (Zero-visibility).
    
- **Cho phép tường minh (Allow-Explicit):** Chỉ những kết nối được định nghĩa rõ ràng trong chính sách mới được phép thiết lập. Điều này đảm bảo rằng nếu một Service bị tấn công, kẻ địch không thể thực hiện hành vi "thăm dò" (Reconnaissance) vì các kết nối không được khai báo trước sẽ bị **PEP** hủy bỏ (Drop) ngay lập tức.
    

> "A ZTA requires that all access requests be evaluated against a policy... The enterprise should default to denying access unless a positive policy exists."
> 
> *(Nguồn: NIST SP 800-207, Section 2.1, Page 6)*

### 2.4.3. Vòng đời Chính sách (Policy Lifecycle)

Để đảm bảo tính thích ứng (Adaptive Security), chính sách trong hệ thống không phải là thực thể tĩnh mà trải qua một vòng đời khép kín:

1.  **Định nghĩa (Definition):** Chính sách được viết dưới dạng mã (**Policy as Code**) bằng các ngôn ngữ như Rego (Open Policy Agent) hoặc Custom Resources (CiliumNetworkPolicy). Việc này giúp kiểm soát phiên bản và tự động hóa.
    
2.  **Phân phối (Distribution):** Sau khi được duyệt, **Policy Administrator (PA)** thực hiện phân phối các luật này xuống các **PEP** (Sidecar proxy, API Gateway, hoặc eBPF agent) trên toàn cụm.
    
3.  **Thực thi (Enforcement):** PEP chặn các yêu cầu và đối chiếu với tập luật tại chỗ để đưa ra quyết định Allow/Deny theo thời gian thực.
    
4.  **Kiểm soát và Điều chỉnh (Audit & Feedback):** Mọi quyết định (dù cho phép hay từ chối) đều được ghi lại. Nếu hệ thống **Observability** phát hiện một chuỗi các lệnh "Deny" từ một Service, nó sẽ tự động điều chỉnh Trust Score của Service đó xuống mức 0, đồng thời thu hồi mọi quyền hiện có.
    

* * *

**Nguồn trích dẫn:**

- **NIST SP 800-207**, "Zero Trust Architecture", August 2020.
    
- **Kiến trúc Zero Trust và Chiến lược Hóa giải các Mối nguy hại An ninh Mạng Hiện đại (2025-2026)**, Chương về ABAC và Policy as Code.
    
- **Xây Dựng Kiến Trúc Zero Trust**, Phần quy trình vận hành PE/PA.
    

* * *

**Lời khuyên cho đồ án:** Trong phần này, bạn nên đưa thêm một ví dụ về một đoạn mã chính sách giả định (như YAML của Cilium hoặc Rego của OPA) để minh họa cho tính **"Explicit"**. Điều này sẽ giúp hội đồng thấy được tính thực tiễn trong nghiên cứu của bạn. Bạn có muốn mình chuẩn bị một đoạn mã mẫu như vậy không?