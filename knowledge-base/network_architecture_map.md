# Bản đồ Kiến trúc Mạng và Phân tích Luồng Dữ liệu (Chi tiết Toàn diện)

Bản đồ này liệt kê **100%** các luồng mạng giữa hơn 70 pods đang hoạt động trên 13 namespaces trong cụm Kubernetes. Mục đích là để làm "Kinh thánh" (Source of Truth) cho việc thiết lập các luật ZTA Microsegmentation (CiliumNetworkPolicy) sau này.

---

## 1. Sơ đồ Cốt lõi: Luồng Ứng dụng & Dữ liệu (Business & Data Flow)

Đây là luồng chính phục vụ người dùng cuối, bao gồm xác thực (N-S) và gọi dịch vụ nội bộ (E-W).

```mermaid
flowchart TD
    subgraph NS_External ["Bên ngoài (External)"]
        User(("End User"))
    end

    subgraph NS_Gateway ["Gateway & Ingress"]
        LB["HAProxy/Cloud LB"]
        ING["Ingress-Nginx\n:80, :443, metrics:10254"]
        KONG["Kong Gateway\nproxy:8000/8443"]
    end

    subgraph NS_Security ["Identity & Policy"]
        O2P["OAuth2-Proxy\n:4180"]
        KC["Keycloak\n:8080"]
        VAULT["Vault\n:8200"]
    end

    subgraph NS_Apps ["job7189-apps (Microservices)"]
        JS["job-service\n:8000"]
        HS["hiring-service\n:8000"]
        CS["candidate-service\n:8000"]
        COMS["communication-service\n:8000"]
        WS["workspace-service\n:8000"]
        IS["identity-service\n:8000"]
        
        REDIS[("Redis Local\n:6379 x6")]
    end

    subgraph NS_Data ["data"]
        MYSQL[("MySQL\n:3306")]
        KAFKA[["Kafka\n:9092"]]
    end

    %% Flow User -> Gateway
    User -->|HTTPS| LB
    LB -->|TCP| ING
    ING -->|TCP| KONG

    %% Flow Gateway -> Auth
    KONG -->|Xác thực JWT / HTTP| O2P
    O2P -->|OIDC Flow / HTTP| KC
    KONG -->|Verify JWKS / HTTP| KC

    %% Flow Gateway -> Apps
    KONG -->|Forward Request / HTTP| JS & HS & CS & COMS & WS & IS

    %% Flow Apps -> Cache
    JS & HS & CS & COMS & WS & IS -->|Ghi/Đọc Cache / TCP| REDIS

    %% Flow Vault Init
    JS & HS & CS & COMS & WS & IS -.->|Vault Agent Init / TCP| VAULT
    VAULT -.->|Quản lý User JIT| MYSQL

    %% Flow Apps -> DB/Message
    JS & HS & CS & COMS & WS & IS ==>|Data / TCP| MYSQL
    JS & HS & CS & COMS & WS & IS ==>|Event Message / TCP| KAFKA

    %% E-W Apps
    JS -->|Internal API / HTTP| WS
    HS -->|Internal API / HTTP| CS
```

---

## 2. Sơ đồ Quan sát & Giám sát (Observability Flow)

Giám sát metrics và logs từ **mọi pod** trong cụm. Đây là lý do tại sao các Namespace cần mở cổng cho Prometheus và Kubelet.

```mermaid
flowchart LR
    subgraph Monitoring_Core ["namespace: monitoring"]
        PROM["Prometheus\n:9090"]
        KSM["kube-state-metrics\n:8080"]
        NODE_EXP["node-exporter\n:9100 (DaemonSet)"]
        ES[("Elasticsearch\n:9200")]
        KIBANA["Kibana\n:5601"]
        FBEAT["Filebeat\nDaemonSet"]
    end

    subgraph Cluster_Wide_Targets ["Tất cả Namespaces"]
        PODS["Mọi Pods / Apps"]
        KUBELET["Kubelet trên các Node\n:10250"]
        VAULT_T["Vault\n:8200"]
        KC_T["Keycloak\n:8080"]
        CERT_T["Cert-Manager\n:9402, :9403"]
        SPIRE_T["Spire\n:8080, :8081, :9809"]
        NGINX_T["Ingress-Nginx\n:10254"]
    end

    %% Metrics Scraping
    PROM -->|Scrape /metrics| NODE_EXP
    PROM -->|Scrape /metrics| KSM
    PROM -->|Scrape /metrics| VAULT_T
    PROM -->|Scrape /metrics| KC_T
    PROM -->|Scrape /metrics| CERT_T
    PROM -->|Scrape /metrics| SPIRE_T
    PROM -->|Scrape /metrics| NGINX_T
    PROM -->|Scrape cAdvisor| KUBELET

    %% Logging Flow
    FBEAT -->|Read /var/log/containers| KUBELET
    FBEAT -->|Push Logs / TCP| ES
    KIBANA -->|Query Logs / HTTP| ES

    %% Probes
    KUBELET -.->|Liveness/Readiness/Startup| PODS
```

---

## 3. Sơ đồ Control Plane & Webhook (Security / Admission)

Mọi thao tác tạo Pod đều phải đi qua Kube-apiserver và bị kiểm duyệt bởi các Webhook bảo mật.

