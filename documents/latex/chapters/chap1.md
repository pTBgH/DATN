## 1.1. Từ Perimeter-based đến Zero Trust

### 1.1.1. Mô hình tin cậy dựa trên vị trí mạng và những lỗ hổng nội tại

Trong nhiều thập kỷ, an ninh mạng truyền thống được xây dựng theo mô hình **phòng thủ chu vi (Perimeter-based defense)**, hay còn gọi là chiến lược **"Lâu đài và Hào nước" (Castle-and-Moat)**.

- **Cơ chế hoạt động:** Thiết lập một ranh giới cứng giữa mạng nội bộ (tin cậy) và Internet (rủi ro) thông qua các thiết bị như tường lửa (Firewall), VPN và hệ thống IDS/IPS.
    
- **Tin cậy ngầm định (Implicit Trust):** Bất kỳ thực thể nào (người dùng, thiết bị) một khi đã vượt qua chu vi mạng để vào bên trong đều mặc định được coi là an toàn và có quyền truy cập rộng rãi vào tài nguyên hệ thống.
    

**Các lỗ hổng nội tại và thực trạng:**

- **Di chuyển ngang (Lateral Movement):** Một khi kẻ tấn công vượt qua "hào nước" (bằng phishing hoặc chiếm đoạt tài khoản), chúng có thể tự do trinh sát và tấn công các tài sản quan trọng bên trong mạng nội bộ mà không gặp rào cản nào.
    
- **Sự biến mất của chu vi:** Các xu hướng như điện toán đám mây (Cloud), làm việc từ xa (Remote work) và thiết bị cá nhân (BYOD) đã khiến ranh giới mạng không còn tồn tại ở một vị trí vật lý cố định.
    
- **Mối đe dọa từ bên trong:** Mô hình cũ hoàn toàn bất lực trước những nhân viên có ý đồ xấu hoặc các thiết bị nội bộ đã bị nhiễm mã độc.
    

> **Ví dụ cụ thể:** Trong vụ tấn công chuỗi cung ứng **SolarWinds**, kẻ tấn công đã cài mã độc vào bản cập nhật phần mềm hợp lệ. Do hệ thống tin cậy ngầm định các phần mềm đã ở trong mạng, mã độc dễ dàng di chuyển ngang và phá hủy mạng lưới của nhiều cơ quan chính phủ mà không bị phát hiện.

* * *

### 1.1.2. Định nghĩa Zero Trust theo NIST SP 800-207

Theo ấn bản đặc biệt **NIST SP 800-207**, Zero Trust không phải là một sản phẩm đơn lẻ mà là một tập hợp các khái niệm nhằm giảm thiểu sự thiếu chắc chắn trong việc thực thi các quyết định truy cập.

- **Giả định mạng luôn bị xâm nhập (Network viewed as compromised):** Zero Trust hoạt động với tư duy rằng kẻ địch luôn hiện diện trên mạng. Do đó, môi trường do doanh nghiệp sở hữu không được tin cậy hơn bất kỳ mạng công cộng nào.
    
- **Giảm thiểu sự thiếu chắc chắn (Minimize uncertainty):** Thay vì tin vào vị trí mạng, hệ thống tập trung vào việc xác thực và ủy quyền liên tục dựa trên các dữ liệu động.
    
- **Đặc quyền tối thiểu trên mỗi yêu cầu (Least privilege per-request):** Quyền truy cập chỉ được cấp ở mức vừa đủ để hoàn thành tác vụ, trên cơ sở từng phiên làm việc (per-session) và phải được thẩm định riêng biệt cho mỗi tài nguyên.
    

> **Ví dụ cụ thể:** Một nhân viên truy cập ứng dụng kế toán từ văn phòng. Thay vì chỉ kiểm tra mật khẩu một lần, hệ thống ZTA sẽ kiểm tra thêm: Thiết bị có được cài bản vá mới nhất không? Vị trí địa lý có bất thường không? Nếu mọi thứ ổn, hệ thống chỉ cấp quyền "đọc" trong 60 phút. Sau 60 phút hoặc khi sang ứng dụng khác, nhân viên phải được xác thực lại.

* * *

### 1.1.3. Phân biệt Zero Trust (ZT), ZTA và Zero Trust Enterprise

