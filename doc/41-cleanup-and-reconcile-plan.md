# 41 — Kế hoạch Dọn dẹp Repo + Đối chiếu Knowledge-Base ↔ Hệ thống thực tế

> Tạo: 2026-06-03 · Trạng thái: **ĐỀ XUẤT (chờ duyệt)** — chưa thực thi cleanup.
> Gồm 2 phần: **A. Dọn dẹp & đổi tên `doc/` → `knowledge-base/`** (cần duyệt vì
> đụng nhiều file) và **B. Quy trình đối chiếu** bằng `scripts/zta-kb-reconcile.sh`
> (chạy trên máy bạn, read-only, có fallback).

---

## PHẦN A — DỌN DẸP REPO

### Nguyên tắc
- **GIỮ nguyên cấu trúc thư mục lớn** (`src/`, `infras/`, `k8s-management/`,
  `documents/`, `DB/`, `postman/`, `evidence/`, `scripts/`, 2 frontend
  `atd_frontend/` + `rct_frontend/`, `frontend/` nếu còn).
- Chỉ **gom các file lẻ ở ROOT** vào đúng chỗ; xoá rác/nhị phân; đổi `doc/` →
  `knowledge-base/`.
- **KHÔNG đụng pipeline scripts** ở root (`01..11-*.sh`) và `scripts/zta-*.sh`
  đang nằm trong chuỗi `scripts/zta-rebuild.sh`.
- Mọi thao tác xoá/di chuyển làm bằng `git mv` / `git rm` để giữ history.

### A.1 — GIỮ NGUYÊN ở ROOT (pipeline, không động)
```
01-setup-cluster.sh            02-deploy-infrastructure.sh
03-deploy-microservices.sh     04-build-and-push-images.sh
05-seed-databases.sh           07-deploy-monitoring-exporters.sh
08-harden-security.sh          09-verify-zta.sh
10-deploy-tetragon.sh          11-provision-dashboards.sh
README.md
```

### A.2 — XOÁ (nhị phân/backup/log rác — đang bị track trong git)
| File | Lý do |
|---|---|
| `20260522-203841.zip` (~11MB) | Archive tạm, không phải source |
| `doc.zip` | Bản nén của chính `doc/` — thừa |
| `fe-keycloak-login.tar.gz` | Artifact build FE |
| `zta-microseg.zip` | Archive tạm |
| `02-deploy-infrastructure.sh.bak.1778687182` | File `.bak` theo timestamp |
| `03-deploy-microservices.sh.bak.1778686840` | File `.bak` theo timestamp |
| `shudown_result.txt` | Output log (gõ nhầm "shutdown") |

→ Đồng thời bổ sung `.gitignore`: `*.zip`, `*.tar.gz`, `*.bak.*`, `*-result.txt`.

### A.3 — GOM SCRIPT LẺ Ở ROOT → `scripts/…`
Tạo 3 thư mục con dưới `scripts/` (đã có sẵn `scripts/utils/`, `scripts/legacy/`):

**→ `scripts/diagnostics/`** (script chẩn đoán, còn tái dùng):
```
check-auth-flow.sh  check-fe-auth.sh  diagnose-auth.sh  diagnose-auth-v2.sh
diagnose-auth-v3.sh  diagnose-kong-jwt.sh  zta-diag-backend.sh  zta-diag-cnp2.sh
zta-diag-sync.sh  zta-diagnose-startup-stuck.sh  zta-audit-selectors.sh
zta-check-stability.sh  zta-verify-gateway.sh  atd-verify.sh  atd-pages-debug.sh
```

**→ `scripts/legacy/microseg-waves/`** (rollout microseg lịch sử — đã xong):
```
zta-microseg-step1-flow-capture.sh  zta-microseg-wave1-apply.sh
zta-microseg-wave2-apply.sh  zta-microseg-wave3-apply.sh
zta-microseg-wave4-apply.sh  zta-microseg-wave5-apply.sh
zta-prefix-apply.sh  zta-apply-gateway.sh  zta-apply-identity-cnp.sh
```

**→ `scripts/legacy/`** (one-off: vault bootstrap, atd bringup, fix/patch/setup):
```
vault-step1-verify-tetragon.sh  vault-step2-bootstrap-vault.sh
vault-step3-resync-apps.sh  vault-step3a-diagnose-webhook.sh
vault-step3b-cleanup-diagnose.sh  vault-step3c-diagnose-redis.sh
vault-step3d-fix-redis-and-tetragon.sh  vault-step3e-fix-identity-job-drift.sh
atd-bringup.sh  atd-fix-identity-jwt.sh  atd-pages-wait.sh
fix-azp-keycloak.sh  fix-opa-allow-realms.sh  fix-vault-mysql.sh
zta-fix-dbcreds.sh  zta-fix-intra-ns-8000.sh  zta-fix-vault-auth-and-finish-startup.sh
add_mapper.sh  apply-kong-cors.sh  patch_realm.sh  patch_py.py
rebuild-service.sh  setup-auth.sh  setup-keycloak-clients-job7189.sh
kibana-sso-up.sh  tok.sh  zta-elk-toggle.sh
```
> Lưu ý: nếu script nào còn được pipeline/README tham chiếu thì GIỮ ở root —
> phần thực thi sẽ `grep` từng tên trước khi `git mv` (xem A.6).

