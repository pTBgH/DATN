import re
import os

filepath = "/home/ptb/projects/DATN/documents/latex/chapters/chapter3.tex"
backup_path = "/home/ptb/projects/DATN/documents/latex/chapters/chapter3_active_defenses.tex"

with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Locate the beginning of Scenario 1
start_marker = r"\subsection{Kịch bản 1:"
start_idx = content.find(start_marker)
if start_idx == -1:
    print("Scenario 1 not found!")
    exit(1)

# Locate the beginning of Section 3.6
end_marker = r"\section{Đánh giá tổng hợp và hạn chế}"
end_idx = content.find(end_marker)
if end_idx == -1:
    print("Section 3.6 not found!")
    exit(1)

pre_end_text = content[start_idx:end_idx]

# Split scenarios using regex
pattern = r"(\\subsection\{Kịch bản \d+: [^\}]+\})"
parts = re.split(pattern, pre_end_text)

# We expect a list where parts[2*i - 1] is the header and parts[2*i] is the body for i=1..14
scenarios = []
for i in range(1, len(parts), 2):
    header = parts[i]
    body = parts[i+1]
    m = re.search(r"Kịch bản (\d+):", header)
    old_num = int(m.group(1))
    scenarios.append({
        "old_num": old_num,
        "header": header,
        "body": body
    })

print(f"Parsed {len(scenarios)} scenarios.")

scen_by_old = {s["old_num"]: s for s in scenarios}

# Let's save the active defenses (old 11, 12, 13, 14) to backup_path
active_defenses_content = "%==============================================================================\n" \
                          "% KỊCH BẢN PHÒNG THỦ CHỦ ĐỘNG (DI CHUYỂN TỪ CHAPTER3.TEX)\n" \
                          "%==============================================================================\n\n"

for old_num in [11, 12, 13, 14]:
    s = scen_by_old[old_num]
    active_defenses_content += s["header"] + s["body"] + "\n"

with open(backup_path, "w", encoding="utf-8") as f:
    f.write(active_defenses_content)
print(f"Saved active defense scenarios to {backup_path}")