Để triển khai chính xác, NIST SP 800-207 phân định rõ ba khái niệm này nhằm giúp các kiến trúc sư bảo mật xây dựng lộ trình phù hợp:

1.  **Zero Trust (ZT - Khái niệm):**
    
    - Là một tập hợp các nguyên lý và ý tưởng thiết kế (ví dụ: "luôn luôn xác minh").
        
    - Mục tiêu: Ngăn chặn truy cập trái phép và hạn chế thiệt hại khi có vi phạm.
        
2.  **Zero Trust Architecture (ZTA - Kế hoạch triển khai):**
    
    - Là bản thiết kế kỹ thuật cụ thể cho một doanh nghiệp, sử dụng các nguyên lý ZT.
        
    - Bao gồm việc thiết lập các thành phần logic như: **Policy Engine (PE)**, **Policy Administrator (PA)** và **Policy Enforcement Point (PEP)**.
        
3.  **Zero Trust Enterprise (Kết quả vận hành):**
    
    - Là trạng thái cuối cùng khi hạ tầng mạng và các chính sách vận hành của doanh nghiệp đã thực thi đầy đủ theo kế hoạch ZTA.
        
    - Đây là một môi trường thực tế nơi mọi luồng công việc đều được bảo vệ bởi Zero Trust.
        

> **Ví dụ cụ thể:**
> 
> - **ZT:** Giám đốc CNTT quyết định áp dụng triết lý "không tin tưởng bất cứ ai". \* **ZTA:** Đội ngũ kỹ thuật thiết kế sơ đồ lắp đặt các cổng ZTNA, cấu hình các chính sách xác thực đa yếu tố (MFA) và vi phân đoạn (Micro-segmentation) cho cơ sở dữ liệu. \* **Zero Trust Enterprise:** Công ty vận hành ổn định trên nền tảng Cloud, nhân viên làm việc tại quán cafe vẫn truy cập dữ liệu an toàn mà không cần VPN truyền thống, và mọi nỗ lực xâm nhập đều bị PEP chặn đứng ngay lập tức.

* * *

**Nguồn trích dẫn chính trong mục này:**

- **NIST SP 800-207**, "Zero Trust Architecture", August 2020. (Nguồn: NIST.SP.800-207.pdf)
    
- **Xây Dựng Kiến Trúc Zero Trust**, Phân tích chuyên sâu và lộ trình triển khai. (Nguồn: Xây Dựng Kiến Trúc Zero Trust.pdf)
    
- **Vai trò IAM/IdP trong Zero Trust**, Báo cáo cơ chế hoạt động IAM. (Nguồn: Vai trò IAM/IDP trong Zero Trust.pdf)


## 1.2. Các nguyên lý cốt lõi của ZTA (7 Tenets — NIST SP 800-207)

### 1.2.1. Phân tích 7 nguyên lý cơ bản và ý nghĩa thực tiễn

Kiến trúc Zero Trust (ZTA) được xây dựng trên 7 nguyên lý (tenets) cốt lõi, đóng vai trò là "kim chỉ nam" cho mọi quyết định thiết kế và vận hành hệ thống:

1.  **Coi tất cả các nguồn dữ liệu và dịch vụ tính toán là tài nguyên:** Không chỉ máy chủ hay cơ sở dữ liệu, mà mọi thiết bị IoT, microservices và API đều phải được bảo vệ.
    
    - *Ý nghĩa:* Đảm bảo không tồn tại "điểm mù" trong hệ sinh thái kỹ thuật số.
2.  **Bảo mật mọi giao tiếp bất kể vị trí mạng:** Loại bỏ khái niệm "vùng tin cậy ẩn" bên trong mạng nội bộ. Mọi kết nối đều phải được mã hóa và xác thực.
    
    - *Ý nghĩa:* Ngăn chặn kẻ tấn công lợi dụng kết nối nội bộ sau khi đã xâm nhập qua chu vi.
3.  **Cấp quyền truy cập trên cơ sở từng phiên làm việc (per-session):** Quyền truy cập được đánh giá trước mỗi lần thiết lập kết nối và chỉ cung cấp đặc quyền tối thiểu.
    
    - *Ý nghĩa:* Việc xác thực vào một tài nguyên không tự động mang lại quyền truy cập vào tài nguyên khác.
