# Hình ảnh / Sơ đồ cần bổ sung -- Hướng dẫn vẽ và chụp

> **Mục đích:** Sau khi cô đọng nội dung từ 113 → 96 trang, các sơ đồ minh hoạ
> được lược bỏ (không còn placeholder `\framebox{[HÌNH 3.x...]}`). Tài liệu này
> liệt kê **chính xác những hình cần anh tự vẽ / tự chụp**, mô tả flow từng
> hình ở mức đủ chi tiết để vẽ.
>
> Cách dùng: vẽ xong → lưu PNG vào `documents/latex/images/<tên_file>.png` →
> chèn vào file `.tex` tương ứng bằng đoạn LaTeX đã chuẩn bị sẵn ở cuối mỗi
> mục dưới đây.

---

## Phần 1. Trạng thái ảnh hiện tại trong báo cáo

### 1.1. Đã có ảnh thực, hợp logic (không cần làm gì)

| # | File ảnh | Vị trí | Caption | Đánh giá logic |
|---|----------|--------|---------|----------------|
| 1 | `images/hust_logo.png` | cover.tex | Logo HUST | OK |
| 2 | `images/nist_zta_logical.png` | chapter1.tex §1.2 | Mô hình logic ZTA NIST | OK -- đúng minh hoạ PE/PA/PEP |
| 3 | `images/ZTAPillars.png` | chapter1.tex §1.4 | CISA ZTMM v2.0 | OK |
| 4 | `images/nsew.png` | chapter2.tex §2.1.1 | Lưu lượng N-S vs E-W | OK -- đúng concept |
| 5 | `images/ebpf_hostrouting (date).png` | chapter2.tex §2.2.3 | iptables vs eBPF host-routing | OK |
| 6 | `images/proposed_architecture_flow.png` | chapter2.tex §2.3.6 | Luồng dữ liệu 5 lớp ZTA | OK |
| 7 | `images/1576778435-vault-db.png` | chapter2.tex §2.5 | Vault Dynamic Secret cho DB | OK |
| 8 | `images/context.png` | chapter3.tex §3.0 | Sơ đồ ngữ cảnh job7189 | OK |
| 9 | `images/container.png` | chapter3.tex §3.0 | Container architecture (góc nghiệp vụ) | OK |
| 10 | `images/containerdb.png` | chapter3.tex §3.0 | Container architecture (góc dữ liệu) | OK |
| 11 | `images/db_tongquan.png` | chapter3.tex §3.0 | Tổng quan lớp dữ liệu | OK |
| 12 | `images/oidc_flow.png` | chapter3.tex §3.4 | Luồng OIDC/JWT N-S | **Cần kiểm tra**: anh xem ảnh có đúng minh hoạ Client → Keycloak → Kong → Backend với JWT verification không. Nếu không, theo flow ở Mục 2.1 dưới. |
| 13 | `images/internal_signin_2.png` | chapter3.tex §3.4 | Trang sign-in Keycloak `7189_internal` | OK -- caption đã được sửa cho khớp |
| 14 | `images/vault_jit_lifecycle.png` | chapter3.tex §3.5 | Vòng đời JIT credential | **Cần kiểm tra**: ảnh phải có 7 bước Pod → Vault → MySQL → tmpfs → app reload. Nếu không, theo flow ở Mục 2.2. |
| 15 | `images/vault_proof.png` | chapter3.tex §3.5 | Minh chứng Vault DB engine | OK |
| 16 | `images/hubble_ui.png` | chapter3.tex §3.6 | Hubble UI flow visualization | OK |
| 17 | `images/kibana.png` | chapter3.tex §3.7 | Kibana security event search | OK |

### 1.2. Đã đặt sẵn nhưng chưa dùng (anh có thể chèn nếu muốn)