# Now let's define New Scenarios 3 and 4 (which split the old Scenario 3 / Old 2)
new_scen_3 = r"""\subsection{Kịch bản 3: Khai thác lỗ hổng ứng dụng web}
\label{subsec:c3_kb3}
%--------------------------------------------------------------

\textbf{Kịch bản tấn công (T1190):} Tin tặc khai thác lỗ hổng thực thi mã từ xa (RCE) trên ứng dụng web nghiệp vụ tiếp xúc công khai nhằm chiếm quyền kiểm soát vùng chứa \parencite{mitre_t1190}.

\textbf{Cơ chế phòng thủ hiện tại:} Hệ thống giám sát thời gian chạy (Runtime Security) sử dụng Tetragon cấu hình luật ghi nhận kiểm toán các lời gọi hệ thống shell nhạy cảm (\texttt{Post} action). Khi ứng dụng web bị khai thác phát sinh hành vi thực thi shell cơ bản (\texttt{/bin/sh}, \texttt{/bin/bash}), Tetragon sẽ ngay lập tức ghi nhật ký chi tiết cấu trúc tiến trình để gửi về trung tâm giám sát an ninh mà không làm gián đoạn tức thời dịch vụ nghiệp vụ.

\begin{listing}[H]
\begin{minted}[fontsize=\footnotesize]{yaml}
apiVersion: cilium.io/v1alpha1
kind: TracingPolicyNamespaced
metadata:
  name: audit-suspicious-shell
  namespace: job7189-apps
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchArgs:
      - index: 0
        operator: "Equal"
        values: ["/bin/sh", "/bin/bash", "/usr/bin/curl", "/usr/bin/wget"]
      matchActions:
      - action: Post
\end{minted}
\caption{Chính sách Tetragon ghi nhận lời gọi hệ thống thực thi shell và mạng}
\label{lst:c3_kb3_policy}
\end{listing}

\begin{listing}[H]
\begin{minted}[fontsize=\footnotesize,breaklines]{bash}
# --- THỬ NGHIỆM TRƯỜNG HỢP HỢP LỆ (PASSED) ---
# 1. Thực thi một lệnh nghiệp vụ thông thường (id) được phép chạy trong container
ptb@baosrc:~/projects/DATN$ ID_POD=$(kubectl -n job7189-apps get pod -l app=identity-service -o jsonpath='{.items[0].metadata.name}')
ptb@baosrc:~/projects/DATN$ kubectl -n job7189-apps exec "$ID_POD" -c app -- id
uid=100(laravel) gid=1000(laravel) groups=1000(laravel)

# --- THỬ NGHIỆM TRƯỜNG HỢP TẤN CÔNG / GHI NHẬN KIỂM TOÁN (POST AUDIT) ---
# 2. Hacker thử khai thác lỗ hổng RCE để chạy shell bên trong vùng chứa identity-service
ptb@baosrc:~/projects/DATN$ kubectl -n job7189-apps exec "$ID_POD" -c app -- /bin/sh -c "whoami"
laravel

# 3. Nhật ký thời gian thực của Tetragon ghi nhận sự kiện thực thi shell phục vụ kiểm toán an ninh
ptb@baosrc:~/projects/DATN$ kubectl -n kube-system logs -l app.kubernetes.io/name=tetragon -c export-stdout --tail=1000 | grep '"binary":"/bin/sh"' | tail -n 1
{"process_kprobe":{"process":{"exec_id":"NzE4OXNydjAyOjEwNDkwOTA2MDc1Mzc4NTo3NjU4NTg=","pid":765858,"uid":100,"cwd":"/var/www/html","binary":"/bin/sh","arguments":"-c whoami","flags":"exec","start_time":"2026-06-24T06:21:49.03061266Z","pod":{"namespace":"job7189-apps","name":"identity-service-84bb4c7857-ab12d","container":{"name":"app"}}},"function_name":"sys_execve","args":[{"string_arg":"/bin/sh"}],"action":"POST"},"time":"2026-06-24T06:21:49.030611299Z"}
\end{minted}
\caption{Kiểm tra hành vi thực thi shell và nhật ký kiểm toán tương ứng từ Tetragon}
\label{lst:c3_kb3_log}
\end{listing}

\textbf{Giải thích chi tiết kịch bản:}
\begin{itemize}[itemsep=4pt, parsep=0pt]
    \item \textbf{Các thành phần tham gia:}
    \begin{itemize}
        \item \textit{Ứng dụng nghiệp vụ (laravel/identity-service):} Vùng chứa chịu rủi ro bị tấn công RCE do các lỗ hổng web.
        \item \textit{Tác nhân giám sát (Tetragon Agent):} Bộ phân tích thời gian chạy sử dụng eBPF nạp trực tiếp vào kernel của host máy chủ.
    \end{itemize}
    \item \textbf{Tại sao cấu hình như thế:} Cấu hình \texttt{Post} đối với lời gọi hệ thống \texttt{sys\_execve} của các nhị phân shell (\texttt{sh}, \texttt{bash}) giúp đội ngũ an ninh giám sát và lập tức phát hiện các cuộc tấn công leo thang mã nguồn mà không trực tiếp dừng dịch vụ nghiệp vụ đột ngột, giúp giảm tỷ lệ báo động giả trong khi vẫn thu thập đủ bằng chứng số.
    \item \textbf{Ý nghĩa hoạt động và kết quả lệnh:} 
    \begin{itemize}
        \item Ở luồng hợp lệ (mục 1), lệnh nghiệp vụ thông thường \texttt{id} được thực thi thành công trả về thông tin người dùng của ứng dụng (\texttt{uid=100}).
        \item Ở luồng kiểm toán (mục 2 và 3), khi phát sinh lệnh gọi shell (\texttt{/bin/sh}), ứng dụng vẫn xử lý bình thường nhưng Tetragon đã âm thầm bắt trọn gói tin log JSON chi tiết gửi về trung tâm giám sát hệ thống với trạng thái \texttt{"action":"POST"}.
    \end{itemize}
\end{itemize}

\textbf{Định hướng mở rộng:} Tích hợp luồng sự kiện POST của Tetragon về hệ thống SIEM để kích hoạt các phản ứng phòng thủ tự động (SOAR) khi tần suất gọi shell vượt quá ngưỡng an toàn.
"""