4.  **Xác định quyền truy cập bằng chính sách động:** Quyết định dựa trên ngữ cảnh thực tế như nhận dạng chủ thể, tư thế bảo mật thiết bị (device posture), hành vi và môi trường (thời gian, vị trí).
    
    - *Ý nghĩa:* Tăng tính thích ứng và độ chính xác của các quyết định bảo mật.
5.  **Giám sát và đo lường tính toàn vẹn của mọi tài sản:** Doanh nghiệp phải liên tục đánh giá trạng thái an ninh của thiết bị (ví dụ: đã vá lỗi chưa, có mã độc không).
    
    - *Ý nghĩa:* Chỉ thiết bị đạt tiêu chuẩn mới được phép tham gia vào luồng công việc.
6.  **Xác thực và ủy quyền nghiêm ngặt trước khi cho phép truy cập:** Đây là quá trình liên tục, bao gồm sử dụng xác thực đa yếu tố (MFA) và giám sát để tái xác thực khi điều kiện rủi ro thay đổi.
    
    - *Ý nghĩa:* Loại bỏ sự tin cậy ngầm định dựa trên thông tin xác thực tĩnh.
7.  **Thu thập tối đa thông tin để cải thiện tư thế bảo mật:** Thu thập nhật ký (logs), dữ liệu giám sát và tình báo đe dọa để nuôi dưỡng các thuật toán phân tích.
    
    - *Ý nghĩa:* Tạo cơ sở để tinh chỉnh chính sách và phản ứng tự động theo thời gian thực.

> **Ví dụ thực tế:** Một lập trình viên sử dụng laptop cá nhân (BYOD) truy cập mã nguồn công ty từ quán cafe. Theo Tenet 4 & 5, hệ thống sẽ kiểm tra: Laptop có bật firewall không? Có bị nhiễm malware không? Nếu đạt, hệ thống cấp quyền truy cập chỉ cho repo dự án hiện tại (Tenet 3) và yêu cầu MFA lại nếu họ chuyển sang mạng Wi-Fi khác (Tenet 6).

* * *

### 1.2.2. Mô hình logic bắt buộc trong ZTA

Để thực thi 7 nguyên lý trên, NIST SP 800-207 yêu cầu một kiến trúc logic tách biệt giữa mặt phẳng điều khiển (control plane) và mặt phẳng dữ liệu (data plane) thông qua ba thành phần trọng yếu:

- **Policy Engine (PE - Động cơ chính sách):** Được coi là "bộ não" phân tích trung tâm. PE sử dụng thuật toán tin cậy để tính toán rủi ro và đưa ra phán quyết cuối cùng về việc cấp, từ chối hoặc thu hồi quyền truy cập.
    
- **Policy Administrator (PA - Quản trị viên chính sách):** Đóng vai trò cơ quan "hành pháp". PA tiếp nhận phán quyết từ PE, sinh ra các mã thông báo (tokens) hoặc thông tin xác thực phiên và ra lệnh cho các điểm thực thi mở/đóng kết nối.
    
- **Policy Enforcement Point (PEP - Điểm thực thi chính sách):** Là "người gác cổng" ở tiền tuyến. PEP trực tiếp giám sát luồng lưu lượng, chặn các yêu cầu và thực hiện cho phép hoặc ngắt kết nối dựa trên lệnh từ PA.
    

* * *

### 1.2.3. Vòng đời của một quyết định truy cập (Access Decision Lifecycle)

Vòng đời của một yêu cầu truy cập trong môi trường ZTA diễn ra theo một quy trình khép kín và liên tục:

1.  **Yêu cầu (Subject Request):** Chủ thể (người dùng, ứng dụng hoặc máy móc) gửi yêu cầu truy cập tài nguyên. Yêu cầu này ngay lập tức bị chặn bởi **PEP**.
    
2.  **Đánh giá (PE Evaluate):** PEP chuyển ngữ cảnh yêu cầu (danh tính, thiết bị, vị trí) tới **PE**. PE tổng hợp dữ liệu từ các nguồn thông tin (IdP, Threat Intel, MDM) để đánh giá theo thuật toán tin cậy.
    