| File trong `images/` | Có thể dùng cho |
|----------------------|------------------|
| `castle_vs_zerotrust.png` | chapter1.tex §1.1 -- so sánh perimeter vs Zero Trust |
| `dual_identity_jwt_spiffe.png` | chapter2.tex §2.3.1 -- 2 loại định danh JWT vs SPIFFE |
| `SPIRE.png` | chapter3.tex §3.7c -- SPIRE workflow |
| `Fig1n-Solorigate-high-level-attack-chain.png` | chapter1.tex §1.5 -- minh hoạ APT |
| `MFA bypass using a reverse proxy (Source - Cisco Talos).png` | chapter1.tex §1.5 -- minh hoạ phising |
| `internal_signin.png` | (phiên bản cũ, đã thay bằng `_2`) |

> Lưu ý: nếu chèn các ảnh trên, số trang sẽ tăng trở lại. Em đề xuất giữ nguyên
> 96 trang và chỉ chèn nếu hội đồng phản biện yêu cầu.

---

## Phần 2. Các sơ đồ MỚI cần anh vẽ -- Em đã không tự vẽ vì đã có placeholder bị xoá

> Các placeholder dưới đây đã bị **xoá khỏi LaTeX** trong lần co gọn này
> (giảm ~7 trang). Nếu anh muốn đưa lại, vẽ xong rồi paste đoạn LaTeX cuối
> mỗi mục.

### 2.1. Sơ đồ kiến trúc 5 tầng namespace (cũ: HÌNH 3.1)

**Đã thay thế bằng**: Bảng đồ TikZ tự động trong báo cáo (Mục 3.1, Hình
`fig:namespace_map`). TikZ map vẽ trực tiếp 9 namespace + workload.

**Anh có thể bỏ qua** -- TikZ đã render đẹp. Chỉ vẽ thêm nếu muốn phiên bản
draw.io đồ họa hơn (ví dụ icon Kong, Vault, Cilium thật).

### 2.2. Sequence diagram OIDC/JWT (kiểm tra `oidc_flow.png` đã có)

**Mục đích**: Minh hoạ luồng xác thực N-S.

**Flow**:
```
Client                  Keycloak              Kong               Backend
  |                        |                   |                    |
  |-- POST /token -------->|                   |                    |
  |   (user/pass)          |                   |                    |
  |                        |                   |                    |
  |<-- JWT (RS256) --------|                   |                    |
  |   {sub,iss,exp,roles}  |                   |                    |
  |                        |                   |                    |
  |-- GET /api/x ------------------>|          |                    |
  |   Authorization:Bearer JWT      |          |                    |
  |                                 |          |                    |
  |                                 |-- GET /jwks ----->|           |
  |                                 |<-- public key ----|           |
  |                                 | verify RS256                  |
  |                                 |                               |
  |                                 |-- proxy GET /api/x ---------->|
  |                                 |   X-User: <claims>            |
  |                                 |<-- 200 OK + data -------------|
  |<-- 200 OK + data --------------|                                |
  |                                                                 |
  | == Alternate (no JWT) ==                                        |
  |-- GET /api/x (no token) ------->|                               |
  |<-- 401 Unauthorized ------------|                               |
```

**Tool gợi ý**: PlantUML, Mermaid sequence, draw.io.

**Nếu cần thay file**: lưu thành `images/oidc_flow.png` (override file hiện
tại). LaTeX không cần sửa.

### 2.3. Sequence diagram vòng đời JIT credential (kiểm tra `vault_jit_lifecycle.png`)

**Mục đích**: Minh hoạ Vault Agent inject + dynamic secret rotation.