```mermaid
flowchart TD
    subgraph Kube_System ["namespace: kube-system"]
        API["kube-apiserver\n:6443"]
        DNS["CoreDNS\n:53 UDP/TCP"]
        CILIUM["Cilium / Hubble\nDaemonSet"]
    end

    subgraph Webhooks_Admission ["Security Webhooks"]
        V_INJ["Vault Agent Injector\n:8080 -> 443 SNAT"]
        CM_WEB["Cert-Manager Webhook\n:9403, :8443"]
        SIG_POL["Cosign Policy Controller\n:8443"]
        GATE["Gatekeeper Controller\n:8443"]
    end
    
    subgraph Internet ["Internet"]
        SIG_PUB["Sigstore Public\n:443"]
    end

    %% Kube-API calls Webhooks
    API ==>|Mutate Pods| V_INJ
    API ==>|Validate Certs| CM_WEB
    API ==>|Verify Image Signatures| SIG_POL
    API ==>|Enforce OPA Policies| GATE

    %% DNS
    Webhooks_Admission -.->|Phân giải tên miền| DNS
    
    %% External Sync
    SIG_POL -->|Refresh TUF Root| SIG_PUB
```

---

## 4. Ma trận Bắt chéo (Luật Tường lửa Cilium - Cross-Namespace Matrix)

Bảng này liệt kê chính xác các cổng phải được MỞ (Allow) nếu áp dụng `default-deny` ở mức Namespace.

| Từ (Source Namespace) | Tới (Destination Namespace) | Thành phần Đích | Port / Giao thức | Mục đích |
|---|---|---|---|---|
| **Mọi Namespace** | `kube-system` | CoreDNS | `53` (UDP/TCP) | Phân giải DNS nội bộ. *(Đã từng lỗi do L7 DNS proxy).* |
| **Mọi Node (Kubelet)** | Mọi Namespace | Mọi Pod | Đa dạng (`8080`, `9403`, `6080`...) | Liveness / Readiness Probes. *(Lưu ý: Không dùng L7 Proxy cho Probes).* |
| `monitoring` | `mọi namespace` | Metrics endpoints | `9100`, `10254`, `8080`, `9402`, `9809` | Prometheus cạo (scrape) metrics. |
| `monitoring` (Filebeat) | `monitoring` | Elasticsearch | `9200` (TCP) | Đẩy logs từ các node về trung tâm lưu trữ. |
| `kube-system` (Apiserver) | `vault` | Vault Injector | `8080`/`8443` (TCP) | Kube-apiserver gọi Webhook chèn sidecar. |
| `kube-system` (Apiserver) | `cert-manager` | CM Webhook | `9403`/`8443` (TCP) | Webhook xác nhận CertificateRequest. |
| `kube-system` (Apiserver) | `cosign-system` | Policy Webhook | `8443` (TCP) | Webhook kiểm tra chữ ký container image. |
| `kube-system` (Apiserver) | `gatekeeper-system` | Gatekeeper | `8443` (TCP) | Webhook ép quy định OPA. |
| `job7189-apps` | `vault` | Vault Server | `8200` (TCP) | Các Init Container lấy mật khẩu DB/Redis. |
| `job7189-apps` | `data` | MySQL | `3306` (TCP) | Lưu trữ Database (Đã xác thực bằng mTLS/Vault). |
| `job7189-apps` | `data` | Kafka | `9092` (TCP) | Hệ thống nhắn tin (Event-driven) giữa các microservice. |
| `job7189-apps` | `job7189-apps` | Redis | `6379` (TCP) | Cache/Queue cục bộ (ví dụ: `job-service` -> `job-service-redis`). |
| `job7189-apps` | `job7189-apps` | Dịch vụ khác | `8000` (TCP) | E-W API (vd: `job-service` gọi `workspace-service`). |
| `ingress-nginx` | `gateway` | Kong | `8000`, `8443` (TCP) | Chuyển tiếp HTTP(S) từ Ingress vào Gateway. |
| `job7189-apps` (Các Backend API) | `security` | Keycloak | `8080` (TCP) | Backend fetch JWKS public keys để xác thực JWT token (Tránh lỗi 401 Unauthorized). |
| `gateway` | `security` | OAuth2-Proxy | `4180` (TCP) | Kong chuyển tiếp request để xác thực JWT. |
| `gateway` | `security` | Keycloak | `8080` (TCP) | Kong fetch JWKS public keys để verify chữ ký JWT. |
| `security` (OAuth2-Proxy)| `security` | Keycloak | `8080` (TCP) | O2P lấy OIDC config và token. *(Đã từng lỗi do sai path trong L7 CNP).* |
| `gateway` | `job7189-apps` | Các App Laravel | `8000` (TCP) | Sau khi có Auth, Kong đẩy request xuống Backend. |
| `cosign-system` | `Internet (World)` | Sigstore Public | `443` (TCP) | Refresh TUF keys để verify chữ ký container. |
| `spire` | `kube-system` | Kube-apiserver | `6443` (TCP) | Spire-agent gọi API server để chứng thực Node. |

---

## 5. Kết luận

- Việc thiếu bất kỳ một luồng nào trong ma trận trên sẽ dẫn đến đứt gãy hệ thống (như lỗi DNS timeout của Vault Agent hay lỗi 503 của OAuth2-Proxy).
- **Tuyệt đối lưu ý:** Liveness/Readiness probe từ Kubelet và DNS resolution không nên bị giới hạn bởi các chính sách **L7 Proxy (HTTP/DNS rules)** của Cilium, bởi vì proxy nội bộ có thể gây nghẽn (TCP SYN_RECV) hoặc time-out UDP packets (Cilium agent bug/checksum issues). Chỉ dùng **L4 Policy** cho Kubelet probes và DNS.
