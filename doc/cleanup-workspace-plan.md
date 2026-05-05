# Workspace Cleanup Plan (executed)

**Date:** 2026-05-05
**Operator decision:** USER chose "execute 4 PRs in parallel" with custom override
on frontend (`từ từ — bỏ khỏi đống microservice thôi, vẫn còn 1 folder đang code
tên là frontend mà, cái lẩn trong đống src và helmfile thì xóa nhé`).

This document is the **executed plan**. Every item has a fixed verdict (KEEP /
DELETE / MOVE / EDIT) and is tracked across 4 PRs:

| PR | Branch (suffix) | Focus |
|---|---|---|
| **PR-A** | `pr-a-root-cleanup` | Root rác (`.md`/`.yaml`/diag dump/`mdfile/`/`app/`/`routes/`) |
| **PR-B** | `pr-b-scripts-cleanup` | `scripts/legacy/` + 7 utils 0-ref + `fix_tasks.sh` + duplicates |
| **PR-C** | `pr-c-frontend-lurkers` | `src/fe_*`, `06-build-frontends.sh`, `docker-compose.frontends.yml`, `k8s-management/charts/fe-*` + `charts/nextjs` + `values/fe-*-values.yaml` + `helmfile.yaml` edit |
| **PR-D** | `pr-d-verify-warnings-falco` | `09-verify-zta.sh` 10 WARN fixes + xóa Falco hoàn toàn (`scripts/zta-deploy-falco.sh`, `infras/k8s-yaml/falco/`, `doc/31` mark deprecated) |

**Pipeline (`scripts/zta-rebuild.sh`) untouched** — 16 scripts đều giữ nguyên,
`90-verify` retest sau merge sẽ thấy 12 WARN còn lại giảm xuống 2-3.

---

## A. Pipeline scripts (DO NOT TOUCH)

```
01-setup-cluster.sh                           02-deploy-infrastructure.sh
03-deploy-microservices.sh                    04-build-and-push-images.sh
05-seed-databases.sh                          07-deploy-monitoring-exporters.sh
08-harden-security.sh                         09-verify-zta.sh (edit in PR-D)
10-deploy-tetragon.sh                         scripts/zta-rebuild.sh
scripts/zta-apply-l7-policies.sh              scripts/zta-apply-workload-labels.sh
scripts/zta-cosign-keygen.sh                  scripts/zta-cosign-sign-deployment.sh
scripts/zta-deploy-gatekeeper.sh              scripts/zta-deploy-hubble-export.sh
scripts/zta-deploy-pdp.sh                     scripts/zta-deploy-policy-controller.sh
scripts/zta-deploy-spire.sh
```

## B. PR-A — Root junk (low risk)

**Delete:**
- `REGISTRY_DEPLOYMENT_COMPLETE.md`, `evidence.md`, `prompt-devin{,-2,-3,-4}.md`
- `auto-reload-solution.yaml`, `fix-filebeat.yaml`, `fix-vault-agent-config.yaml`,
  `fix_minio_ingress.yaml`, `minio-deploy.yaml`
- `app/Providers/HotReloadServiceProvider.php` + dir `app/`
- `routes/internal.php` + dir `routes/`
- `diag-20260430-142156/` + `diag-20260430-142156.tar.gz`
- `deployment-test.log`
- `lookup github.com 192.168.43.2`
- `mdfile/` toàn bộ (43 file) **trừ** `mdfile/important/` 3 file → MOVE → `doc/architecture/`

**Move into `doc/archive/`:**
- `app-behavior-analysis.md` → `doc/archive/`
- `dynamic-secret-test.md` → `doc/archive/`
- `mitigation-strategies.md` → `doc/archive/`
- `require.md` → `doc/archive/01-original-requirements.md`
- `sequence-diagram.md` → `doc/archive/`
- `startup_flow_analysis.md` → `doc/archive/`
- `vault-agent-startup-race-condition.md` → `doc/archive/`
- `vault-agent-verification.md` → `doc/archive/`
- `API-AUTHENTICATION-GUIDE.md` → `doc/api-authentication-guide.md` (active KB)

**Move into `doc/architecture/`:**
- `mdfile/important/SYSTEM_PORT_MAPPING_ARCHITECTURE.md`
- `mdfile/important/ZTA_ARCHITECTURE_DEEPDIVE.md`
- `mdfile/important/ZTA_DEMO_SCENARIOS.md`

**Edit `README.md`** — viết lại từ 1 dòng `# DATN` thành cổng vào repo
(link `doc/README.md`, `scripts/zta-rebuild.sh`, pre-flight checklist).

## C. PR-B — Scripts cleanup (medium risk)

**Delete:**
- `scripts/legacy/patch_storage.sh`, `scripts/legacy/rebuild-cluster.sh`,
  `scripts/legacy/rebuild-laravel.sh` → xóa thư mục `scripts/legacy/`
- `scripts/utils/check-seeded-databases.sh` (0 refs)
- `scripts/utils/fix.sh` (0 refs, 239 byte)
- `scripts/utils/fix_fs.sh` (0 refs, 265 byte)
- `scripts/utils/setup_logger.sh` (0 refs)
- `scripts/utils/test-api-endpoints.sh` (0 refs)
- `scripts/utils/test-vault-batch.sh` (0 refs, 28 byte)
- `scripts/utils/update_logs_and_rebuild.sh` (0 refs)
- `fix_tasks.sh` (0 refs)
- `setup-keycloak-clients.sh` (1 ref trong mdfile đang xóa, bị `-job7189` thay)
- `deploy-all.sh` (1 ref trong doc/23 — sửa doc/23)