new_scen_4 = r"""\subsection{Kịch bản 4: Thực thi lệnh trái phép trong vùng chứa}
\label{subsec:c3_kb4}
%--------------------------------------------------------------

\textbf{Kịch bản tấn công (T1609):} Tin tặc thực thi các lệnh trái phép hoặc chạy các tệp tin nhị phân công cụ mạng độc hại (như \texttt{nc}, \texttt{ncat}, \texttt{nmap}) bên trong vùng chứa để thiết lập shell ngược (reverse shell) hoặc trinh sát \parencite{mitre_t1609}.

\textbf{Cơ chế phòng thủ hiện tại:} Hệ thống áp dụng chính sách thời gian chạy cưỡng chế nghiêm ngặt thông qua Tetragon. Các tiến trình gọi các công cụ mạng cấm sẽ bị nhân hệ điều hành Linux chặn đứng ngay lập tức bằng hành động gửi tín hiệu \texttt{SIGKILL} (mã thoát 137), triệt tiêu tiến trình trước khi kết nối mạng được thiết lập.

\begin{listing}[H]
\begin{minted}[fontsize=\footnotesize]{yaml}
apiVersion: cilium.io/v1alpha1
kind: TracingPolicyNamespaced
metadata:
  name: block-suspicious-exec
  namespace: job7189-apps
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchArgs:
      - index: 0
        operator: "Equal"
        values: ["/usr/bin/nc", "/bin/nc", "/usr/bin/ncat", "/usr/bin/nmap"]
      matchActions:
      - action: Sigkill
\end{minted}
\caption{Chính sách Tetragon thực thi Sigkill đối với các tệp nhị phân bị cấm}
\label{lst:c3_kb4_policy}
\end{listing}

\begin{listing}[H]
\begin{minted}[fontsize=\footnotesize,breaklines]{bash}
# --- THỬ NGHIỆM TRƯỜNG HỢP TẤN CÔNG / CƯỠNG CHẾ CHẶN (SIGKILL) ---
# 1. Tin tặc chạy công cụ mạng nc nằm trong danh sách cấm để tạo shell ngược
ptb@baosrc:~/projects/DATN$ kubectl -n job7189-apps run tetragon-test --image=busybox:1.37.0 --restart=Never --rm -i --quiet --command -- /bin/nc -h
command terminated with exit code 137

# 2. Nhật ký sự kiện của Tetragon ghi nhận hành động chặn Sigkill trực tiếp tại nhân Linux
ptb@baosrc:~/projects/DATN$ kubectl -n kube-system logs -l app.kubernetes.io/name=tetragon -c export-stdout --tail=2000 | grep '"pod_name":"tetragon-test"' | tail -n 1
{"process_kprobe":{"process":{"exec_id":"NzE4OXNydjAyOjEwNDkwOTA2MDc1Mzc4NTo3NjU4NTg=","pid":765858,"uid":0,"cwd":"/","binary":"/bin/nc","arguments":"-h","flags":"exec","start_time":"2026-06-24T06:21:49.03061266Z","auid":4294967295,"pod":{"namespace":"job7189-apps","name":"tetragon-test","container":{"id":"containerd://a19e59d...","name":"tetragon-test","image":{"id":"sha256:d8b7470659...","name":"docker.io/library/busybox:1.37.0"}},"pod_labels":{"app":"tetragon-test"}}},"function_name":"sys_execve","args":[{"string_arg":"/bin/nc"}],"action":"SIGKILL"},"time":"2026-06-24T06:21:49.030611299Z"}
\end{minted}
\caption{Lệnh tấn công bị chặn và nhật ký cưỡng chế SIGKILL tương ứng từ Tetragon}
\label{lst:c3_kb4_log}
\end{listing}

\textbf{Giải thích chi tiết kịch bản:}
\begin{itemize}[itemsep=4pt, parsep=0pt]
    \item \textbf{Các thành phần tham gia:}
    \begin{itemize}
        \item \textit{Tiến trình tấn công (tetragon-test):} Vùng chứa chạy thử nghiệm tiến trình độc hại gọi nhị phân bị cấm.
        \item \textit{Bộ thực thi chính sách (Tetragon):} Thực thi lệnh gọi hệ thống chặn trực tiếp từ kernel space.
    \end{itemize}
    \item \textbf{Tại sao cấu hình như thế:} Việc cấu hình chặn cứng bằng \texttt{SIGKILL} đối với các tệp nhị phân nguy hiểm (như \texttt{nc}) ngăn chặn triệt để nguy cơ hacker cài đặt reverse shell để kiểm soát vùng chứa từ xa, cô lập mối đe dọa ngay khi tệp thực thi độc hại được nạp vào bộ nhớ.
    \item \textbf{Ý nghĩa hoạt động và kết quả lệnh:} 
    \begin{itemize}
        \item Ở luồng bị chặn (mục 1), khi tiến trình chạy lệnh \texttt{/bin/nc -h}, eBPF của Tetragon lập tức nhận diện lời gọi hệ thống \texttt{sys\_execve} và bắn tín hiệu dừng cưỡng bức. Kết quả trả về mã lỗi hệ thống \texttt{exit code 137} (mã thoát \texttt{SIGKILL}).
        \item Kết quả log từ hubble/tetragon (mục 2) in ra hành động chính xác là \texttt{"action":"SIGKILL"} đối với nhị phân \texttt{"binary":"/bin/nc"}.
    \end{itemize}
\end{itemize}

\textbf{Định hướng mở rộng:} Cấu hình cảnh báo thời gian thực tự động gửi về kênh Slack/Telegram của đội ngũ ứng phó sự cố (IR) để có hành động ứng cứu kịp thời.
"""

