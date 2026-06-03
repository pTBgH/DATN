# Danh sách thuật ngữ kỹ thuật tiếng Anh được chuẩn hóa cho báo cáo

Đây là danh sách các thuật ngữ tiếng Anh xuất hiện trong báo cáo, đã được chuẩn hóa theo phong cách viết học thuật kỹ thuật tiếng Việt, ưu tiên giữ nguyên thuật ngữ tiếng Anh với giải thích tiếng Việt (nếu cần) ở lần đầu tiên xuất hiện.

---

## Nguyên tắc chung:
*   **Giữ nguyên tiếng Anh**: Đối với tên công nghệ, chuẩn kỹ thuật, acronym phổ biến, tên công cụ, thuật toán, giao thức (ví dụ: Kubernetes, SPIFFE, eBPF, HTTP, JWT, CVE, mTLS, OPA Rego, v.v.).
*   **Giải thích lần đầu**: Mở ngoặc giải thích tiếng Việt ngắn gọn ở lần đầu tiên thuật ngữ xuất hiện trong nội dung (trừ tiêu đề).
*   **Việt hóa hợp lý**: Đối với các khái niệm có bản dịch tiếng Việt tự nhiên và phổ biến trong ngành CNTT (ví dụ: "vi dịch vụ" cho Microservices).
*   **Tránh dịch máy móc**: Tránh các bản dịch ngô nghê, không tự nhiên (ví dụ: không dùng "đám mây gốc", "mặt phẳng dữ liệu", "tải công việc", "ảnh chứa", "móc web").
*   **Không thêm "tầng"**: Với L3/L4/L7, giữ nguyên, không thêm từ "tầng".

---

## Chapter 1: Tổng quan và kiến trúc Zero Trust

1.  **Perimeter-based**:
    *   **Chuẩn hóa**: "dựa trên chu vi"
    *   **Lưu ý**: Chỉ dùng khi giải thích khái niệm cũ, không dùng cho Zero Trust.
2.  **Implicit Trust**:
    *   **Chuẩn hóa**: "tin cậy ngầm định"
3.  **insider threat**:
    *   **Chuẩn hóa**: "mối đe dọa nội bộ"
4.  **network location**:
    *   **Chuẩn hóa**: "vị trí mạng"
5.  **VLAN/subnet**:
    *   **Chuẩn hóa**: Giữ nguyên "VLAN/subnet" (có thể thêm "(mạng con)" cho subnet lần đầu)
6.  **cloud-native**:
    *   **Chuẩn hóa**: Giữ nguyên "cloud-native" (lần đầu giải thích: "(thiết kế tối ưu cho môi trường đám mây)")
7.  **de-perimeterization**:
    *   **Chuẩn hóa**: "loại bỏ mô hình chu vi truyền thống" hoặc "không còn phụ thuộc chu vi mạng"
8.  **per-session**:
    *   **Chuẩn hóa**: "theo phiên"
9.  **per-request access**:
    *   **Chuẩn hóa**: "truy cập theo yêu cầu"
    *   **Lưu ý**: KHÔNG dùng "quyền truy cập theo yêu cầu".
10. **Least Privilege**:
    *   **Chuẩn hóa**: "nguyên tắc đặc quyền tối thiểu"
11. **macro-segmentation**:
    *   **Chuẩn hóa**: "phân đoạn vĩ mô"
12. **micro-segmentation**:
    *   **Chuẩn hóa**: "phân đoạn vi mô"
13. **JIT (Just-In-Time)**:
    *   **Chuẩn hóa**: Giữ nguyên "JIT" (lần đầu giải thích: "(cấp phát đúng lúc/tức thời)")
14. **TTL (Time-To-Live)**:
    *   **Chuẩn hóa**: Giữ nguyên "TTL" (lần đầu giải thích: "(thời gian sống)")
15. **control plane**:
    *   **Chuẩn hóa**: Giữ nguyên "control plane"
    *   **Lưu ý**: Có thể giải thích là "thành phần điều khiển" ở lần đầu nếu cần ngữ cảnh.
16. **data plane**:
    *   **Chuẩn hóa**: Giữ nguyên "data plane"
    *   **Lưu ý**: Có thể giải thích là "thành phần xử lý lưu lượng" ở lần đầu nếu cần ngữ cảnh.
17. **supporting components**:
    *   **Chuẩn hóa**: "các thành phần hỗ trợ"
18. **Best-of-breed**:
    *   **Chuẩn hóa**: "lựa chọn tốt nhất theo từng loại" hoặc "phù hợp nhất" tùy ngữ cảnh.