### A.4 — GOM DOC LẺ Ở ROOT → trong `knowledge-base/`
Các doc này là **tài liệu frontend (ATD/RCT) + API client**, không thuộc KB ZTA;
gom vào thư mục con cho gọn:

**→ `knowledge-base/frontend/`** (UI/UX của atd_frontend + rct_frontend):
```
INDEX.md  START_HERE.txt  QUICK_START.md  COMPLETION_SUMMARY.txt
FILE_CHANGES.md  IMPROVEMENTS_SUMMARY.md  MINIMALISM_REFACTOR_SUMMARY.md
PAGES_IMPROVEMENTS_COMPLETE.md  PREMIUM_DESIGN_UPGRADE.md
README_IMPROVEMENTS.md  TASTE_SKILL_IMPLEMENTATION.md  VISUAL_GUIDE.md
```
**→ `knowledge-base/api/`** (gộp với `api-authentication-guide.md` đã có):
```
API_COMPLETE_REFERENCE.md  API_DEVELOPMENT_GUIDE.md  API_DOCUMENTATION_INDEX.md
API_IMPLEMENTATION_STATUS.md  API_QUICK_REFERENCE.md  API_SUMMARY.txt
```
**→ `knowledge-base/archive/`**:
```
PHASE5D_COMPLETION.txt                    (báo cáo test ZTA phase 5.D)
DANH_SACH_TU_TIENGANH_CANSUAFIXED.md      (glossary VN↔EN cho luận văn)
```

### A.5 — ĐỔI TÊN `doc/` → `knowledge-base/`
```bash
git mv doc knowledge-base
```
**Phải cập nhật tham chiếu `doc/`** trong **58 file** (đã đếm) ngoài thư mục
`doc/` + `documents/` (README.md, các `*.sh`, `infras/**`, `k8s-management/**`).
Cách an toàn:
```bash
# 1) Xem trước
grep -rIl 'doc/' --include='*.md' --include='*.sh' --include='*.yaml' --include='*.yml' . \
  | grep -vE '/(documents)/'
# 2) Thay (BACKUP/branch trước). Chỉ thay tiền tố 'doc/<NN|chữ>' → 'knowledge-base/'
grep -rIl 'doc/' . | grep -vE '\.git/' \
  | xargs sed -i 's#\bdoc/#knowledge-base/#g'
```
> ⚠️ Cẩn thận false-positive: `sed` trên có thể đụng chuỗi như `…/doc/` trong
> ngữ cảnh khác. Phần thực thi sẽ review từng file qua `git diff` trước khi commit,
> và cập nhật cả các liên kết nội bộ trong chính KB (vd `doc/15-…` → `knowledge-base/15-…`).

### A.6 — Cách thực thi (đề xuất 1 PR, có thể tách nhỏ)
1. Branch `devin/<ts>-repo-cleanup`.
2. `git rm` mục A.2 + cập nhật `.gitignore`.
3. Tạo thư mục con + `git mv` script (A.3) — **grep tham chiếu từng file trước khi mv**.
4. `git mv doc knowledge-base` + `git mv` doc lẻ (A.4) + sed-update tham chiếu (A.5).
5. Cập nhật `README.md` (link `doc/README.md` → `knowledge-base/README.md`).
6. `git diff` review → commit → PR.
> **Chưa làm bước này** cho tới khi bạn duyệt mapping ở trên.

---

## PHẦN B — ĐỐI CHIẾU KNOWLEDGE-BASE ↔ HỆ THỐNG THỰC TẾ

### B.1 — File check
`scripts/zta-kb-reconcile.sh` (~1170 dòng). **Chạy trên máy bạn** (có kubeconfig
trỏ cluster ZTA). **READ-ONLY** — chỉ `kubectl get/describe/exec` đọc, không
apply/patch/delete. Mỗi điều KB khẳng định → script kiểm chứng trên cluster và in
`PASS / FAIL / WARN / SKIP`.

### B.2 — Source-of-truth & DRIFT
Khi 2 chương KB mâu thuẫn, script check theo **`doc/40-snapshot-20260527`** (snapshot
live mới nhất) và in mục **DRIFT WATCH** để bạn quyết sửa chương nào. Các drift đã
phát hiện sẵn (script in lại ở cuối, không cần cluster vẫn thấy):
| # | Lệch | Chi tiết |
|---|---|---|
| 1 | ES version | doc/05 ghi *8.x*, snapshot 40 ghi *7.17.18* |
| 2 | Encryption | doc/04 ghi *mTLS/WireGuard ĐÃ BẬT*, snapshot 40 ghi *mesh-auth DISABLED* |
| 3 | Hạ tầng | doc/06 còn nói *Kind, ~12GB*; snapshot 40 nói *multi-VM kubeadm, 32GB* |
| 4 | Cluster type | doc/00 + doc/08 còn vẽ *Kind 1CP+3W*; thực tế *kubeadm srv01..05* |
| 5 | Frontend | port-mapping doc liệt kê ns `frontend`; doc/19 nói *FE đã tách khỏi cluster* |

