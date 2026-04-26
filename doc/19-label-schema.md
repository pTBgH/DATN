# Workload Label Schema (ZTA Step 2.3.3)

> Reference: Đồ án 1, Mục 2.3.3 / 3.4.3 — *Gắn nhãn workload theo 4-6 tiêu chí để hỗ trợ identity-based security*.

ZTA yêu cầu mọi quyết định security dựa trên **identity** chứ không phải IP. Để thực thi điều đó với Cilium, mỗi workload (Pod) phải mang đủ label phục vụ hai mục đích:
1. **Selector cho CNP** — `endpointSelector.matchLabels` chỉ định "ai" được phép.
2. **Audit / Policy authoring** — DAAS map (PR #8) ↔ workload label ↔ 5W1H policy (PR #10).

Repo dùng **prefix riêng `zta.job7189/`** cho tất cả label do PR #9 thêm vào, để KHÔNG đụng:
- Existing label `app: <name>` (đang được Service selector + CNP selector cũ dùng — IMMUTABLE).
- Standard label `app.kubernetes.io/*` (Kubernetes recommended).
- Cilium-managed label `io.kubernetes.pod.namespace`, `io.cilium.k8s.policy.serviceaccount`.

---

## 6 label keys bắt buộc

| Key | Giá trị hợp lệ | Mô tả |
|---|---|---|
| `zta.job7189/role` | `api` / `worker` / `cache` / `db` / `broker` / `proxy` / `sso` / `secret-store` / `ui` / `monitoring` / `scraper` | Vai trò chính của workload trong kiến trúc. |
| `zta.job7189/tier` | `T1` / `T2` / `T3` | Mức ưu tiên Protection Surface (mirror DAAS — PR #8): **T1** critical (data confidential, identity, secrets), **T2** important (observability, gateway, message broker), **T3** low-risk (UI admin, dev tools). |
| `zta.job7189/env` | `prod` / `dev` / `staging` | Môi trường vận hành. |
| `zta.job7189/data-classification` | `confidential` / `internal` / `public` / `none` | Loại data workload xử lý trực tiếp (T1 luôn ≥ `internal`; chỉ static frontend mới `public`). |
| `zta.job7189/exposure` | `external` / `internal` / `cluster-only` | Mức expose: **external** (Internet qua NodePort/Ingress public), **internal** (Ingress nội bộ, qua oauth2-proxy SSO), **cluster-only** (chỉ cluster-internal traffic). |
| `zta.job7189/team` | `platform` / `backend` / `frontend` / `data` / `security` | Đội ngũ owner — phục vụ alerting/oncall mapping. |

---

## Bảng workload → labels

### Infrastructure (`infras/k8s-yaml/`)

| Workload | Namespace | role | tier | env | data-classification | exposure | team |
|---|---|---|---|---|---|---|---|
| `mysql` | data | db | T1 | prod | confidential | cluster-only | data |
| `phpmyadmin` | management | ui | T3 | prod | internal | internal | platform |
| `keycloak` | security | sso | T1 | prod | confidential | internal | security |
| `oauth2-proxy` | security | proxy | T1 | prod | confidential | internal | security |
| `kafka` | data | broker | T1 | prod | confidential | cluster-only | data |
| `kafbat` | management | ui | T3 | prod | none | internal | data |
| `kong-gateway` | gateway | proxy | T2 | prod | none | external | platform |
| `vault-0` (vault-prod) | vault | secret-store | T1 | prod | confidential | cluster-only | security |
| `vault-dev` | vault | secret-store | T1 | dev | internal | cluster-only | security |
| `vault-agent-injector` | vault | proxy | T1 | prod | confidential | cluster-only | security |
| `elasticsearch` | monitoring | db | T2 | prod | internal | cluster-only | platform |
| `filebeat` | monitoring | scraper | T2 | prod | none | cluster-only | platform |
| `kibana` | monitoring | ui | T2 | prod | internal | internal | platform |
| `prometheus` | monitoring | monitoring | T2 | prod | none | cluster-only | platform |
| `grafana` | monitoring | ui | T2 | prod | internal | internal | platform |
| `kube-state-metrics` | monitoring | scraper | T2 | prod | none | cluster-only | platform |
| `node-exporter` | monitoring | scraper | T2 | prod | none | cluster-only | platform |
| `minio` | data | db | T2 | prod | internal | cluster-only | data |
| `docker-registry` | registry | db | T3 | prod | none | cluster-only | platform |

### Microservices (`k8s-management/charts/`)

| Workload | Namespace | role | tier | env | data-classification | exposure | team |
|---|---|---|---|---|---|---|---|
| `identity-service` | job7189-apps | api | T1 | prod | confidential | internal | backend |
| `hiring-service` | job7189-apps | api | T2 | prod | internal | internal | backend |
| `candidate-service` | job7189-apps | api | T2 | prod | internal | internal | backend |
| `job-service` | job7189-apps | api | T2 | prod | internal | internal | backend |
| `workspace-service` | job7189-apps | api | T2 | prod | internal | internal | backend |
| `communication-service` | job7189-apps | api | T2 | prod | internal | internal | backend |
| `storage-service` | job7189-apps | api | T2 | prod | internal | internal | backend |
| `identity-service-redis` | job7189-apps | cache | **T1** | prod | confidential | cluster-only | backend |
| `<other-service>-redis` | job7189-apps | cache | T2 | prod | internal | cluster-only | backend |
| `fe-candidate` | frontend | ui | T3 | prod | public | internal | frontend |
| `fe-recruiter` | frontend | ui | T3 | prod | public | internal | frontend |

> Ghi chú: mỗi service có Redis sidecar riêng (vd `hiring-service-redis`). Helm chart `laravel-app` template Redis tier+data-classification kế thừa từ parent service — Redis của identity-service tự động T1/confidential vì cache session token nhạy cảm; Redis các service khác là T2/internal.

---

## Cách áp dụng

### 1) Manifest (bền lâu — pod restart vẫn còn label)

YAML files trong `infras/k8s-yaml/*.yaml` đã được patch để **bao gồm cả 6 label** trong `metadata.labels` (Deployment-level) **và** `spec.template.metadata.labels` (Pod-level). Helm charts trong `k8s-management/charts/*/templates/deployment.yaml` đã được template hoá để nhận `values.zta.role/tier/...`.

Re-apply qua script deploy thông thường (`02-deploy-infrastructure.sh`, `03-deploy-microservices.sh`, hoặc `helm upgrade`).

### 2) Live cluster (idempotent — không cần re-deploy)

Dùng `scripts/zta-apply-workload-labels.sh` — gọi `kubectl label deployment/statefulset/daemonset` với `--overwrite` cho từng workload theo bảng trên. Script idempotent, an toàn chạy nhiều lần.

```bash
bash scripts/zta-apply-workload-labels.sh         # dry-run mặc định
bash scripts/zta-apply-workload-labels.sh --apply # áp thật
```

### 3) Verify

```bash
bash scripts/zta-verify-labels.sh
```

Script sẽ liệt kê workload thiếu bất kỳ label nào trong 6 keys bắt buộc. Đầu ra dùng cho audit Phase 4.

---

## Liên kết với các PR khác

- **PR #8 (DAAS + microperimeter)**: `tier` trong label này = Protection Surface tier trong DAAS doc.
- **PR #10 (5W1H Policy Matrix)**: CNP mới sẽ dùng `endpointSelector.matchLabels.zta.job7189/role` thay vì `app:` — selector dựa trên IDENTITY thay vì name.
- **PR #11 (Adaptive Security)**: `zta.job7189/state=quarantined` (label do Tetragon controller patch) sẽ override mọi allow-list khác.

## Anti-pattern cần tránh

- **KHÔNG đổi `app: <name>`** trên các workload đã chạy — sẽ break Deployment selector (immutable).
- **KHÔNG dùng giá trị tự do**: chỉ enum trong bảng. CI sẽ fail nếu giá trị không hợp lệ (PR #10 có thể thêm OPA/Gatekeeper enforcement).
- **KHÔNG xếp tier theo cảm tính**: tier chỉ căn cứ DAAS classification chính thức (`doc/18-daas-classification.md`).
