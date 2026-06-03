# DAAS Classification & Microperimeter — Step 2.3.2

> **Mục đích:** Phân loại Data / Applications / Assets / Services theo từng
> namespace + xác định **Protection Surface** (bề mặt bảo vệ) và Tier theo Mục
> 2.3.2 / 3.4.2 đồ án 1. Đầu vào của bước này là baseline ở PR #7 và các
> deployment YAML hiện có.

## Khung phân loại

Theo Mục 2.3.2 thesis:

- **D — Data**: dữ liệu nhạy cảm cần bảo vệ (CV, hồ sơ, secret, credential).
- **A — Applications**: ứng dụng xử lý/tiêu thụ Data.
- **A — Assets**: tài sản hạ tầng (OS, container, certificate).
- **S — Services**: dịch vụ phụ trợ (DNS, observability, ingress).

Mỗi đơn vị được gắn **Tier**:

| Tier | Tên | Tác động khi compromise | Chiến lược policy |
|------|-----|-------------------------|---------------------|
| T1 | Critical | Lộ data nhạy / Lateral movement → toàn cluster | default-deny + identity allow-list rất chặt + L7 + mTLS |
| T2 | Important | Mất tính khả dụng dịch vụ chính | default-deny + identity allow-list + L4 |
| T3 | Less critical | Ảnh hưởng chỉ phần admin / dev tooling | default-deny + allow-list rộng hơn (HTTP basic only) |

## Bảng DAAS — toàn cluster

