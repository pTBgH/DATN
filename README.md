# DATN — Zero Trust Architecture (ZTA) for Kubernetes

Đồ án tốt nghiệp triển khai Zero Trust Architecture trên cụm Kubernetes
(Kind/lab), với các trụ cột:

- **Identity:** Keycloak Dual-Realm + Vault dynamic credentials (JIT) + SPIRE/SPIFFE
- **Network:** Cilium microsegmentation (L3-L7) + WireGuard + mTLS
- **Workload:** Tetragon eBPF runtime + OPA Gatekeeper + sigstore policy-controller
- **Observability:** Hubble flows → Elasticsearch + Prometheus + Grafana
- **Adaptive Loop:** PDP Controller (continuous trust scoring)

## Knowledge base

Tất cả tài liệu kỹ thuật đã được hợp nhất trong `doc/`. Bắt đầu từ:

- [`doc/README.md`](doc/README.md) — index 32 chương + 3 incident reports
- [`doc/00-project-overview.md`](doc/00-project-overview.md) — overview 7 services + namespaces
- [`doc/08-deployment-pipeline.md`](doc/08-deployment-pipeline.md) — pipeline 30 steps
- [`doc/architecture/`](doc/architecture/) — kiến trúc deep-dive + demo scenarios
- [`doc/archive/`](doc/archive/) — tài liệu cũ giữ làm chứng cứ thesis
- [`doc/incident-*.md`](doc/) — 3 incident reports (probe-webhook, CRD timeout, RAM)

## Cách chạy (lab VM)

```bash
# Pre-flight: cần >= 1500 MiB RAM available, 1-min load < 30
free -m | head -2
uptime

# Full rebuild (30 steps)
bash scripts/zta-rebuild.sh --yes

# Resume từ một step nhất định (giữ nguyên cluster)
bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes

# Verify
bash 09-verify-zta.sh
```

Xem [`doc/23-rebuild-from-scratch.md`](doc/23-rebuild-from-scratch.md) cho chi
tiết từng step và rollback strategy.

## Tinh gọn workspace (2026-05-05)

Workspace vừa được dọn lớn — xem [`doc/cleanup-workspace-plan.md`](doc/cleanup-workspace-plan.md)
cho 4 PR (PR-A → PR-D) và quyết định liên quan.

**Frontend:** thư mục `frontend/` (root) là nơi đang phát triển tiếp; mọi
frontend `fe_candidate`/`fe_recruiter` lẩn trong `src/`, helmfile, build script
đã được gỡ bỏ khỏi pipeline ZTA.

## Cấu trúc thư mục

```
DATN/
├── 01-...09-*.sh, 10-*.sh         # Pipeline orchestration scripts (root)
├── scripts/                        # ZTA-specific deploy/util scripts
├── infras/k8s-yaml/                # Kubernetes manifests (live)
├── k8s-management/                 # Helm charts + helmfile (laravel-app)
├── src/                            # 7 Laravel microservices (backend)
├── frontend/                       # Next.js (active dev — không build trong pipeline)
├── DB/                             # MySQL seed SQL files
├── documents/                      # Thesis LaTeX nguồn
├── doc/                            # Knowledge base (32 chương)
├── evidence/                       # Runtime evidence (gitignored mostly)
└── postman/                        # Postman collections
```