19. **vendor lock-in**:
    *   **Chuẩn hóa**: "phụ thuộc nhà cung cấp" hoặc "bị khóa vào hệ sinh thái nhà cung cấp"
20. **Policy-as-code**:
    *   **Chuẩn hóa**: "chính sách dạng mã"
    *   **Lưu ý**: KHÔNG dùng "chính sách dưới dạng mã".
21. **Black cloud**:
    *   **Chuẩn hóa**: Giữ nguyên "Black cloud" (lần đầu giải thích: "(môi trường không đáng tin cậy)")
22. **Crawl Phase**:
    *   **Chuẩn hóa**: "giai đoạn thu thập dữ liệu" hoặc "giai đoạn crawling" tùy ngữ cảnh.
    *   **Lưu ý**: KHÔNG dùng "giai đoạn bò tìm kiếm".
23. **EIG (Enhanced Identity Governance)**:
    *   **Chuẩn hóa**: Giữ nguyên "EIG" (lần đầu giải thích: "(Quản trị danh tính nâng cao)")
24. **SDP (Software-Defined Perimeter)**:
    *   **Chuẩn hóa**: Giữ nguyên "SDP" (lần đầu giải thích: "(Chu vi định nghĩa bằng phần mềm)")
25. **SASE (Secure Access Service Edge)**:
    *   **Chuẩn hóa**: Giữ nguyên "SASE" (lần đầu giải thích: "Secure Access Service Edge")
    *   **Lưu ý**: KHÔNG dịch "Cạnh dịch vụ bảo mật truy cập". Có thể dùng "kiến trúc bảo mật truy cập biên" hoặc "kiến trúc mạng và bảo mật hội tụ" tùy ngữ cảnh.
26. **event-driven**:
    *   **Chuẩn hóa**: "điều khiển bởi sự kiện" hoặc "dựa trên sự kiện"
27. **Poll IdP**:
    *   **Chuẩn hóa**: "kiểm tra IdP" hoặc "truy vấn IdP"
28. **CI/CD (Continuous Integration/Continuous Delivery)**:
    *   **Chuẩn hóa**: Giữ nguyên "CI/CD" (lần đầu giải thích: "(Tích hợp liên tục/Triển khai liên tục)")

---

## Chapter 2: Áp dụng kiến trúc Zero Trust cho Microservices trên Kubernetes

1.  **East-West traffic**:
    *   **Chuẩn hóa**: "lưu lượng đông-tây"
2.  **North-South traffic**:
    *   **Chuẩn hóa**: "lưu lượng bắc-nam"
3.  **Microservices**:
    *   **Chuẩn hóa**: "vi dịch vụ"
4.  **Kubernetes (K8s)**:
    *   **Chuẩn hóa**: Giữ nguyên "Kubernetes" hoặc "K8s" (lần đầu giải thích: "(hệ thống điều phối container)")
5.  **Pod**:
    *   **Chuẩn hóa**: Giữ nguyên "Pod" (KHÔNG dịch "khối công việc").
6.  **workload**:
    *   **Chuẩn hóa**: Giữ nguyên "workload" (lần đầu giải thích: "(khối lượng công việc)")
7.  **Discovery**:
    *   **Chuẩn hóa**: Tùy ngữ cảnh. Đối với "service discovery" dùng "khám phá dịch vụ". Đối với "discovery" nói chung dùng "phát hiện" hoặc "khám phá".
    *   **Lưu ý**: Ưu tiên dịch theo ngữ cảnh thay vì cố định một nghĩa.
8.  **Lateral Movement**:
    *   **Chuẩn hóa**: "di chuyển ngang"
9.  **Database**:
    *   **Chuẩn hóa**: "cơ sở dữ liệu"
10. **Privilege Escalation**:
    *   **Chuẩn hóa**: "leo thang đặc quyền"
11. **Stealth**:
    *   **Chuẩn hóa**: "ẩn mình" hoặc "lẩn trốn"
12. **CVE (Common Vulnerabilities and Exposures)**:
    *   **Chuẩn hóa**: Giữ nguyên "CVE" (lần đầu giải thích: "(mã định danh lỗ hổng bảo mật)")
13. **image (Docker image)**:
    *   **Chuẩn hóa**: Giữ nguyên "image" (lần đầu giải thích: "(gói container image)")
    *   **Lưu ý**: KHÔNG dịch "ảnh".