3.  **Phân phối (PA Distribute):** Nếu yêu cầu hợp lệ, PE gửi lệnh phê duyệt tới **PA**. PA tạo thông tin xác thực phiên (như JWT token) và gửi cấu hình đường dẫn tới PEP.
    
4.  **Thực thi (PEP Enforce):** PEP mở "cổng" trên mặt phẳng dữ liệu, cho phép luồng giao dịch diễn ra dưới sự giám sát chặt chẽ.
    
5.  **Giám sát liên tục:** Trong suốt phiên làm việc, nếu phát hiện hành vi bất thường hoặc rủi ro thiết bị tăng cao, PE sẽ lập tức ra lệnh cho PA chỉ thị PEP đóng kết nối ngay lập tức (thu hồi quyền truy cập).
    

> **Ví dụ về vòng đời:** Khi một nhân viên Marketing tải tệp tin từ Server công ty (Yêu cầu), PEP chặn lại và hỏi PE. PE thấy thiết bị sạch nhưng nhân viên đang ở vùng địa lý lạ nên báo PA yêu cầu thêm MFA. Sau khi nhân viên nhập MFA (Đánh giá xong), PA cấp token cho PEP mở kết nối (Thực thi). Nếu giữa chừng nhân viên tải quá nhiều dữ liệu bất thường, PE ra lệnh PEP ngắt kết nối ngay (Kết thúc vòng đời).

* * *

**Nguồn trích dẫn:**

- **NIST SP 800-207**, "Zero Trust Architecture", August 2020.
    
- **Xây Dựng Kiến Trúc Zero Trust**, Phân tích chuyên sâu và lộ trình triển khai.
    
- **Vai trò IAM/IDP trong Zero Trust**, Báo cáo vai trò danh tính


Dưới đây là nội dung chi tiết cho mục **1.3** để hoàn thiện chương 1 trong đồ án của bạn. Phần này tập trung vào các phương thức hiện thực hóa lý thuyết Zero Trust vào hạ tầng thực tế.

* * *

## 1.3. Ba hướng triển khai ZTA (Approaches to ZTA)

NIST SP 800-207 xác định rằng không có một kiến trúc duy nhất cho mọi doanh nghiệp. Thay vào đó, có ba hướng tiếp cận chính tùy thuộc vào hạ tầng và mục tiêu bảo mật:

### 1.3.1. Enhanced Identity Governance (Lấy định danh làm gốc)

Đây là hướng tiếp cận tập trung vào việc quản lý vòng đời và quyền hạn của các thực thể (người dùng, thiết bị, dịch vụ).

- **Cơ chế:** Quyết định truy cập dựa trên các chính sách định danh (Identity-centric). Chỉ những thực thể có định danh được xác thực mạnh (MFA) và có thuộc tính (Attributes) phù hợp mới được cấp quyền.
    
- **Thực thi:** Thường sử dụng các giải pháp IAM (Identity and Access Management) hiện đại kết hợp với IdP (Identity Provider) để cấp quyền truy cập vào các ứng dụng phần mềm (SaaS) hoặc tài nguyên đám mây.
    

### 1.3.2. Micro-segmentation (Phân đoạn mạng vi mô)

Hướng tiếp cận này tập trung vào việc bảo vệ các luồng dữ liệu bên trong mạng bằng cách chia nhỏ hạ tầng thành các phân đoạn cực nhỏ.

- **Cơ chế:** Đặt các rào cản bảo mật (như Firewall ảo, Identity-based policies) bao quanh từng workload hoặc nhóm tài nguyên nhỏ. Điều này ngăn chặn luồng lưu lượng "East-West" (ngang) trái phép.
    
- **Thực thi:** Thường được triển khai thông qua các thiết bị mạng thế hệ mới (NGFW), Service Mesh (như Istio) trong Kubernetes, hoặc các giải pháp SDN (Software Defined Networking).
    

> **Ví dụ:** Trong một cụm Microservices, Service A chỉ có thể gọi sang Service B thông qua một cổng kiểm soát chặt chẽ, ngay cả khi cả hai nằm trên cùng một máy chủ vật lý.

### 1.3.3. Software Defined Perimeter (SDP - Chu vi xác định bằng phần mềm)

SDP thực hiện nguyên lý "Black Cloud" – làm ẩn hoàn toàn tài nguyên khỏi mạng công cộng và chỉ "mở" ra khi thực thể đã được xác thực thành công.

