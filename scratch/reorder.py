import re
import os

filepath = "/home/ptb/projects/DATN/documents/latex/chapters/chapter3.tex"

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

# New order
new_order = [8, 1, 2, 7, 4, 3, 6, 5, 9, 10, 11, 12, 13, 14]

reordered_scenarios = []
for idx, old_num in enumerate(new_order):
    new_num = idx + 1
    scen = scen_by_old[old_num]
    
    header_new = re.sub(r"Kịch bản \d+:", f"Kịch bản {new_num}:", scen["header"])
    body_new = scen["body"]
    
    # Update labels using simple string replacement (safe from escape sequences)
    body_new = body_new.replace(f"\\label{{subsec:c3_kb{old_num}}}", f"\\label{{subsec:c3_kb{new_num}}}")
    body_new = body_new.replace(f"\\label{{lst:c3_kb{old_num}}}", f"\\label{{lst:c3_kb{new_num}}}")
    body_new = body_new.replace(f"\\label{{lst:c3_kb{old_num}_", f"\\label{{lst:c3_kb{new_num}_")
    
    reordered_scenarios.append(header_new + body_new)

new_scenarios_block = "".join(reordered_scenarios)

# Update Table 3.1
after_text = content[end_idx:]

new_table_rows = """1  & Từ chối mặc định + tước quyền & Thành phần 4 & Hiện tại \\\\
\\hline
2  & Xác thực JWT tại biên & Thành phần 1, 4 & Hiện tại (Ngữ cảnh: Mở rộng) \\\\
\\hline
3  & Giám sát \\texttt{execve} & Thành phần 4 & Hiện tại (Chế độ kiểm toán) \\\\
\\hline
4  & Cổng nạp yêu cầu mã băm & Thành phần 2 & Hiện tại (Chữ ký: Mở rộng) \\\\
\\hline
5  & Xác thực định danh nội bộ & Thành phần 4 & Hiện tại \\\\
\\hline
6  & Bí mật động JIT & Thành phần 3, 4 & Hiện tại \\\\
\\hline
7  & Nhóm IP tình báo đe dọa & Thành phần 2, 4 & Hiện tại \\\\
\\hline
8  & CoreDNS sinkhole + Chặn Egress & Thành phần 2, 4 & Hiện tại \\\\
\\hline
9  & Seccomp + Chặn Egress & Thành phần 4 & Hiện tại \\\\
\\hline
10 & Cấu hình dạng mã + Kiểm toán & Thành phần 5 & Hiện tại (Tự phục hồi: Mở rộng) \\\\
\\hline
11 & Quét phát hiện dịch chuyển bất khả thi & Thành phần 2, 5 & Hiện tại (Shadow/Audit) \\\\
\\hline
12 & Hệ thống tập tin chỉ đọc & Thành phần 4 & Hiện tại \\\\
\\hline
13 & Trọng số lỗ hổng CISA KEV & Thành phần 2, 3 & Hiện tại \\\\
\\hline
14 & Đóng vòng tự động và đa chính sách mạng & Thành phần 3, 4, 5 & Hiện tại \\\\"""

table_start_marker = r"\textbf{Trạng thái kiểm chứng} \\"
table_start_idx = after_text.find(table_start_marker)
table_end_marker = r"\end{tabularx}"
table_end_idx = after_text.find(table_end_marker)

if table_start_idx != -1 and table_end_idx != -1:
    hline_idx = after_text.find(r"\hline", table_start_idx)
    if hline_idx != -1 and hline_idx < table_end_idx:
        table_before = after_text[:hline_idx + 6]
        table_after = after_text[table_end_idx:]
        after_text_new = table_before + "\n" + new_table_rows + "\n\\hline\n" + table_after
        after_text = after_text_new
        print("Updated Table 3.1 rows successfully!")
    else:
        print("Could not find hline in Table 3.1!")
else:
    print("Could not locate Table 3.1 boundary!")

final_content = content[:start_idx] + new_scenarios_block + after_text

with open(filepath, "w", encoding="utf-8") as f:
    f.write(final_content)

print("Successfully wrote updated chapter3.tex!")