### B.3 — Fallback (theo yêu cầu)
- Không dùng `set -e`. Mỗi **section chạy trong subshell + `timeout`**; lỗi/hang 1
  phần → log `WARN` rồi **chạy tiếp section sau**, không bao giờ chết giữa chừng.
- `kubectl` luôn bọc `timeout` (mặc định 15s, exec 20s) → không treo vô hạn.
- Check cần `kubectl exec` (Vault status, MySQL `SHOW DATABASES`, ES indices,
  Keycloak realm…) sẽ `SKIP`/`WARN` nếu thiếu quyền, không làm hỏng phần khác.

### B.4 — Cách chạy
```bash
bash scripts/zta-kb-reconcile.sh                 # full
bash scripts/zta-kb-reconcile.sh --list          # liệt kê 23 section
bash scripts/zta-kb-reconcile.sh --only 7,11     # chỉ Cilium + Observability
bash scripts/zta-kb-reconcile.sh --no-exec       # bỏ check cần exec
bash scripts/zta-kb-reconcile.sh --static        # chỉ check tĩnh (không cần cluster)
# override khi cluster của bạn khác:
KCTX=my-ctx K_TIMEOUT=25 EXPECT_NODES=4 bash scripts/zta-kb-reconcile.sh
```
Kết quả lưu `evidence/kb-reconcile-<timestamp>.log`. Exit: `0`=không FAIL,
`1`=có FAIL, `2`=không tới được cluster.

### B.5 — 23 section đối chiếu
| # | Section | Đối chiếu claim KB |
|---|---|---|
| 0 | Preflight | K8s 1.30, 4 node Ready, Cilium 1.19, nodeIP CGNAT (Tailscale) |
| 1 | Namespaces | core/infra/ZTA add-on ns; cảnh báo ns `frontend` |
| 2 | 7 microservices | deployment ready, svc port 80, pod 4-container (app/vault-agent/env-loader/env-watcher) |
| 3 | Redis cache | `<svc>-redis` mỗi service (doc/19) |
| 4 | Identity | Keycloak dual-realm, Vault dual + unseal, SPIRE server/agent, PDP `PDP_CVE_INPUT=false` |
| 5 | ServiceAccount | 7 SA 1:1 (doc/03) |
| 6 | Kong + JWT | DB-less, plugin jwt RS256, NodePort 30000, đối chiếu `kong.yml` |
| 7 | Cilium microseg | ≥11 CNP apps, default-deny 4/7 ns, 5 L7 CNP, CCNP/CIDRGroup threat-intel |
| 8 | Encryption | `cilium-config` mesh-auth/wireguard (in DRIFT vs doc/04) |
| 9 | Data layer | MySQL 3306, **7 DB `job7189_*_db`**, Kafka, MinIO |
| 10 | Vault JIT | secrets trên tmpfs, `.env` trong pod, active leases |
| 11 | Observability | ES (in DRIFT version), Filebeat DS, Kibana/Prom/Grafana/KSM/node-exporter, Hubble, ES indices, PrometheusRule |
| 12 | Label schema | đủ 6 `zta.job7189/*` trên 26 workload (doc/19) |
| 13 | Gatekeeper | ConstraintTemplate, `image-digest-required`, `block-latest-tag`, `zta-labels-required` |
| 14 | Image provenance | cosign-system, 3 ClusterImagePolicy, secret `zta-cosign-public-key` |
| 15 | Tetragon | DaemonSet + TracingPolicy `block-suspicious-exec` |
| 16 | Threat-intel | CronJob, CoreDNS sinkhole CM, forward 1.1.1.1/8.8.8.8, security-cdm egress |
| 17 | Trivy | DEFERRED (đối chiếu: trivy-system rỗng = khớp; có pod = drift) |
| 18 | PDP adaptive | `score-bucket` label & `block-low-trust-to-vault` (snapshot: PENDING) |
| 19 | Resource budget | node allocatable, tổng pod (in DRIFT Kind→multi-VM) |
| 20 | Ingress | ingress-nginx NodePort 30003/30001, host `*.job7189.*` |
| 21 | STATIC refs | file KB trỏ tới có thật trong repo không (chạy được cả khi offline) |
| 22 | KB consistency | đếm 32 chương + 3 incident, liệt kê drift doc-vs-doc |

### B.6 — Sau khi chạy
1. Đọc mục **TỔNG KẾT** + **DANH SÁCH FAIL/WARN** + **DRIFT WATCH** ở cuối log.
2. Với mỗi FAIL/DRIFT: quyết định **sửa KB cho khớp cluster** hay **sửa cluster cho
   khớp KB**, rồi cập nhật chương tương ứng.
3. Chạy lại tới khi **0 FAIL** → đó là mốc "KB = thực tế" để chuẩn hoá về sau.