**Flow** (8 bước):
```
K8s API   MutatingWebhook   Pod                Vault           MySQL
  |              |            |                   |               |
  | -- create -->|            |                   |               |
  |              |-- inject vault-agent-init      |               |
  |                          (sidecar pattern)    |               |
  |              |                                |               |
  |              |---> Pod (vault-agent-init)     |               |
  |                            |                  |               |
  |                            |-- Auth (SA tok) ->|              |
  |                            |<-- token --------|               |
  |                            |                  |               |
  |                            |-- Read database/creds/<svc> ---->|
  |                            |                  |-- CREATE USER usr_random
  |                            |                  |   GRANT CRUD on db
  |                            |                  |<-- ack         |
  |                            |<-- {user,pwd,lease_id,TTL=1h} ---|
  |                            |                                  |
  |                            |-- write tmpfs:/vault/secrets/.env.db
  |                            |                                  |
  |                            |-- env-loader merge .env files    |
  |                            |   -> /app-secrets/.env           |
  |                            |                                  |
  |                            |-- app reads .env, connects MySQL |
  |                            |==================================>|
  |                            |   query data                     |
  |                            |                                  |
  | == TTL renew/rotate every 50 min ==                            |
  |                            |-- Vault Agent renew lease --->   |
  |                            |   on revoke: re-fetch new creds  |
  |                            |-- env-watcher detect MD5 change  |
  |                            |   -> POST /api/internal/reload-db|
  |                            |   (Laravel reconnect)            |
```

**Tool gợi ý**: PlantUML, draw.io.

**Lưu file**: `images/vault_jit_lifecycle.png` (override).

### 2.4. Microsegmentation proof (cũ: HÌNH 3.7) -- ẢNH CHỤP TERMINAL

**Mục đích**: minh chứng Pod attacker bị Cilium chặn còn allowed-client thì
qua được. **Em không tự chụp được** vì cần cluster đang chạy.

**Cách chụp**:
```bash
# Pane trái: attacker bị block
kubectl run attacker --image=busybox -n job7189-apps \
    --serviceaccount=default -- sleep 3600
kubectl exec attacker -n job7189-apps -- \
    wget -qO- --timeout=3 http://identity-service/api/v1/auth
# → wget: download timed out

# Pane phải: allowed-client qua
kubectl run allowed-client --image=busybox -n job7189-apps \
    --serviceaccount=test-client-allowed -- sleep 3600
kubectl exec allowed-client -n job7189-apps -- \
    wget -qO- --timeout=3 http://identity-service/api/v1/auth
# → {"status":"ok"}
```

**Lưu file**: `images/microseg_proof_screenshot.png`.

**Đoạn LaTeX để chèn lại** (đặt ngay sau `lst:microseg_test` trong chapter3.tex):
```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.95\textwidth]{images/microseg_proof_screenshot.png}
    \caption{Minh chứng microsegmentation: Pod ``attacker'' (SA=\texttt{default}) bị Cilium drop, \texttt{allowed-client} (SA=\texttt{test-client-allowed}) qua được nhờ \texttt{CiliumNetworkPolicy} ServiceAccount-based.}
    \label{fig:microseg_proof}
\end{figure}
```

### 2.5. Grafana Dashboard ZTA (cũ: HÌNH 3.9) -- ẢNH CHỤP

**Mục đích**: Dashboard tổng hợp metric bảo mật.

**Cách chụp**:
```bash
kubectl -n monitoring port-forward svc/grafana 30600:3000
# Mở http://localhost:30600, login admin/admin
# Mở dashboard "ZTA Security Overview" (đã có sẵn trong values)
# Đảm bảo có ít nhất 4 panel hiển thị:
#   1. Cilium hubble_flows_processed_total rate (forward vs drop)
#   2. Vault active leases count (vault_token_count_by_method)
#   3. Pod restarts (kube_pod_container_status_restarts_total)
#   4. Node CPU/Memory (node_cpu_seconds_total)
```

**Lưu file**: `images/grafana_dashboard_screenshot.png`.

**Đoạn LaTeX để chèn lại** (đặt cuối subsection "Prometheus + Grafana"):
```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.95\textwidth]{images/grafana_dashboard_screenshot.png}
    \caption{Dashboard ``ZTA Security Overview'' trên Grafana -- panel Cilium drop rate, Vault leases, Pod restart, Node CPU/Memory}
    \label{fig:grafana_dashboard}
\end{figure}
```

