# Hướng dẫn vẽ hình cho Chương 2 và Chương 3

---

## CHƯƠNG 2

### HÌNH 2.x: Lộ trình triển khai ZTA 4 giai đoạn
- **Label:** `fig:zta_deployment_roadmap`
- **Nội dung:** Sơ đồ lộ trình (Roadmap) ngang, 4 giai đoạn kết nối bằng mũi tên:
  - **Giai đoạn 1 — Chuẩn bị:** Icon: kính lúp/checklist. Nội dung: Kiểm kê tài sản, Bản đồ luồng, Gap Analysis, Chọn công nghệ
  - **Giai đoạn 2 — Thí điểm:** Icon: test tube/pilot. Nội dung: Root of Trust (IdP + Vault), Default Deny 1 namespace, JWT Gateway, Dynamic Secrets
  - **Giai đoạn 3 — Mở rộng:** Icon: mũi tên mở rộng. Nội dung: Microsegmentation L3/L4/L7 toàn bộ, Vault 7 services, EFK + Prometheus
  - **Giai đoạn 4 — Cải tiến liên tục:** Icon: vòng tròn lặp. Nội dung: Giám sát, Policy Review, Pen-test, Nâng cấp phiên bản
- **Giữa mỗi giai đoạn:** Checkpoint diamond: ✅ "Đánh giá trước khi chuyển giai đoạn"
- **Mũi tên vòng lặp:** Từ Giai đoạn 4 quay lại Giai đoạn 1 (Continuous Improvement Loop)
- **Tool:** draw.io / mermaid
- **File:** `zta_deployment_roadmap.png`

---

## CHƯƠNG 3

Tổng cộng **13 hình** cần vẽ/chụp. Lưu vào `documents/latex/images/` rồi replace `\framebox{...}` bằng `\includegraphics{images/<tên_file>}`.

---

## HÌNH 3.1: Kiến trúc tổng thể 5 tầng namespace
- **Label:** `fig:system_architecture`
- **Nội dung:** Sơ đồ kiến trúc 5 tầng.
  - **Tầng trên cùng:** Client (Browser/Mobile/Postman) gửi HTTPS
  - **Tầng 1 — Gateway:** Nginx Ingress → Kong Gateway (namespace `gateway`)
  - **Tầng 2 — Security:** Keycloak (namespace `security`)
  - **Tầng 3 — Application:** 7 microservices (namespace `job7189-apps`). Mỗi service box chứa 4 container: app + vault-agent + env-loader + env-watcher
  - **Tầng 4 — Data:** MySQL, Kafka, Redis (namespace `data`)
  - **Tầng 5 — Platform:** Vault, EFK, Prometheus, Grafana (namespace `vault`, `monitoring`)
- **Mũi tên:**
  - Xanh dương = North-South (Client → Ingress → Kong → Services)
  - Xanh lá = East-West (Services gọi nhau: job→workspace, hiring→identity)
  - Cam = Services → Data tier (MySQL 3306, Redis 6379, Kafka 9092)
  - Tím = Services → Vault (8200 TLS)
- **Tool:** draw.io / Excalidraw
- **File:** `architecture_5_layer.png`

---

## HÌNH 3.2: Sequence diagram OIDC/JWT flow
- **Label:** `fig:oidc_flow`
- **Nội dung:** Sequence diagram UML
  - Actors: Client, Keycloak, Kong Gateway, Backend Service
  - Flow:
    1. Client → Keycloak: POST /token (username + password)
    2. Keycloak → Client: Access Token (JWT RS256)
    3. Client → Kong: GET /api/... + Authorization: Bearer <JWT>
    4. Kong → Keycloak JWKS: Verify signature (có thể cache)
    5. Kong → Backend: Proxy request + X-Forwarded-For
    6. Backend → Client: Response 200
    7. **Alternate:** Client gửi request KHÔNG có JWT → Kong trả 401
- **Tool:** plantuml / mermaid / draw.io
- **File:** `oidc_jwt_sequence.png`

---

## HÌNH 3.3: Screenshot JWT proof (Postman/terminal)
- **Label:** `fig:jwt_proof_screenshot`
- **Nội dung:** 2 screenshot cạnh nhau:
  - **(a)** `curl http://api.job7189.com/api/recruiters/profile` → response `{"message":"Unauthorized"}` HTTP 401
  - **(b)** `curl -H "Authorization: Bearer $TOKEN" http://api.job7189.com/api/recruiters/profile` → response 200 với data