14. **Deploy**:
    *   **Chuẩn hóa**: "triển khai"
15. **Shared Infrastructure**:
    *   **Chuẩn hóa**: "hạ tầng dùng chung"
16. **Kernel**:
    *   **Chuẩn hóa**: Giữ nguyên "kernel" (lần đầu giải thích: "(nhân hệ điều hành)")
17. **eBPF (Extended Berkeley Packet Filter)**:
    *   **Chuẩn hóa**: Giữ nguyên "eBPF" (lần đầu giải thích: "(Extended Berkeley Packet Filter)")
18. **Cilium**:
    *   **Chuẩn hóa**: Giữ nguyên "Cilium"
19. **mTLS (mutual TLS)**:
    *   **Chuẩn hóa**: Giữ nguyên "mTLS" (lần đầu giải thích: "(TLS hai chiều)")
20. **SPIFFE (Secure Production Identity Framework for Everyone)**:
    *   **Chuẩn hóa**: Giữ nguyên "SPIFFE"
21. **SPIRE (SPIFFE Runtime Environment)**:
    *   **Chuẩn hóa**: Giữ nguyên "SPIRE"
22. **Service Mesh**:
    *   **Chuẩn hóa**: Giữ nguyên "Service Mesh" (lần đầu giải thích: "(lưới dịch vụ)")
23. **Ingress**:
    *   **Chuẩn hóa**: Giữ nguyên "Ingress"
    *   **Lưu ý**: Cộng đồng K8s Việt Nam gần như không dịch thuật ngữ này.
24. **Namespace**:
    *   **Chuẩn hóa**: Giữ nguyên "namespace" (lần đầu giải thích: "(không gian tên)")
25. **sidecar**:
    *   **Chuẩn hóa**: Giữ nguyên "sidecar" (lần đầu giải thích: "(container đồng hành)")
26. **webhook**:
    *   **Chuẩn hóa**: Giữ nguyên "webhook" (KHÔNG dịch "móc web")
27. **L3/L4/L7**:
    *   **Chuẩn hóa**: Giữ nguyên "L3/L4/L7" (KHÔNG thêm "tầng").

---

## Chapter 3: Triển khai và Tích hợp các công cụ Zero Trust

1.  **Keycloak**:
    *   **Chuẩn hóa**: Giữ nguyên "Keycloak"
2.  **Vault**:
    *   **Chuẩn hóa**: Giữ nguyên "Vault"
3.  **Kong**:
    *   **Chuẩn hóa**: Giữ nguyên "Kong"
4.  **SVID (SPIFFE Verifiable Identity Document)**:
    *   **Chuẩn hóa**: Giữ nguyên "SVID"
5.  **tmpfs**:
    *   **Chuẩn hóa**: Giữ nguyên "tmpfs" (lần đầu giải thích: "(hệ thống tập tin tạm thời trong RAM)")
6.  **Tetragon**:
    *   **Chuẩn hóa**: Giữ nguyên "Tetragon"
7.  **Sigstore**:
    *   **Chuẩn hóa**: Giữ nguyên "Sigstore"
8.  **Helm**:
    *   **Chuẩn hóa**: Giữ nguyên "Helm"
9.  **Helmfile**:
    *   **Chuẩn hóa**: Giữ nguyên "Helmfile"
10. **kubeadm**:
    *   **Chuẩn hóa**: Giữ nguyên "kubeadm"
11. **Default Deny**:
    *   **Chuẩn hóa**: "từ chối mặc định"
12. **Allow-Explicit**:
    *   **Chuẩn hóa**: "cho phép tường minh"
13. **OpenSSL**:
    *   **Chuẩn hóa**: Giữ nguyên "OpenSSL"
14. **HTTP**:
    *   **Chuẩn hóa**: Giữ nguyên "HTTP"
15. **TCP/IP**:
    *   **Chuẩn hóa**: Giữ nguyên "TCP/IP"
16. **iptables**:
    *   **Chuẩn hóa**: Giữ nguyên "iptables"
17. **YAML**:
    *   **Chuẩn hóa**: Giữ nguyên "YAML"
18. **git**:
    *   **Chuẩn hóa**: Giữ nguyên "git"
19. **OPA Rego**:
    *   **Chuẩn hóa**: Giữ nguyên "OPA Rego"
20. **JWT (JSON Web Token)**:
    *   **Chuẩn hóa**: Giữ nguyên "JWT"
21. **zero-day**:
    *   **Chuẩn hóa**: Giữ nguyên "zero-day" (lần đầu giải thích: "(lỗ hổng chưa được biết đến)")