**Move:**
- `00-cleanup-images.sh` → `scripts/legacy/00-cleanup-images.sh` (giữ làm util)
- `diag-cascade.sh` → `scripts/legacy/diag-cascade.sh` (giữ làm util)

## D. PR-C — Frontend lurkers (medium risk)

**Decision (USER):** GIỮ `frontend/` (root, đang code tiếp). XÓA tất cả frontend
"lẩn trong" microservice pile + helmfile.

**Delete:**
- `src/fe_candidate/` (172 KB, Next.js app)
- `src/fe_recruiter/` (108 KB, Next.js app)
- `06-build-frontends.sh`
- `docker-compose.frontends.yml`
- `k8s-management/charts/fe-candidate/`
- `k8s-management/charts/fe-recruiter/`
- `k8s-management/charts/nextjs/`
- `k8s-management/values/fe-candidate-values.yaml`
- `k8s-management/values/fe-recruiter-values.yaml`

**Edit:**
- `k8s-management/helmfile.yaml` — bỏ 2 release blocks `fe-candidate` (line 60-64) và `fe-recruiter` (line 66-71).
- `09-verify-zta.sh:354` — bỏ `frontend` khỏi `LABEL_NAMESPACES` (vì không còn workload deploy vào ns đó từ pipeline).
- `infras/k8s-yaml/99-ingress.yaml` — nếu còn route fe-* thì xoá (verify khi exec).
- `doc/00-project-overview.md`, `doc/19-label-schema.md`, `doc/23-rebuild-from-scratch.md` — note "frontend dev độc lập trong `frontend/` (không build trong pipeline ZTA)".

## E. PR-D — Verify warnings + Falco purge (medium risk)

### E.1 `09-verify-zta.sh` fixes (10 WARN)

| WARN | Fix |
|---|---|
| Kong port-forward 8s timeout | `09-verify-zta.sh:158` — bump 8s → 30s |
| `ns=registry does not exist` | bỏ key `[registry]` trong `NS_TO_DEFAULT_DENY` (line 280); bỏ `registry` khỏi `LABEL_NAMESPACES` (line 354) |
| `Hubble L7 flows = 0` | trước count L7 flows: generate dummy traffic (`kubectl run --rm curl-test ...`) hoặc warm-up sleep |
| `image-digest-required: 176 violations (audit mode)` | sửa wording WARN → INFO: "audit mode active — N images use mutable tags (expected; pin to digest when ready)" |
| `Could not auto-detect SPIRE trustDomain` | broaden grep cho cả `trust_domain` và `trustDomain` |
| `SPIRE workload integration demo not deployed` | bỏ check Test 4k (demo là step manual) |
| `No filebeat activity log` | thêm `sleep 30` warm-up trước check |
| `ES hubble-flows-* index not found yet` | cùng warm-up |
| `Falco runtime detection not deployed` | xoá Test 4m hoàn toàn (Falco bỏ) |

**KHÔNG fix bằng PR (USER chạy trên lab VM):**
- `ns=security: 6 label-misses` → `bash scripts/zta-apply-workload-labels.sh --apply`
- `block-latest-tag: 4 violations` → audit 4 image, fix Deployment tương ứng (issue riêng)

### E.2 Falco purge

**Delete:**
- `scripts/zta-deploy-falco.sh`
- `infras/k8s-yaml/falco/` (chỉ có `values.yaml`)

**Edit:**
- `09-verify-zta.sh` — xoá Test 4m
- `doc/31-falco-runtime-detection.md` — thêm header "DEPRECATED — replaced by Tetragon (`doc/14-tetragon-runtime.md`). Kept for thesis history."
- `doc/incident-falco-tetragon-ram-overcommit.md` — note xác định Falco đã bỏ
- `doc/32-deploy-script-troubleshooting.md` — gỡ Falco out of troubleshooting matrix

---

## F. Verified (không xóa nhầm)

| Path | Status | Lý do giữ |
|---|---|---|
| `frontend/` (root) | KEEP | USER đang code tiếp |
| `src/{candidate,communication,hiring,identity,job,storage,workspace}_service/` | KEEP | 7 Laravel microservices, `03-deploy-microservices.sh` build |
| `DB/*.sql` | KEEP | `05-seed-databases.sh:80,85-91` đọc trực tiếp |
| `k8s-management/charts/laravel-app/` | KEEP | `helmfile.yaml` + `03-deploy-microservices.sh` dùng cho 7 microservices |
| `k8s-management/cilium/cilium-values.yaml` | KEEP | `01-setup-cluster.sh:127` |
| `k8s-management/operational/`, `values/` (laravel ones) | KEEP | helm values |
| `documents/` (45 MB LaTeX) | KEEP | Thesis nguồn |
| `evidence/` | KEEP | Đã `.gitignore` cho `baseline-*/`, `audit-*/` |
| `postman/` | KEEP | Không trong scope cleanup, để USER quyết sau |

---

**Total deletion estimate (rough):** ~ 3.0 MB + ~30 file ngoài root → repo gọn hơn nhiều, navigate dễ hơn, không còn rác lẩn trong microservice pile.