- **Cách chụp:** Khởi hệ thống → chạy 2 lệnh curl → chụp terminal
- **File:** `jwt_proof_screenshot.png`

---

## HÌNH 3.4: Vòng đời JIT credential (Vault)
- **Label:** `fig:vault_jit_lifecycle`
- **Nội dung:** Sequence/Flowchart
  - Steps:
    1. Pod Created → MutatingWebhook inject vault-agent-init
    2. vault-agent → Vault: Auth (K8s ServiceAccount token)
    3. Vault → MySQL: CREATE USER 'usr_random' GRANT SELECT,INSERT,UPDATE,DELETE
    4. Vault → vault-agent: {username, password, lease_id, lease_duration=3600}
    5. vault-agent → tmpfs: write /vault/secrets/.env.db
    6. env-loader: merge .env files → /app-secrets/.env
    7. App: read .env → connect MySQL
    8. [Loop] TTL expires → Vault Agent renew/re-fetch
    9. Vault: DROP USER IF EXISTS 'old_user' → CREATE new user
    10. env-watcher: detect change → call /api/internal/reload-db
- **Tool:** draw.io sequence diagram
- **File:** `vault_jit_lifecycle.png`

---

## HÌNH 3.5: Screenshot Vault credentials
- **Label:** `fig:vault_proof_screenshot`
- **Cách chụp:**
  - **(a)** `kubectl exec -n job7189-apps deploy/identity-service -c app -- cat /app-secrets/.env | grep DB_` → hiện DB_USERNAME, DB_PASSWORD ngẫu nhiên
  - **(b)** `kubectl exec -n vault vault-0 -- vault list sys/leases/lookup/database/creds/` → hiện 7 service folders
- **File:** `vault_proof_screenshot.png`

---

## HÌNH 3.6: Screenshot Hubble UI
- **Label:** `fig:hubble_ui`
- **Cách chụp:** Port-forward Hubble UI (`kubectl -n kube-system port-forward svc/hubble-ui 12000:80`), mở browser, chọn namespace `job7189-apps`
- **Nội dung:** Network flow map hiển thị:
  - Mũi tên xanh = FORWARDED (ví dụ: kong → identity-service)
  - Mũi tên đỏ = DROPPED (ví dụ: attacker-pod → identity-service)
  - Các node = Pods/Services
- **File:** `hubble_ui_screenshot.png`

---

## HÌNH 3.7: Screenshot microsegmentation proof
- **Label:** `fig:microseg_proof`
- **Cách chụp:**
  - **(a)** Tạo attacker pod: `kubectl run attacker --image=busybox -n job7189-apps --serviceaccount=default -- sleep 3600`, rồi `kubectl exec attacker -- wget -qO- --timeout=3 http://identity-service:80/api/v1/auth` → timeout/refused
  - **(b)** Tạo allowed pod: `kubectl run allowed-client --image=busybox -n job7189-apps --serviceaccount=test-client-allowed -- sleep 3600`, rồi `kubectl exec allowed-client -- wget -qO- --timeout=3 http://identity-service:80/api/v1/auth` → 200 OK
- **File:** `microseg_proof_screenshot.png`

---

## HÌNH 3.8: Screenshot Kibana
- **Label:** `fig:kibana_screenshot`
- **Cách chụp:** Port-forward Kibana (`kubectl -n monitoring port-forward svc/kibana 30601:5601`), mở browser
- **Nội dung:** Kibana Discover tab, filter:
  - `kubernetes.namespace: "gateway"` → thấy Kong access logs
  - Highlight entry có status 401 (Unauthorized)
- **File:** `kibana_screenshot.png`

---

## HÌNH 3.9: Screenshot Grafana Dashboard
- **Label:** `fig:grafana_dashboard`
- **Cách chụp:** Port-forward Grafana (`kubectl -n monitoring port-forward svc/grafana 30600:3000`)
- **Nội dung:** Dashboard gồm các panel:
  - **Panel 1:** Cilium Forward/Drop rate (PromQL: `rate(hubble_flows_processed_total[5m])`)
  - **Panel 2:** Node CPU/Memory usage (node-exporter)
  - **Panel 3:** Pod restart count (kube_pod_container_status_restarts_total)
  - **Panel 4:** Kafka consumer lag (nếu có)