22. **shell**:
    *   **Chuẩn hóa**: Giữ nguyên "shell"
23. **health-check**:
    *   **Chuẩn hóa**: Giữ nguyên "health-check"
24. **liveness probe**:
    *   **Chuẩn hóa**: Giữ nguyên "liveness probe"
25. **readiness probe**:
    *   **Chuẩn hóa**: Giữ nguyên "readiness probe"
26. **timeout**:
    *   **Chuẩn hóa**: Giữ nguyên "timeout"
27. **initialDelay**:
    *   **Chuẩn hóa**: Giữ nguyên "initialDelay"
28. **uninstall**:
    *   **Chuẩn hóa**: Giữ nguyên "uninstall"
29. **selector**:
    *   **Chuẩn hóa**: Giữ nguyên "selector"
30. **StatefulSet**:
    *   **Chuẩn hóa**: Giữ nguyên "StatefulSet"
31. **DaemonSet**:
    *   **Chuẩn hóa**: Giữ nguyên "DaemonSet"
32. **CronJob**:
    *   **Chuẩn hóa**: Giữ nguyên "CronJob"
33. **ConfigMap**:
    *   **Chuẩn hóa**: Giữ nguyên "ConfigMap"
34. **Secret**:
    *   **Chuẩn hóa**: Giữ nguyên "Secret"
35. **Realm (Keycloak)**:
    *   **Chuẩn hóa**: Giữ nguyên "realm" (đối với Keycloak realm).
    *   **Lưu ý**: KHÔNG dịch "khu vực".

---

## Chapter 4: Đánh giá và Phân tích kết quả

1.  **Baseline**:
    *   **Chuẩn hóa**: "mức tham chiếu" hoặc "cấu hình tham chiếu" hoặc "giá trị cơ sở" tùy ngữ cảnh
    *   **Ví dụ**:
        - baseline configuration → cấu hình cơ sở
        - baseline performance → hiệu năng tham chiếu
        - baseline model → mô hình tham chiếu
2.  **Enforced**:
    *   **Chuẩn hóa**: "được thực thi"
3.  **Security Testing**:
    *   **Chuẩn hóa**: "kiểm thử bảo mật"
4.  **Performance Evaluation**:
    *   **Chuẩn hóa**: "đánh giá hiệu năng"
5.  **latency**:
    *   **Chuẩn hóa**: "độ trễ"
6.  **throughput**:
    *   **Chuẩn hóa**: "thông lượng"
7.  **native speed**:
    *   **Chuẩn hóa**: "hiệu năng native"
    *   **Lưu ý**: KHÔNG dùng "tốc độ gốc".
8.  **Trust Score**:
    *   **Chuẩn hóa**: "điểm tin cậy"
9.  **Sensitivity analysis**:
    *   **Chuẩn hóa**: "phân tích độ nhạy"
    *   **Lưu ý**: KHÔNG dùng "độ nhạy cảm" nếu nói về mô hình/phân tích.

---

## Tổng kết

### Những thuật ngữ nên giữ nguyên tiếng Anh
(Cộng đồng CNTT Việt Nam gần như không dịch các thuật ngữ này)

Pod, workload, sidecar, webhook, realm, ingress, Service Mesh, image, runtime, native, fail-open, fail-closed, liveness probe, readiness probe, health-check, selector, timeout, uninstall, bootstrap, warm path, overhead, buffering, connection pooling, eBPF, Cilium, Kubernetes, SPIFFE, SPIRE, Tetragon, Sigstore, Keycloak, Vault, Kong, Helm, Helmfile, kubeadm, OpenSSL, HTTP, TCP/IP, iptables, YAML, git, OPA Rego, JWT, CVE, zero-day, mTLS, SVID, shell, API, L3/L4/L7, StatefulSet, DaemonSet, CronJob, ConfigMap, Secret, namespace, Ingress

---

### Bảng chuẩn hóa thêm các thuật ngữ khác