Dữ liệu lấy từ baseline `evidence/baseline-20260426_031945/` (PR #7).

### Namespace `data` (T1)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| D | `mysql` | DB chứa user / company / job / resume / message | 3306 | T1 |
| D | `kafka` | Event bus (apply-job, message, audit) | 9092 / 9093 | T1 |
| A | (không host app) | — | — | — |
| A | PVC `mysql-pvc`, kafka volume | persistent storage | — | T1 |

**Protection surface**: tất cả pod trong `data` chỉ được nhận traffic từ
identity hợp lệ (mysql ← identity-service / hiring / job / candidate;
kafka ← các service emit event). Không pod nào trong `data` được phép egress
ra Internet.

### Namespace `vault` (T1)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| D | `vault` (StatefulSet) | Master Vault, secret store, dynamic DB creds | 8200 / 8201 | T1 |
| D | `vault-dev` | Transit unsealer (dev mode, ephemeral) | 8300 | T1 |
| A | `vault-injector` (helm release) | Mutating webhook, inject Vault Agent vào pod | 443 (webhook) | T1 |

**Protection surface**: vault chỉ được nhận:
- Ingress 8200 từ pod đã `serviceAccount` được Vault role mapping.
- Ingress 8201 chỉ giữa các pod trong cùng namespace (raft peers).
- Ingress 8300 (vault-dev) chỉ từ vault-prod (auto-unseal flow) trong cùng namespace.

Không pod `data`/`vault` được egress ra Internet.

### Namespace `security` (T1)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| A | `keycloak` | OIDC provider, IAM | 8080 | T1 |
| D | Keycloak DB (lưu trong mysql) | user/realm config | (qua 3306 ở data) | T1 |

Tham khảo baseline: `- → security TCP/4180` (114 flow) là oauth2-proxy
sidecar đứng trước Kibana/Grafana/phpmyadmin (port 4180 oauth2-proxy default).

**Protection surface**: keycloak chỉ nhận:
- Ingress 8080 từ ingress-nginx + gateway (Kong) + oauth2-proxy + job7189-apps (JWKS fetch).
- Egress: data/3306 (DB) + DNS.

### Namespace `gateway` (T2)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| S | `kong-gateway` | PEP biên (north-south), JWT validate | 8000 (proxy), 8001 (admin) | T2 |

**Protection surface**: kong nhận ingress 8000 từ ingress-nginx; egress
tới mọi service trong job7189-apps + keycloak (security/8080).
Cổng admin 8001 chỉ được truy cập từ pod cùng namespace.

### Namespace `job7189-apps` (T1 cho identity, T2 cho phần còn lại)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| A | `identity-service` | OIDC bridge, profile, user mapping | 80 | T1 |
| A | `workspace-service` | Workspace CRUD, member, permission | 80 | T2 |
| A | `job-service` | Job listing, draft, public search | 80 | T2 |
| A | `hiring-service` | Pipeline, board, interview | 80 | T2 |
| A | `candidate-service` | CV, applications, interactions | 80 | T2 |
| A | `communication-service` | Chat, email | 80 | T2 |
| A | `storage-service` | Presigned URL → MinIO | 80 | T2 |

**Protection surface**: mỗi service chỉ nhận từ Kong (gateway/kong-gateway)
+ các service cùng namespace gọi `internal/*` route. Egress: chỉ tới các
service nó cần (xem ma trận 5W1H ở PR #10).

### Namespace `monitoring` (T2 / T3 trộn)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| S | `prometheus` | Metrics scrape | 9090 | T2 (cần egress rộng) |
| S | `grafana` | Metrics UI | 3000 | T3 |
| D | `elasticsearch` | Log store | 9200 | T2 |
| S | `kibana` | Log UI | 5601 | T3 |
| S | `filebeat` (DaemonSet) | Log shipper | hostNetwork | T2 |

**Protection surface**:
- prometheus cần **egress scrape** rộng (every namespace, multiple ports) →
  policy mở hơn nhưng chỉ cho serviceAccount `prometheus`.
- elasticsearch ingress chỉ từ `filebeat` + `kibana` + `grafana`.
- kibana/grafana ingress chỉ từ `oauth2-proxy` + `ingress-nginx`.

### Namespace `management` (T3)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| S | `phpmyadmin` | DB UI (admin) | 8080 → 80 (svc) | T3 |
| ~~S~~ | ~~`kafbat`~~ | ~~Kafka UI (admin)~~ | ~~8080 → 80 (svc)~~ | ~~T3~~ | (removed — never used)

**Protection surface**: ingress chỉ từ oauth2-proxy. Egress:
phpmyadmin → data/3306. (Kafbat removed; see
`infras/k8s-yaml/03-kafka.yaml` Phần 2.)

### Namespace `registry` (T3)

| Loại | Workload | Mô tả | Port | Tier |
|------|----------|-------|------|------|
| A | `docker-registry` | Container image storage | 5000 | T3 |

**Protection surface**: ingress 5000 từ tất cả node (kubelet pulling
images) — sử dụng `nodeSelector` trong policy. Egress: chỉ DNS + (tuỳ
chọn) bucket lưu blob.

### Namespace `kube-system` / `cilium-secrets` / `cert-manager` / `ingress-nginx` / `local-path-storage` / `default` (system)

Không áp default-deny user-defined ở các namespace này — đây là plane control
do K8s/Cilium quản lý. Truy cập điều khiển bằng RBAC + Pod Security
Standards.

## Microperimeter map (luồng cross-namespace ALLOWED)

Dựa trên baseline (`12-hubble-flow-summary.txt`) — chỉ liệt kê luồng ALLOWED
xuất hiện thực tế trong baseline. Luồng nào không có ở đây mà thấy trong
DROPPED là đúng spec (không cần mở).

```
Internet
   ↓
ingress-nginx (host network)
   ↓ HTTPS 443
gateway/kong-gateway (8000)
   ├──→ security/keycloak (8080)         [JWKS, OIDC discovery]
   ├──→ job7189-apps/identity-service (80)
   ├──→ job7189-apps/workspace-service (80)
   ├──→ job7189-apps/job-service (80)
   ├──→ job7189-apps/hiring-service (80)
   ├──→ job7189-apps/candidate-service (80)
   ├──→ job7189-apps/communication-service (80)
   └──→ job7189-apps/storage-service (80)

job7189-apps/* ──→ data/mysql (3306)
job7189-apps/* ──→ data/kafka (9092)
job7189-apps/* ──→ vault/vault (8200)
job7189-apps/* ──→ kube-system/kube-dns (53)

monitoring/prometheus ──→ <every-ns>/<exporter-port>      (scrape)
monitoring/filebeat ──→ monitoring/elasticsearch (9200)
monitoring/kibana ──→ monitoring/elasticsearch (9200)
monitoring/grafana ──→ monitoring/prometheus (9090)
monitoring/grafana ──→ monitoring/elasticsearch (9200)

ingress-nginx ──→ security/oauth2-proxy (4180)
oauth2-proxy ──→ security/keycloak (8080)
oauth2-proxy ──→ monitoring/kibana (5601)
oauth2-proxy ──→ monitoring/grafana (3000)
oauth2-proxy ──→ management/phpmyadmin (80)
# oauth2-proxy ──→ management/kafbat (80)   # removed

management/phpmyadmin ──→ data/mysql (3306)
# management/kafbat ──→ data/kafka (9092)        # removed

vault ──→ kube-system/kube-apiserver (6443)               [auth-delegator]
security/keycloak ──→ data/mysql (3306)
```

Tất cả flow khác = DROPPED.

## Tier-based policy strategy

| Tier | Default | Identity strictness | L7? | mTLS |
|------|---------|---------------------|-----|------|
| T1 (data, vault, security, identity-service) | `default-deny` | Per-ServiceAccount allow-list | Có cho HTTP path | Required khi PR #11 |
| T2 (job7189-apps khác, gateway, monitoring) | `default-deny` | Per-ServiceAccount allow-list | L4 chỉ + L7 cho admin route | Optional |
| T3 (management, registry) | `default-deny` | Namespace-level allow | L4 | No |

## Policy file layout

```
infras/k8s-yaml/cilium-policies/
├── 00-default-deny.yaml             (job7189-apps — đã có)
├── 01-allow-egress-dns.yaml         (job7189-apps — đã có)
├── 02-allow-egress-data.yaml        (job7189-apps — đã có)
├── 03-allow-ingress-kong.yaml       (job7189-apps — đã có)
├── 04-allow-internal-api-strict.yaml (job7189-apps — đã có)
├── apply-zta-microsegmentation.sh   (job7189-apps applier — đã có)
└── namespaces/                       (PR #8 thêm vào)
    ├── README.md
    ├── 10-data.yaml                  (default-deny + allow ingress, đã 1 phần ở 20-security)
    ├── 11-vault.yaml
    ├── 12-security.yaml
    ├── 13-monitoring.yaml
    ├── 14-gateway.yaml
    ├── 15-management.yaml
    ├── 16-registry.yaml
    └── apply-zta-namespace-policies.sh   (per-namespace dry-run + apply)
```

## Verify check list

Sau khi apply một namespace, dùng baseline tool ở PR #7 lần nữa và so sánh
DROPPED count:

| NS đã apply | Expected DROPPED tăng |
|-------------|------------------------|
| `monitoring` | Ingress lạ vào prometheus / kibana không qua oauth2-proxy |
| `management` | Truy cập phpmyadmin ngoài oauth2-proxy (kafbat removed) |
| `gateway` | Truy cập kong admin từ ngoài |
| `vault` | Truy cập 8200/8201 sai serviceAccount |
| `security` | Truy cập keycloak ngoài bridge cho phép |
| `registry` | Truy cập 5000 từ pod không phải kubelet/CI |

Bước tiếp theo (PR #9): chuẩn hoá labels 4-6 tiêu chí để allow-list khớp
được role/tier — không chỉ serviceAccount.