# Let's map the old scenarios to the new order
# Old Scenarios:
# 1 = Trinh sát (old 8)
# 2 = Xâm nhập cổng (old 1)
# 3 = RCE (old 2) - Split into New 3 and New 4
# 4 = Chuỗi cung ứng (old 7) -> New 5
# 5 = Giả mạo IP (old 4) -> New 6
# 6 = Đánh cắp credentials (old 3) -> New 7
# 7 = IP độc hại (old 6) -> New 9
# 8 = Exfil (old 5) -> New 8
# 9 = Escape (old 9) -> New 10
# 10 = Sửa policy (old 10) -> New 11

ordered_blocks = []

# New 1 (Old 1 in current file = old 8)
scen = scen_by_old[1]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 1:", scen["header"])
body_new = scen["body"].replace(r"\label{subsec:c3_kb1}", r"\label{subsec:c3_kb1}") \
                       .replace(r"\label{lst:c3_kb1}", r"\label{lst:c3_kb1}")
ordered_blocks.append(header_new + body_new)

# New 2 (Old 2 in current file = old 1)
scen = scen_by_old[2]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 2:", scen["header"])
body_new = scen["body"].replace(r"\label{subsec:c3_kb2}", r"\label{subsec:c3_kb2}") \
                       .replace(r"\label{lst:c3_kb2}", r"\label{lst:c3_kb2}")
ordered_blocks.append(header_new + body_new)

# New 3 & New 4 (split of Old 3 in current file = old 2)
ordered_blocks.append(new_scen_3 + "\n")
ordered_blocks.append(new_scen_4 + "\n")

# New 5 (Old 4 in current file = old 7)
scen = scen_by_old[4]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 5:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb4", r"subsec:c3_kb5") \
                       .replace(r"lst:c3_kb4", r"lst:c3_kb5")
ordered_blocks.append(header_new + body_new)

# New 6 (Old 5 in current file = old 4)
scen = scen_by_old[5]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 6:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb5", r"subsec:c3_kb6") \
                       .replace(r"lst:c3_kb5", r"lst:c3_kb6")
ordered_blocks.append(header_new + body_new)

# New 7 (Old 6 in current file = old 3)
scen = scen_by_old[6]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 7:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb6", r"subsec:c3_kb7") \
                       .replace(r"lst:c3_kb6", r"lst:c3_kb7")
ordered_blocks.append(header_new + body_new)

# New 8 (Old 8 in current file = old 5)
scen = scen_by_old[8]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 8:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb8", r"subsec:c3_kb8") \
                       .replace(r"lst:c3_kb8", r"lst:c3_kb8")