| Thuật ngữ tiếng Anh     | Dịch/Giải thích tiếng Việt                                                 |
|----------------------|---------------------------------------------------------------------------|
| Posture              | trạng thái bảo mật (KHÔNG dùng "tư thế")                                |
| Connection Pooling   | tái sử dụng kết nối (hoặc giữ nguyên "connection pooling" tùy ngữ cảnh) |
| buffering            | giữ nguyên "buffering"                                                   |
| Adaptive Loop        | giữ nguyên "adaptive loop"                                               |
| Control Loop         | giữ nguyên "control loop"                                               |
| Runtime Anomaly      | bất thường runtime                                                       |
| warm path            | giữ nguyên "warm path"                                                  |
| Living-off-the-Land  | giữ nguyên "Living-off-the-Land technique"                              |
| Admission Control    | kiểm soát admission hoặc giữ nguyên "Admission Control"                  |
| Admission Controller | Admission Controller (K8s resource)                                      |
| Image Provenance     | nguồn gốc container image                                               |
| L7 proxy             | giữ nguyên "L7 proxy"                                                   |

---

### Bảng chuẩn hóa thuật ngữ Security/Runtime nâng cao

| Thuật ngữ tiếng Anh      | Dịch/Giải thích tiếng Việt                                              |
|------------------------|------------------------------------------------------------------------|
| runtime                | giữ nguyên "runtime"                                                    |
| runtime security       | bảo mật runtime (hoặc "bảo mật thời gian chạy" tùy ngữ cảnh)            |
| observability          | giữ nguyên "observability" (khả năng quan sát nếu giải thích)           |
| telemetry              | giữ nguyên "telemetry"                                                  |
| enforcement            | thực thi chính sách / cơ chế thực thi                                   |
| identity federation    | giữ nguyên "identity federation"                                        |
| attestation            | giữ nguyên "attestation" (chứng thực nếu giải thích)                    |
| provenance             | giữ nguyên "provenance" (hoặc "nguồn gốc" nếu giải thích)               |
| service account        | ServiceAccount (K8s resource) hoặc "tài khoản dịch vụ" tùy ngữ cảnh     |
| controller             | giữ nguyên "controller"                                                 |
| operator               | giữ nguyên "operator"                                                   |
| reconciliation loop    | giữ nguyên "reconciliation loop"                                        |
| drift                  | sai lệch cấu hình / drift                                               |
| policy engine          | giữ nguyên "policy engine"                                              |
| identity-aware         | nhận biết định danh / identity-aware                                    |
| security posture       | trạng thái bảo mật                                                      |
| policy enforcement     | thực thi chính sách                                                     |
| ephemeral              | giữ nguyên "ephemeral" (tạm thời nếu giải thích)                       |
| immutable              | giữ nguyên "immutable" (bất biến nếu giải thích)                        |

---

### Bảng chuẩn hóa thuật ngữ Zero Trust & Supply Chain Security

| Thuật ngữ tiếng Anh      | Dịch/Giải thích tiếng Việt                                              |
|------------------------|------------------------------------------------------------------------|
| supply chain security  | bảo mật chuỗi cung ứng                                                  |
| workload identity      | định danh workload                                                      |
| trust domain           | miền tin cậy                                                            |
| identity provider (IdP)| nhà cung cấp định danh                                                  |
| authentication         | xác thực                                                                |
| authorization          | phân quyền                                                              |
| verification           | xác minh                                                                |
| certificate rotation   | xoay vòng chứng chỉ                                                     |
| short-lived certificate| chứng chỉ ngắn hạn                                                      |
| root of trust          | gốc tin cậy                                                             |
| attack surface         | bề mặt tấn công                                                         |
| hardening              | tăng cường bảo mật                                                      |
| sandboxing             | cô lập sandbox / sandboxing                                             |
| syscall                | giữ nguyên "syscall"                                                    |
| kernel space           | giữ nguyên "kernel space"                                               |
| user space             | giữ nguyên "user space"                                                 |

---

## Phương pháp tiếp cận

Danh sách này được chuẩn hóa theo tiêu chuẩn viết học thuật kỹ thuật tiếng Việt, với tinh thần:

*   **Tránh dịch máy móc**: Không cố Việt hóa mọi thuật ngữ tiếng Anh
*   **Giữ thuật ngữ công nghệ**: Các tên công cụ, chuẩn kỹ thuật, acronym phổ biến giữ nguyên tiếng Anh
*   **Giải thích ngữ cảnh**: Mở ngoặc giải thích tiếng Việt ngắn gọn ở lần xuất hiện đầu tiên
*   **Ưu tiên chuyên nghiệp**: Đọc tự nhiên, không giống văn bản Google Translate
*   **Nhất quán trong cộng đồng**: Tuân theo cách dùng thực tế của cộng đồng CNTT Việt Nam

**Mục tiêu**: Tài liệu này dùng để nắn AI rewrite luận văn, đảm bảo kết quả có phong cách học thuật kỹ thuật chuyên nghiệp và nhất quán.