### 2.6. Vault credential rotation proof (cũ: HÌNH 3.11) -- ẢNH CHỤP TERMINAL

**Mục đích**: Chứng minh service vẫn 200 OK sau khi revoke tất cả lease (Vault
Agent tự fetch credential mới).

**Cách chụp**:
```bash
# Pane 1: set TTL ngắn
vault write database/roles/identity-service default_ttl=300 max_ttl=3600
vault read -format=json database/creds/identity-service
# → lease_duration: 300

# Pane 2: revoke all
vault lease revoke -prefix database/creds/identity-service
# Ngay sau đó:
curl -s -H "Authorization: Bearer $TOKEN" \
    http://api.job7189.com/api/recruiters/profile
# → 200 OK (Agent đã auto-fetch credential mới)
```

**Lưu file**: `images/vault_rotation_proof.png`.

**Đoạn LaTeX để chèn lại** (đặt sau `lst:vault_proof`):
```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.95\textwidth]{images/vault_rotation_proof.png}
    \caption{Vault credential rotation -- sau \texttt{lease revoke -prefix}, service vẫn trả 200 OK trong < 1s nhờ Agent re-fetch tự động.}
    \label{fig:rotation_proof}
\end{figure}
```

### 2.7. `kubectl get pods -A` healthy state (cũ: HÌNH 3.12) -- ẢNH CHỤP TERMINAL

**Mục đích**: Chứng minh sau pipeline hoàn tất, mọi pod đều `Running`, không có
`CrashLoopBackOff`.

**Cách chụp**:
```bash
kubectl get pods -A --sort-by=.metadata.namespace \
  | grep -E "gateway|security|vault|data|job7189|monitoring|kube-system"
# Cần thấy:
#   - 7 backend services: 5/5 READY (5 container/pod)
#   - cilium-*: 1/1 Running
#   - vault-prod-0: 1/1 Running
#   - keycloak-0: 1/1 Running
#   - elasticsearch-0, kibana-*, prometheus-*, grafana-*
```

**Lưu file**: `images/pods_status_screenshot.png`.

**Đoạn LaTeX để chèn lại** (đặt cuối Mục 3.7c -- Pod Anatomy):
```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.95\textwidth]{images/pods_status_screenshot.png}
    \caption{Trạng thái cluster sau khi \texttt{zta-rebuild.sh} hoàn tất phase \texttt{27-pdp} -- toàn bộ pods Running, backend service 5/5 READY (app + 4 sidecar).}
    \label{fig:pods_status}
\end{figure}
```

### 2.8. Tetragon SIGKILL flow (cũ: HÌNH 3.10) -- VẼ FLOWCHART

**Mục đích**: Minh hoạ kernel-level interception bằng eBPF kprobe trên `sys_execve`.

**Flow**:
```
[App container]                [Linux Kernel]              [Tetragon]
   |                                |                          |
   | exec("/usr/bin/wget ...")      |                          |
   |------ syscall ---------------->|                          |
   |                                | sys_execve entry         |
   |                                |--- kprobe hook --------->|
   |                                |                          |
   |                                |  (Tetragon evaluates     |
   |                                |   TracingPolicy)         |
   |                                |                          |
   |                                |        match?            |
   |                                |    /-----yes-----\       |
   |                                |    |             |       |
   |                                |    | <-- SIGKILL |       |
   |                                |<---|-------------|       |
   |                                |                          |
   |                                |  process killed BEFORE   |
   |                                |  kernel completes exec   |
   |                                |                          |
   | (process dies, exit code 137)  |                          |
   |<----- SIGKILL -----------------|                          |
   |                                |                          |
   |                                |    \-----no------\       |
   |                                |    |             |       |
   |                                |    | continue exec       |
   |                                | <- (allowed) ---|       |
```

**Tool gợi ý**: draw.io flowchart.