ordered_blocks.append(header_new + body_new)

# New 9 (Old 7 in current file = old 6)
scen = scen_by_old[7]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 9:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb7", r"subsec:c3_kb9") \
                       .replace(r"lst:c3_kb7", r"lst:c3_kb9")
ordered_blocks.append(header_new + body_new)

# New 10 (Old 9 in current file = old 9)
scen = scen_by_old[9]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 10:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb9", r"subsec:c3_kb10") \
                       .replace(r"lst:c3_kb9", r"lst:c3_kb10")
ordered_blocks.append(header_new + body_new)

# New 11 (Old 10 in current file = old 10)
scen = scen_by_old[10]
header_new = re.sub(r"Kịch bản \d+:", "Kịch bản 11:", scen["header"])
body_new = scen["body"].replace(r"subsec:c3_kb10", r"subsec:c3_kb11") \
                       .replace(r"lst:c3_kb10", r"lst:c3_kb11")
ordered_blocks.append(header_new + body_new)

new_scenarios_block = "".join(ordered_blocks)

# Now let's update Table 3.1, Table 3.2 and Section 3.6 text
after_text = content[end_idx:]

# Table 3.1 update
new_table_rows = """1  & Từ chối mặc định + tước quyền & Thành phần 4 & Hiện tại \\\\
\\hline
2  & Xác thực JWT tại biên & Thành phần 1, 4 & Hiện tại (Ngữ cảnh: Mở rộng) \\\\
\\hline
3  & Khai thác lỗ hổng ứng dụng web & Thành phần 4 & Hiện tại (Chế độ kiểm toán) \\\\
\\hline
4  & Thực thi lệnh trái phép trong vùng chứa & Thành phần 4 & Hiện tại \\\\
\\hline
5  & Cổng nạp yêu cầu mã băm & Thành phần 2 & Hiện tại (Chữ ký: Mở rộng) \\\\
\\hline
6  & Xác thực định danh nội bộ & Thành phần 4 & Hiện tại \\\\
\\hline
7  & Bí mật động JIT & Thành phần 3, 4 & Hiện tại \\\\
\\hline
8  & CoreDNS sinkhole + Chặn Egress & Thành phần 2, 4 & Hiện tại \\\\
\\hline
9  & Nhóm IP tình báo đe dọa & Thành phần 2, 4 & Hiện tại \\\\
\\hline
10 & Seccomp + Chặn Egress & Thành phần 4 & Hiện tại \\\\
\\hline
11 & Cấu hình dạng mã + Kiểm toán & Thành phần 5 & Hiện tại (Tự phục hồi: Mở rộng) \\\\"""

table_start_marker = r"\textbf{Trạng thái kiểm chứng} \\"
table_start_idx = after_text.find(table_start_marker)
table_end_marker = r"\end{tabularx}"
table_end_idx = after_text.find(table_end_marker)

if table_start_idx != -1 and table_end_idx != -1:
    hline_idx = after_text.find(r"\hline", table_start_idx)
    if hline_idx != -1 and hline_idx < table_end_idx:
        table_before = after_text[:hline_idx + 6]
        table_after = after_text[table_end_idx:]
        after_text = table_before + "\n" + new_table_rows + "\n\\hline\n" + table_after
        print("Updated Table 3.1 successfully.")

# Table 3.2 update (MITRE summary)
# Let's specify exactly the 11 MITRE techniques in the table
new_mitre_rows = """T1046 & Trinh sát mạng nội bộ & Chính sách mạng từ chối mặc định & Hiện tại \\\\
\\hline
T1078 & Lạm dụng tài khoản hợp lệ & Xác thực JWT tại API Gateway & Hiện tại \\\\
\\hline
T1190 & Khai thác ứng dụng web & Tetragon audit log thực thi shell & Hiện tại \\\\
\hline
T1609 & Thực thi lệnh trái phép & Tetragon chặn nhị phân bị cấm & Hiện tại \\\\
\\hline
T1610 & Triển khai image mã độc & Cổng nạp yêu cầu mã băm image & Một phần \\\\
\\hline
T1036 & Giả mạo địa chỉ IP & Xác thực định danh Cilium & Hiện tại \\\\
\\hline
T1552 & Đánh cắp thông tin xác thực & Cấp phát bí mật động (Vault JIT) & Hiện tại \\\\
\\hline
T1048 & Trích xuất dữ liệu ra ngoài & Chính sách mạng từ chối mặc định & Hiện tại \\\\
\\hline
T1071 & Kết nối máy chủ độc hại & Tình báo đe dọa (CIDR Group) & Hiện tại \\\\
\\hline
T1611 & Thoát khỏi vùng chứa & Cấu hình Seccomp & Hiện tại \\\\
\\hline
T1562 & Vô hiệu hóa phòng thủ & Quản lý cấu hình dạng mã (IaC) & Hiện tại \\\\"""

