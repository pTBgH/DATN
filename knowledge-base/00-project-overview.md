# Project Overview — job7189 Zero Trust PoC

Quick reference cho AI/agent. Moi file doc tap trung 1 chu de, doc file nao tuy muc dich.

## He thong

- **Ten**: job7189 — He thong tuyen dung truc tuyen
- **Kien truc**: Microservices (7 Laravel PHP-FPM backend)
- **Ha tang**: Kubernetes 1.30, **kubeadm 4-node multi-VM** (mac dinh `--vm`): `srv01` control-plane + `srv02`/`srv03`/`srv05` worker. Mesh L3 qua Tailscale. (Legacy: Kind 1CP+3W chi cho local-dev qua `--kind` — xem `knowledge-base/migration/`.)
- **CNI**: Cilium eBPF (tat default CNI, Cilium tiep quan mang)
- **Bao mat**: Zero Trust Architecture theo NIST SP 800-207

## 7 Backend Microservices

| # | Service | Chuc nang | Database | Namespace |
|---|---------|-----------|----------|-----------|
| 1 | identity-service | Xac thuc, ho so, admin users | job7189_identity_db | job7189-apps |
| 2 | workspace-service | Quan ly workspace, loi moi | job7189_workspace_db | job7189-apps |
| 3 | job-service | Dang tuyen, quan ly viec lam | job7189_job_db | job7189-apps |
| 4 | hiring-service | Pipeline tuyen dung, phong van | job7189_hiring_db | job7189-apps |
| 5 | candidate-service | Ho so ung vien, CV | job7189_candidate_db | job7189-apps |
| 6 | communication-service | Hoi thoai, tin nhan, thong bao | job7189_communication_db | job7189-apps |
| 7 | storage-service | Presigned URL, luu tru tep | job7189_storage_db | job7189-apps |

## Pod Structure (moi backend service)

Moi service chay **4 containers** trong 1 Pod:
1. `app` — Laravel PHP-FPM application
2. `vault-agent` — Vault Agent sidecar (inject boi MutatingWebhook)
3. `env-loader` — Merge .env files tu Vault secrets
4. `env-watcher` — Detect lease rotation va goi reload endpoint

## Namespace Tiers

| Tier | Namespace | Thanh phan |
|------|-----------|------------|
| Gateway | `gateway`, `ingress-nginx` | Kong Gateway 3.6 (DB-less), Nginx Ingress Controller |
| Security | `security`, `cert-manager` | Keycloak (OIDC/JWT), oauth2-proxy, cert-manager |
| Application | `job7189-apps` | 7 Laravel services + Redis Cache |
| Data | `data` | MySQL 8.0, Kafka |
| Management | `management` | phpMyAdmin (Kafbat removed — Kafka UI never used) |
| Platform | `vault`, `monitoring` | Vault (Dual-Vault), EFK, Prometheus, Grafana |

## Luong giao dich chinh

### North-South (Client → He thong)
```
Client → Nginx Ingress → Kong Gateway (JWT check) → Backend Service → MySQL (via Vault JIT creds)
```

### East-West (Service → Service noi bo)
- `job-service` → `GET /api/v1/internal/workspaces/{id}` → `workspace-service`
- `hiring-service` → `GET /api/v1/internal/profile/{id}` → `identity-service`
- Moi service → MySQL (TCP 3306), Vault (TCP 8200), Kafka (TCP 9092), Redis (TCP 6379)

## Deployment Pipeline

| Script | Giai doan | Thanh phan |
|--------|-----------|------------|
| `01-setup-cluster.sh` | Cluster | Mac dinh VM mode (4-node kubeadm qua `knowledge-base/migration/scripts/bootstrap.sh`); `--kind` = Kind local-dev. Ca hai: + Cilium + cert-manager + Ingress |
| `02-deploy-infrastructure.sh` | Infra | Vault + MySQL + Keycloak + Kafka + Kong + EFK |
| `03-deploy-microservices.sh` | Apps | Registry + Build images + Helmfile 7 services |
| `04-build-and-push-images.sh` | Build | Sub-script: build 7 Laravel Docker images |
| `05-seed-databases.sh` | Data | Seed 7 database schemas |

## Key config files

| File | Muc dich |
|------|----------|
| `infras/kind/kind-config.yaml` | Kind cluster spec (CHI dung mode `--kind`/local-dev) |
| `knowledge-base/migration/scripts/bootstrap.sh` | Bootstrap cluster kubeadm 4-node (VM mode mac dinh) |
| `infras/kong/kong.yml` | Kong declarative routes + JWT |
| `infras/k8s-yaml/11-vault.yaml` | Dual-Vault deployment |
| `infras/k8s-yaml/02-keycloak.yaml` | Keycloak deployment |
| `infras/k8s-yaml/cilium-policies/*` | Microsegmentation policies |
| `infras/k8s-yaml/20-security-policies.yaml` | Additional security policies |
| `k8s-management/helmfile.yaml` | Helmfile: 7 services + 2 frontends |
| `k8s-management/values/laravel-common-values.yaml` | Shared resource limits + env |