**Lưu file**: `images/tetragon_sigkill_flow.png`.

**Đoạn LaTeX để chèn** (đặt sau `lst:tetragon_policy`):
```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.85\textwidth]{images/tetragon_sigkill_flow.png}
    \caption{Tetragon kprobe trên \texttt{sys\_execve}: binary trong blacklist bị SIGKILL trước khi kernel hoàn tất execve.}
    \label{fig:tetragon_sigkill}
\end{figure}
```

### 2.9. Deployment Pipeline 16-phase visualization (cũ: HÌNH 3.13)

**Mục đích**: Sơ đồ ngang minh hoạ 16 phase của `zta-rebuild.sh`.

**Đã có**: Bảng `tab:zta_rebuild_phases` trong chapter3.tex liệt kê đủ 16 phase
với mô tả + module ZTA. **Nếu anh cảm thấy bảng đủ, bỏ qua hình này.**

**Nếu vẫn muốn vẽ**: 16 box ngang, mũi tên giữa các phase, mỗi box có:
- Số phase (00-prep → 27-pdp)
- Tên ngắn (Cilium, Cosign, SPIRE, Vault, Apps, Hubble, Tetragon, ...)
- Icon module ZTA (key, lock, eye)

**Tool gợi ý**: draw.io horizontal swimlane.

**Lưu file**: `images/zta_rebuild_pipeline.png`.

---

## Phần 3. Tóm tắt ưu tiên

| Ưu tiên | Hình | Tại sao |
|---------|------|---------|
| ⭐⭐⭐ Cao | 2.4 Microseg proof | Bằng chứng tấn công bị chặn -- thuyết phục hội đồng |
| ⭐⭐⭐ Cao | 2.7 Pods healthy state | Bằng chứng hệ thống chạy thật, không demo trên giấy |
| ⭐⭐⭐ Cao | 2.6 Vault rotation proof | Khẳng định mệnh đề "no downtime" trong Chương 4 |
| ⭐⭐ Vừa | 2.5 Grafana dashboard | Củng cố Mục Observability |
| ⭐⭐ Vừa | 2.8 Tetragon SIGKILL flow | Đặc biệt nếu phản biện hỏi "vì sao Tetragon mà không Falco" |
| ⭐ Thấp | 2.9 Pipeline visual | Đã có bảng -- chỉ cần nếu defence yêu cầu hình |

> **Em đề xuất**: anh ưu tiên 3 hình ⭐⭐⭐ (2.4, 2.6, 2.7) vì chúng là minh
> chứng vận hành thực, không thay thế được bằng diễn giải. 3 hình còn lại có
> thể bỏ qua hoặc làm khi rảnh.

---

## Phần 4. Cảnh báo logic phát hiện trong lần audit này

| # | Vấn đề | Đã sửa? |
|---|--------|---------|
| 1 | `internal_signin_2.png` có label `fig:jwt_proof_screenshot` nhưng caption nói về Keycloak realm internal -- không khớp | **Đã sửa**: đổi label thành `fig:keycloak_internal_signin` + caption rõ hơn |
| 2 | `vault_proof.png` caption viết `"Indentity Service"` (typo) | **Đã sửa**: `\texttt{identity-service}` |
| 3 | `nsew.png` trước đây không được render thành figure (chỉ ở `\begin{leftbar}` trong `insertanh.txt`) | **Đã sửa**: đưa vào figure environment trong chapter2.tex §2.1.1 |
| 4 | 5 placeholder `\framebox{[HÌNH 3.x ...]}` chiếm chỗ nhưng không có ảnh | **Đã xoá**, thay bằng tài liệu này |

---

*Tạo bởi audit lần co gọn 113 → 96 trang. Sau khi anh vẽ ảnh, paste đoạn LaTeX
ở mỗi mục vào file `.tex` tương ứng, build lại bằng `docker compose up
--abort-on-container-exit`.*