mitre_start_marker = r"\caption{Tổng hợp độ phủ kỹ thuật MITRE ATT\&CK và mức minh chứng}"
mitre_start_idx = after_text.find(mitre_start_marker)
mitre_end_marker = r"\end{tabularx}"
mitre_end_idx = after_text.find(mitre_end_marker, mitre_start_idx)

if mitre_start_idx != -1 and mitre_end_idx != -1:
    # Find the tabularx start
    tab_idx = after_text.find(r"\begin{tabularx}", mitre_start_idx)
    # Find the first \hline after tabularx header row
    header_end_idx = after_text.find(r"\hline", tab_idx)
    # Let's locate the SECOND \hline (after columns header)
    header_cols_end_idx = after_text.find(r"\hline", header_end_idx + 6)
    if header_cols_end_idx != -1 and header_cols_end_idx < mitre_end_idx:
        mitre_before = after_text[:header_cols_end_idx + 6]
        mitre_after = after_text[mitre_end_idx:]
        after_text = mitre_before + "\n" + new_mitre_rows + "\n\\hline\n" + mitre_after
        print("Updated Table 3.2 successfully.")
    else:
        print("Could not find hline in Table 3.2!")

# Update counts in text
# 1. "Đồ án kiểm chứng 14 kịch bản" -> "Đồ án kiểm chứng 11 kịch bản"
after_text = after_text.replace("Đồ án kiểm chứng 14 kịch bản", "Đồ án kiểm chứng 11 kịch bản")
# 2. "tổng hợp 18 kỹ thuật MITRE" -> "tổng hợp 11 kỹ thuật MITRE"
after_text = after_text.replace("tổng hợp 18 kỹ thuật MITRE", "tổng hợp 11 kỹ thuật MITRE")
# 3. "14 kỹ thuật đã kiểm chứng thực tế (hoặc một phần) và 4 kỹ thuật" -> "10 kỹ thuật đã kiểm chứng thực tế (hoặc một phần) và 1 kỹ thuật"
after_text = after_text.replace("14 kỹ thuật đã kiểm chứng thực tế (hoặc một phần) và 4 kỹ thuật", "10 kỹ thuật đã kiểm chứng thực tế (hoặc một phần) và 1 kỹ thuật")

# Table 3.3 update (Mức độ cưỡng chế)
# Remove impossible travel, feedback loop and read-only rootfs rows since they are active defense and moved out
# We can find table 3.3 starting with \caption{Mức độ cưỡng chế thực tế của các cơ chế bảo mật}
enforce_start_marker = r"\caption{Mức độ cưỡng chế thực tế của các cơ chế bảo mật}"
enforce_start_idx = after_text.find(enforce_start_marker)
enforce_end_marker = r"\end{tabularx}"
enforce_end_idx = after_text.find(enforce_end_marker, enforce_start_idx)