- **Cơ chế:** Sử dụng kiến trúc tách biệt Control Plane và Data Plane. Một thiết bị (Client) phải xác thực với SDP Controller trước, sau đó Controller mới chỉ định cho SDP Gateway mở một kết nối tạm thời đến tài nguyên.
    
- **Thực thi:** Thay thế VPN truyền thống bằng mô hình ZTNA (Zero Trust Network Access). Tài nguyên không có địa chỉ IP công khai và không phản hồi các yêu cầu quét mạng (Port scanning).
    

* * *

### 1.3.4. So sánh các hướng triển khai

Việc lựa chọn hướng tiếp cận phụ thuộc vào mức độ trưởng thành của hệ thống và loại tài nguyên cần bảo vệ:

| **Tiêu chí** | **Enhanced Identity Governance** | **Micro-segmentation** | **Software Defined Perimeter (SDP)** |
| --- | --- | --- | --- |
| **Đối tượng tập trung** | Con người và quyền hạn (Identity) | Workload và luồng mạng (Network) | Kết nối giữa Client và Resource |
| **Ưu điểm** | Dễ triển khai cho môi trường Cloud/SaaS; quản lý tập trung. | Ngăn chặn tối đa việc di chuyển ngang (Lateral Movement). | Ẩn hoàn toàn tài nguyên, chống tấn công DDoS và quét mạng. |
| **Nhược điểm** | Phụ thuộc hoàn toàn vào độ tin cậy của IdP. | Cấu hình phức tạp, khó duy trì trong mạng quy mô lớn. | Cần cài đặt Agent trên thiết bị đầu cuối (thường xuyên). |
| **Khi nào sử dụng?** | Doanh nghiệp ưu tiên quản lý người dùng và ứng dụng web. | Trung tâm dữ liệu lớn, kiến trúc Microservices (K8s). | Cấp quyền cho nhân viên làm việc từ xa truy cập App nội bộ. |

* * *

**Nguồn trích dẫn:**

- **NIST SP 800-207**, "Zero Trust Architecture", August 2020. (Nguồn: NIST.SP.800-207.pdf)
    
- **Bảo mật thích ứng trong Zero Trust**, Phân tích các mô hình triển khai thực tế. (Nguồn: Bảo mật thích ứng trong Zero Trust.pdf)
    
- **Xây Dựng Kiến Trúc Zero Trust**, Chương về SDP và Micro-segmentation. (Nguồn: Xây Dựng Kiến Trúc Zero Trust.pdf)
    

Bạn có muốn mình bổ sung thêm sơ đồ so sánh chi tiết hơn về mặt kỹ thuật giữa VPN truyền thống và SDP để làm nổi bật sự khác biệt không?

## 1.4. Mô hình đe dọa trong ZTA (Threat Modeling)

### 1.4.1. Attack Surface của doanh nghiệp số: Sự biến mất của biên giới

Bề mặt tấn công hiện nay không còn là một chu vi có thể bao bọc mà là một tập hợp các tài nguyên phân tán. Sự bùng nổ của điện toán đám mây, làm việc từ xa và thiết bị di động đã biến các giả định về sự tin cậy dựa trên vị trí mạng thành một "lỗ hổng chí tử".

- **Sự khủng hoảng định danh:** Định danh đã trở thành vành đai bảo mật mới và là mục tiêu hàng đầu. Thông tin xác thực bị thỏa hiệp chiếm khoảng **20,5%** các vụ vi phạm.
    
- **Shadow IT và Thiết bị không kiểm soát:** Các ứng dụng SaaS tự ý và thiết bị BYOD tạo ra những "điểm mù" khổng lồ, nơi mã độc có thể lây nhiễm từ mạng gia đình vào hạ tầng công ty.
    

### 1.4.2. Các mối đe dọa trọng tâm và Cơ chế hóa giải của ZTA

ZTA vận hành dựa trên tư duy **"Giả định bị vi phạm" (Assume Breach)**, luôn hoạt động như thể kẻ tấn công đã ở bên trong mạng.

#### A. Thỏa hiệp định danh và Tấn công AiTM