- **Nếu chưa có dashboard sẵn:** Tạo mới bằng cách Import dashboard hoặc thêm panel thủ công
- **File:** `grafana_dashboard_screenshot.png`

---

## HÌNH 3.10: Tetragon SIGKILL flow
- **Label:** `fig:tetragon_sigkill`
- **Nội dung:** Flowchart/Diagram
  - Container → sys_execve("/usr/bin/wget") → Kernel
  - eBPF hook trên sys_execve → Tetragon TracingPolicy check
  - Match: binary trong blacklist → Action: SIGKILL
  - **Kết quả:** Process bị kill TRƯỚC KHI kernel thực thi
  - **Nếu không match:** → Allow → Kernel execute normally
- **Lưu ý:** Component này chưa triển khai, vẽ theo thiết kế
- **File:** `tetragon_sigkill_flow.png`

---

## HÌNH 3.11: Screenshot Vault rotation proof
- **Label:** `fig:rotation_proof`
- **Cách chụp:**
  - **(a)** Set TTL ngắn: `vault write database/roles/identity-service default_ttl=300` → read creds → thấy `lease_duration: 300`
  - **(b)** Revoke all: `vault lease revoke -prefix database/creds/identity-service` → curl service → vẫn 200 OK (Vault Agent auto-renewed)
- **File:** `vault_rotation_proof.png`

---

## HÌNH 3.12: Screenshot kubectl get pods
- **Label:** `fig:pods_status`
- **Cách chụp:** `kubectl get pods -A --sort-by=.metadata.namespace | grep -E "gateway|security|vault|data|job7189|monitoring"` → chụp terminal
- **Nội dung cần thấy:**
  - Mọi pod `Running`, không có `CrashLoopBackOff`
  - Backend services: `4/4 READY` (4 containers)
  - Vault: `1/1 READY`
- **File:** `pods_status_screenshot.png`

---

## HÌNH 3.13: Deployment Pipeline
- **Label:** `fig:deployment_pipeline`
- **Nội dung:** Flowchart ngang 5 bước
  - **01** Cluster Setup → checkpoint: Cilium healthy
  - **02** Infrastructure → checkpoint: Vault unsealed, DB engine ready
  - **03** Microservices → checkpoint: Vault Agent inject OK, 4/4 containers
  - **04** Image Build → checkpoint: images pushed to local registry
  - **05** Database Seed → checkpoint: SQL loaded via Vault credentials
- **Mỗi bước:** ghi rõ thành phần chính và ZTA checkpoint
- **Tool:** draw.io / mermaid
- **File:** `deployment_pipeline_flow.png`

---

## Checklist tổng hợp

| # | Tên file | Loại | Ưu tiên |
|---|----------|------|---------|
| 3.1 | `architecture_5_layer.png` | Vẽ (draw.io) | ⭐⭐⭐ |
| 3.2 | `oidc_jwt_sequence.png` | Vẽ (plantuml) | ⭐⭐⭐ |
| 3.3 | `jwt_proof_screenshot.png` | Chụp (terminal) | ⭐⭐⭐ |
| 3.4 | `vault_jit_lifecycle.png` | Vẽ (draw.io) | ⭐⭐⭐ |
| 3.5 | `vault_proof_screenshot.png` | Chụp (terminal) | ⭐⭐ |
| 3.6 | `hubble_ui_screenshot.png` | Chụp (browser) | ⭐⭐⭐ |
| 3.7 | `microseg_proof_screenshot.png` | Chụp (terminal) | ⭐⭐⭐ |
| 3.8 | `kibana_screenshot.png` | Chụp (browser) | ⭐⭐ |
| 3.9 | `grafana_dashboard_screenshot.png` | Chụp (browser) | ⭐⭐ |
| 3.10 | `tetragon_sigkill_flow.png` | Vẽ (draw.io) | ⭐ |
| 3.11 | `vault_rotation_proof.png` | Chụp (terminal) | ⭐⭐ |
| 3.12 | `pods_status_screenshot.png` | Chụp (terminal) | ⭐⭐⭐ |
| 3.13 | `deployment_pipeline_flow.png` | Vẽ (draw.io) | ⭐⭐ |