if enforce_start_idx != -1 and enforce_end_idx != -1:
    tab_idx = after_text.find(r"\begin{tabularx}", enforce_start_idx)
    header_end_idx = after_text.find(r"\hline", tab_idx)
    header_cols_end_idx = after_text.find(r"\hline", header_end_idx + 6)
    
    # We want to replace the rows inside Table 3.3 to only keep mTLS, WireGuard, Sigkill runtime, Sigstore, OPA
    new_enforce_rows = """Xác thực chéo (mTLS) & \\texttt{mesh-auth-enabled=true} & Đã kích hoạt. \\\\
\\hline
Mã hóa L3 & \\texttt{enable-wireguard=false} & Bắt buộc tắt để tránh xung đột mã hóa kép do nền tảng mạng ảo đã đảm nhận. \\\\
\\hline
Giám sát Runtime & \\texttt{Sigkill enforce} ở 4 không gian tên. & Ngắt tại nhân hệ điều hành. \\\\
\\hline
Chữ ký số & Đang ở chế độ cảnh báo (\\texttt{warn}). & Cảnh báo — chuyển cưỡng chế ở giai đoạn sau. Chốt cứng dựa vào mã băm. \\\\
\\hline
Kiểm soát cổng nạp & Hoạt động ở chế độ ghi nhận (\\texttt{audit}), chỉ chặn gắn thư mục máy chủ. & Phần lớn ghi nhận; chốt cứng là mã băm, chính sách mạng và seccomp. \\\\
\\hline
Quét lỗ hổng & Đang chạy, cung cấp báo cáo định kỳ. & Cung cấp dữ liệu tư thế bảo mật hoạt động. \\\\
\\hline
Tình báo đe dọa & Tác vụ đồng bộ đang chạy. & Đã đồng bộ. \\\\"""
    
    if header_cols_end_idx != -1 and header_cols_end_idx < enforce_end_idx:
        enforce_before = after_text[:header_cols_end_idx + 6]
        enforce_after = after_text[enforce_end_idx:]
        after_text = enforce_before + "\n" + new_enforce_rows + "\n\\hline\n" + enforce_after
        print("Updated Table 3.3 successfully.")

# Update the Hạn chế của thực nghiệm (since the closed loop is now in the backup / active defenses)
# Let's restore the limitations back to:
# "Mô hình điểm tin cậy và vòng lặp phản hồi hiện tại đã được triển khai thành phần điều khiển, tuy nhiên chưa được kiểm chứng tự động toàn trình do mọi khối lượng công việc hiện tại đều đạt điểm tin cậy cao. Việc minh chứng kịch bản cô lập tự động đòi hỏi phải chủ động tiêm một vùng chứa mang lỗ hổng nghiêm trọng vào hệ thống.
# Bên cạnh đó, trục đánh giá phân cấp dịch vụ đã được đọc từ nhãn của Kubernetes nhưng chưa được tích hợp vào hàm tính điểm. Trục khả năng khai thác hiện đang dừng ở mức định hướng thiết kế, do báo cáo quét lỗ hổng chưa hỗ trợ trực tiếp thông tin về mã khai thác công khai, đòi hỏi hệ thống phải tích hợp thêm nguồn cấp dữ liệu ngoại vi trong tương lai."
new_limitations = r"""\subsection{Hạn chế của thực nghiệm}

Mô hình điểm tin cậy và vòng lặp phản hồi hiện tại đã được triển khai thành phần điều khiển, tuy nhiên chưa được kiểm chứng tự động toàn trình do mọi khối lượng công việc hiện tại đều đạt điểm tin cậy cao. Việc minh chứng kịch bản cô lập tự động đòi hỏi phải chủ động tiêm một vùng chứa mang lỗ hổng nghiêm trọng vào hệ thống.

Bên cạnh đó, trục đánh giá phân cấp dịch vụ đã được đọc từ nhãn của Kubernetes nhưng chưa được tích hợp vào hàm tính điểm. Trục khả năng khai thác hiện đang dừng ở mức định hướng thiết kế, do báo cáo quét lỗ hổng chưa hỗ trợ trực tiếp thông tin về mã khai thác công khai, đòi hỏi hệ thống phải tích hợp thêm nguồn cấp dữ liệu ngoại vi trong tương lai.
"""

limitations_start_marker = r"\subsection{Hạn chế của thực nghiệm}"
limitations_start_idx = after_text.find(limitations_start_marker)
if limitations_start_idx != -1:
    after_text = after_text[:limitations_start_idx] + new_limitations

final_content = content[:start_idx] + new_scenarios_block + after_text

with open(filepath, "w", encoding="utf-8") as f:
    f.write(final_content)

print("Successfully wrote updated chapter3.tex!")