Các hình thức MFA truyền thống (OTP/SMS) dễ bị đánh bại bởi kỹ thuật **Adversary-in-the-Middle (AiTM)** thông qua proxy ngược.

- **Giải pháp:** ZTA yêu cầu MFA chống phishing (như FIDO2) để ràng buộc mã xác thực với tên miền dịch vụ hợp lệ.
    
- **Chiếm đoạt phiên (Token Theft):** Để chống lại việc đánh cắp cookie/token OAuth, ZTA sử dụng **Đánh giá truy cập liên tục (CAE)** và **Ràng buộc thiết bị (Device Binding)** để thu hồi quyền ngay khi bối cảnh (IP, thiết bị) thay đổi.
    

#### B. Di chuyển ngang (Lateral Movement) và Ransomware

Mạng truyền thống cho phép kẻ tấn công di chuyển tự do sau khi chiếm được một điểm duy nhất.

- **Phân đoạn vi mô (Microsegmentation):** Chia tài nguyên thành các vùng cô lập logic. Nếu một khoang bị "rò rỉ", các vách ngăn sẽ ngăn chặn thiệt hại lan rộng (Blast Radius).
    
- **Hiệu quả:** Trong mạng ZT, thời gian ngăn chặn di chuyển ngang trung bình giảm từ **48 phút** xuống còn **18 phút**.
    

#### C. Kỹ thuật "Living Off the Land" (LotL)

Kẻ tấn công lạm dụng các công cụ hợp lệ (PowerShell, WMI, RDP) để ẩn mình, khiến phần mềm diệt virus truyền thống trở nên vô hiệu.

- **Giải pháp:** Chuyển từ kiểm tra "cái gì" (mã độc) sang kiểm tra "như thế nào" (hành vi) thông qua **UEBA (User and Entity Behavior Analytics)**. ZTA nhận diện sai lệch hành vi (như quản trị viên quét mạng vào nửa đêm) để chặn đứng LotL.

#### D. Tấn công Chuỗi cung ứng và Golden SAML

Vụ việc SolarWinds cho thấy mã độc có thể nằm trong ứng dụng "tin cậy".

- **Chặn C2:** ZTA áp dụng đặc quyền tối thiểu cho mạng, chặn mọi kết nối đi (egress) từ máy chủ đến các địa chỉ lạ, khiến mã độc bị "câm lặng".
    
- **Golden SAML:** Đối phó bằng cách yêu cầu **MFA không thể bỏ qua** tại điểm thực thi (PEP) cho mọi yêu cầu tài nguyên, ngay cả khi kẻ tấn công có mã thông báo giả mạo.
    

### 1.4.3. MITRE ATT&CK Enterprise: Mapping kỹ thuật tấn công vào ZTA

| **Chiến thuật (Tactic)** | **Kỹ thuật (Technique)** | **Cơ chế đối phó của ZTA** |
| --- | --- | --- |
| **Initial Access** | Valid Accounts (T1078) | **Tenet 6:** Xác thực liên tục và MFA chống Phishing. |
| **Lateral Movement** | Remote Services (T1021) | **Phân đoạn vi mô:** Ngăn chặn lưu lượng "Đông-Tây" không được phép. |
| **Persistence** | Token Theft (T1539) | **CAE & Device Binding:** Ràng buộc mã thông báo với thiết bị cụ thể. |
| **Command & Control** | Application Layer Protocol | **Egress Filtering:** Chỉ cho phép kết nối đến các Endpoint được chỉ định. |
| **Impact** | Data Encrypted (Ransomware) | **JIT Access:** Hạn chế quyền hạn tối thiểu để thu hẹp phạm vi dữ liệu bị ảnh hưởng. |

* * *

**Nguồn trích dẫn trực tiếp từ tài liệu đính kèm:**

- **Kiến trúc Zero Trust và Chiến lược Hóa giải các Mối nguy hại An ninh Mạng Hiện đại (2025-2026)**.
    
- **NIST SP 800-207**, "Zero Trust Architecture".
    
- **Báo cáo về MFA và Token Theft**.
    

Bạn có thể đưa phần này vào đồ án để chứng minh khả năng phòng thủ của ZTA trước các cuộc tấn công tinh vi nhất hiện nay. Bạn cần mình chi tiết hóa thêm bảng so sánh nào khác không?

