# Rebuild From Scratch (ZTA Phase 4 stack)

> Audience: operator. Mục tiêu: từ máy đã từng deploy → wipe sạch → fresh
> deploy với toàn bộ ZTA enforcement (PR #7 → PR #22) chạy trong **một
> lệnh**.

---

## TL;DR

```bash
# 1) Tắt và wipe sạch (idempotent)
bash scripts/zta-teardown.sh --yes

# 2) Rebuild + apply ZTA enforcement (base only — không kèm Tetragon/SPIRE/Cosign/Hubble heavy)
bash scripts/zta-rebuild.sh --yes

# 2b) HOẶC rebuild kèm tất cả module nặng (Tetragon, Cosign policy-controller, SPIRE, SPIRE demo, Hubble export)
bash scripts/zta-rebuild.sh --yes --full-enforcement
```

Hoặc qua menu:
```bash
bash deploy-all.sh
# → option 7 (teardown) → option 8 (rebuild base, không có --full-enforcement)
```

Kết quả mong đợi (cluster trắng → cluster Phase 4 sẵn sàng):
- **Base rebuild** (`--yes`): ~25-35 phút, cluster ZTA Advanced+, chưa có Tetragon/SPIRE/Cosign/Hubble.
- **Full-enforcement rebuild** (`--yes --full-enforcement`): ~45-60 phút, cluster ZTA Optimal, đã có cả 4 module trên.

---

## 1. Teardown (`scripts/zta-teardown.sh`)

Mục đích: dọn sạch để rebuild không kế thừa state cũ.

| Bước | Hành động | Có thể tắt |
|----|----------|----------|
| 1 | `kind delete cluster job7189` | (không) |
| 2 | `docker rmi` images project (job7189/datn/*-service) | `--keep-images` |
| 3 | Xoá `/mnt/data/job7189`, `/var/lib/job7189-{mysql,vault,kafka,elasticsearch}` | `--keep-volumes` |
| 4 | Dọn file `evidence/` cũ hơn 7 ngày | (luôn chạy, không xoá folder) |

Flags:
- `--yes` — bỏ confirm prompt (phục vụ CI / batch)
- `--keep-images` — giữ docker images đã build (rebuild nhanh hơn ~5 phút)
- `--keep-volumes` — giữ data Vault/MySQL (rebuild dùng lại data cũ — KHÔNG khuyến nghị nếu thay schema)

---

## 2. Rebuild (`scripts/zta-rebuild.sh`)

Sau teardown (hoặc trên máy chưa có cluster), script này dựng lại toàn bộ
phase tuần tự. Mỗi phase fail → script dừng, in tổng thời gian, không
silently tiếp tục.

### 2.1 Phase chính (luôn chạy)

| # | Phase | Script gọi | Thời gian (~) | Output chính |
|---|-------|-----------|----------------|--------------|
| 1 | `cluster` | `01-setup-cluster.sh` | 4-6 phút | Kind 4-node + Cilium 1.19 + cert-manager + ingress-nginx |
| 2 | `infra` | `02-deploy-infrastructure.sh` (`ZTA_ENABLE_POLICIES=0`) | 8-12 phút | Vault + MySQL + Keycloak + Kafka + Kong + ELK |
| 3 | `apps` | `03-deploy-microservices.sh` | 6-10 phút | 8 microservices + Redis sidecars |
| 4 | `exporters` | `07-deploy-monitoring-exporters.sh` | 1-2 phút | node-exporter + kube-state-metrics (cần cho Test 6 + L7 prom-scrape) |
| 5 | `harden` | `08-harden-security.sh` | 1-2 phút | Cilium mesh-auth + WireGuard ENABLED |
| 6 | `zta` | 6 sub-step (xem 2.2) | 2-3 phút | 60+ CNPs + workload labels + Gatekeeper + Tetragon TracingPolicy + PDP |
| 7 | `verify` | `09-verify-zta.sh` + `zta-observability-baseline.sh` | 5-8 phút | `evidence/` + `baseline-*` snapshot |

> Lý do `ZTA_ENABLE_POLICIES=0` ở phase `infra`: step 9c của
> `02-deploy-infrastructure.sh` chỉ apply legacy 5 monolithic CNPs cho
> `job7189-apps` (PR cũ). Phase `zta` của rebuild script áp PR #8/#9/#10
> đầy đủ cho 7 ns — thay thế hoàn toàn step 9c.

### 2.2 Sub-step bên trong phase `zta`

Phase này áp tất cả enforcement layer mà script khác không tự động làm:

| Sub-step | File / script | Mục đích |
|----------|---------------|----------|
| 5a (i)   | `infras/k8s-yaml/20-security-policies.yaml` | default-deny `data` + `job7189-apps` + identity→mysql + ingress→kong (foundational, KHÔNG được bất kỳ deploy script nào auto-apply) |
| 5a (ii)  | `infras/k8s-yaml/cilium-policies/apply-zta-microsegmentation.sh` | 5 CNP cho `job7189-apps` (allow-egress-dns/data + ingress-kong + internal-api) |
| 5a (iii) | `infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh` | per-ns CNP cho 6 ns non-app (`monitoring`/`data`/`vault`/`security`/`gateway`/`management`) |
| 5b       | `scripts/zta-apply-workload-labels.sh --apply` | 6 ZTA criteria labels cho deployment + live pod (PR #9) |
| 5c       | `scripts/zta-apply-l7-policies.sh --apply` | 5 L7 CNP (vault-api / keycloak-oidc / keycloak-jwks / kong-admin / prom-scrape) (PR #10) |
| 5d       | `scripts/zta-deploy-gatekeeper.sh` | OPA Gatekeeper audit-only (PR #12) |
| 5e       | `scripts/zta-apply-tracing-policies.sh --apply` | Tetragon TracingPolicies cho T1 ns (PR #12, **chỉ chạy nếu** `tracingpoliciesnamespaced.cilium.io` CRD đã có — tức là sau khi `10-deploy-tetragon.sh` chạy) |
| 5f       | `scripts/zta-deploy-pdp.sh` | PDP Controller — đóng adaptive loop (PR #15) |

### 2.3 Phase optional (`--full-enforcement`)

Chạy giữa phase `zta` và phase `verify`. **Sequential, fail-fast** để tránh
cascading API timeouts trên cluster RAM-constrained:

| # | Module | Script | Thời gian (~) | Ghi chú |
|---|--------|--------|----------------|---------|
| 1 | `tetragon` | `10-deploy-tetragon.sh` | 3-5 phút | eBPF runtime tracer; cần CRD `tracingpoliciesnamespaced.cilium.io` cho 5e ở trên (5e sẽ skip nếu CRD chưa có) |
| 2 | `cosign-key` | `scripts/zta-cosign-keygen.sh` | <30s | Sinh + publish public key vào CM `security/zta-cosign-public-key` |
| 3 | `policy-controller` | `scripts/zta-deploy-policy-controller.sh` | 3-5 phút | sigstore real Cosign verify at admission (PR #19). Pre-flight RAM ≥200Mi/node |
| 4 | `spire` | `scripts/zta-deploy-spire.sh` | 5-10 phút | SPIRE server + agent + controller-manager + 11 ClusterSPIFFEID (PR #17). Pre-flight RAM ≥450Mi/node |
| 5 | `spire-demo` | `scripts/zta-spire-onboard-demo.sh` | 1-2 phút | Demo workload consume SVID qua spiffe-helper (PR #20) |
| 6 | `hubble-export` | `scripts/zta-deploy-hubble-export.sh --enable-cilium-export` | 3-5 phút | Filebeat shipper + cilium hubble-export-file (PR #21). **CHÚ Ý**: rolling-restart cilium DS — script tự revert nếu fail |

> Module nặng được sequential và fail-fast vì khi cluster đã chiếm 9-10Gi
> RAM (full base), apply 4 helm chart song song dễ kéo control-plane vào
> cascade CrashLoop. Pre-flight RAM của từng script bảo vệ thêm một lớp.
>
> Tetragon (`10-deploy-tetragon.sh`) **không** chạy tự động trong phase chính
> dù nó nằm ngoài `--full-enforcement`. Chỉ phase optional gọi nó. Nếu muốn
> chạy Tetragon riêng thì gọi `bash 10-deploy-tetragon.sh` trước rồi
> mới `bash scripts/zta-rebuild.sh --skip-cluster --until=zta --yes` để 5e
> apply được TracingPolicy.

### 2.4 Falco (DEPRECATED — đã gỡ)

Falco runtime detection đã bị gỡ khỏi pipeline ZTA (PR-D cleanup, 2026-05).
Tetragon (xem step `10-tetragon`) phủ toàn bộ runtime use-case mà Falco từng
làm. Xem `doc/31-falco-deprecated.md` + `doc/incident-falco-tetragon-ram-overcommit.md`
cho lý do và evidence.

### 2.5 Flags tổng hợp

| Flag | Tác dụng |
|------|----------|
| `--yes` / `-y` | Bỏ confirm prompt |
| `--skip-cluster` | Cluster đã có (sau khi 01 chạy), chỉ làm 02 → verify |
| `--skip-frontend` | Bỏ build FE images (test backend nhanh hơn) — set `DEPLOY_SKIP_FRONTEND=1` cho phase `apps` |
| `--full-enforcement` | Bật phase optional (Tetragon + Cosign + SPIRE + Hubble) |
| `--strict-apps` | KHÔNG tolerate phase `apps` non-zero exit (mặc định: nếu `03-deploy` exit non-zero, đợi thêm 180s rồi check `kubectl wait` cho pods Ready) |
| `--from=phase` | Resume từ 1 phase cụ thể (skip các phase trước) — giá trị: `cluster \| infra \| apps \| exporters \| harden \| zta \| verify` |
| `--until=phase` | Dừng sau 1 phase. Cùng tập giá trị với `--from` |

Ví dụ chạy phase by phase để debug:
```bash
bash scripts/zta-rebuild.sh --until=cluster --yes
# debug cluster ở đây nếu cần
bash scripts/zta-rebuild.sh --skip-cluster --until=infra --yes
bash scripts/zta-rebuild.sh --from=apps --until=zta --yes
bash scripts/zta-rebuild.sh --from=verify --yes
```

---

## 3. Verify sau rebuild

`scripts/zta-rebuild.sh` tự gọi `09-verify-zta.sh` ở phase cuối. Output kỳ
vọng (cluster healthy):

```
   ✅ PASS: 35-50  (50+ nếu --full-enforcement)
   ❌ FAIL: 0-2   (Vault sealed initial là expected; chạy unseal)
   ⚠  WARN: 3-5
```

Test ID coverage trong `09-verify-zta.sh`:

| Test | Chủ đề | Doc |
|------|--------|-----|
| 1 | Pod health all ns | — |
| 2 | Vault dynamic credentials | `03` |
| 3 | Kong JWT enforcement | `03`, `04` |
| 4 | Cilium microsegmentation (default-deny) | `04`, `08` |
| 4b | Default-deny coverage 7 ns (PR #8) | `18` |
| 4c | Audit findings F-1/F-2/F-4 (PR #8) | `22` |
| 4d | Workload labeling 6 criteria (PR #9) | `19` |
| 4e | L7 enforcement coverage (PR #10) | `20` |
| 4f | Adaptive security loop (PR #12) | `24` |
| 4g | PDP Controller (PR #15) | `25` |
| 4h | Image provenance Cosign + Gatekeeper (PR #16) | `26` |
| 4i | SPIRE workload attestation (PR #17) | `27` |
| 4j | sigstore policy-controller real Cosign verify (PR #19) | `28` |
| 4k | SPIRE workload integration consume SVID (PR #20) | `29` |
| 4l | Hubble flow → ES sink (PR #21) | `30` |
| ~~4m~~ | ~~Falco runtime detection (PR #22)~~ — **REMOVED** PR-D, xem `31-falco-deprecated.md` | `31` |
| 5 | Encryption mTLS + WireGuard | `15` |
| 6 | Observability stack | `05` |
| 7 | Namespace tier isolation | `02`, `18` |

Nếu Vault sealed sau rebuild:
```bash
bash infras/k8s-yaml/vault-scripts/restart_unseal.sh
# rồi chạy lại verify
bash 09-verify-zta.sh
```

Output baseline (Hubble flows) ở `evidence/baseline-<timestamp>/SUMMARY.md`:
- Forwarded: ~3000+ (apps cross-ns đến data/security/vault)
- Dropped: ~500-1000 (mọi flow ngoài allow-list)
- L7 flows: > 0 (sau khi traffic đầu tiên qua Vault/Keycloak/Kong)

---

## 4. Recovery khi rebuild fail giữa chừng

| Lỗi | Hành động |
|-----|-----------|
| Phase `cluster` fail (kind create timeout) | `bash scripts/zta-teardown.sh --yes` rồi rebuild lại |
| Phase `infra` fail (Vault không init) | `kubectl logs -n vault vault-0` debug, sau đó: `bash scripts/zta-rebuild.sh --skip-cluster --from=infra --yes` |
| Phase `apps` timeout nhưng pods eventually Ready | Mặc định OK — script tolerate. Nếu muốn strict: `--strict-apps` |
| Phase `apps` thực sự fail | `kubectl get pod -n job7189-apps`, fix image, sau đó: `bash scripts/zta-rebuild.sh --from=apps --yes` |
| Phase `harden` fail (Cilium agent crash) | `kubectl -n kube-system rollout restart ds/cilium`, sau đó: `bash scripts/zta-rebuild.sh --from=harden --yes` |
| Phase `zta` fail (CNP VALID=False) | `kubectl describe cnp <name> -n <ns>` xem error; thường do label workload chưa apply (PR #9). Re-run: `bash scripts/zta-apply-workload-labels.sh --apply` |
| Optional phase `spire` fail (helm timeout / pre-upgrade hook) | Xem `32-deploy-script-troubleshooting.md` § SPIRE recovery — tóm tắt: `bash scripts/zta-deploy-spire.sh --reset` |
| Optional phase `policy-controller` fail (`namespaceSelector` SSA conflict) | Xem `32-deploy-script-troubleshooting.md` § policy-controller recovery — tóm tắt: `bash scripts/zta-deploy-policy-controller.sh --reset` |
| Phase optional fail vì RAM | `bash scripts/free-ram-for-tetragon.sh`, sau đó re-run module fail (script idempotent) |

---

## 5. Tài nguyên cluster sau rebuild

```text
namespaces (base):
  - job7189-apps        (12+ microservice pods + 6 Redis)
  - data                (mysql, kafka)
  - vault               (vault-0, vault-dev, agent-injector)
  - security            (keycloak, oauth2-proxy, zta-pdp)
  - gateway             (kong-gateway)
  - management          (phpmyadmin, kafbat)
  - monitoring          (prometheus, grafana, kibana, elasticsearch=es-0, hubble-ui, exporters)
  - gatekeeper-system   (gatekeeper audit + controller-manager)

namespaces (--full-enforcement adds):
  - kube-system (tetragon DS, cilium hubble-export-file)
  - cosign-system (policy-controller-webhook)
  - spire (spire-server-0 + spire-agent DS + spiffe-csi-driver DS)

CNPs (~60-70):
  - default-deny-{ns} × 7
  - allow-dns-egress-{ns} × 7
  - allow-prometheus-scrape-{ns} × 7
  - allow-{flow-specific} × 30+  (PR #8)
  - l7-{vault-api,keycloak-oidc,keycloak-jwks,kong-admin,prom-*}  (PR #10)

Cilium config keys (sau --full-enforcement):
  - mesh-auth-enabled: true
  - enable-wireguard:  true
  - enable-l7-proxy:   true
  - hubble-export-file-path: /var/run/cilium/hubble/events.log
  - hubble-export-file-max-size-mb: 50
  - hubble-export-file-max-backups: 5
```

Cluster RAM ổn định sau full rebuild: ~10-11 Gi / 12 Gi total. Free
≤1.5Gi. Trước khi deploy thêm Falco hoặc thử nghiệm chart mới, **luôn**
chạy `bash scripts/free-ram-for-tetragon.sh` để giải phóng UI 600-800Mi.

---

## 6. Khi nào cần rebuild?

- Sau khi sửa `01-setup-cluster.sh` hoặc `kind` config (network mode, port mappings).
- Sau khi update Cilium version (cilium-config bị reset, mesh-auth status có thể inconsistent).
- Khi muốn reset Vault data (drop secrets / leases).
- Khi cluster đã accumulate orphan pod / PVC / webhook configuration không xoá được bằng script `--reset`.
- Cuối mỗi sprint (clean baseline để so sánh evidence).

KHÔNG cần rebuild nếu chỉ:
- Đổi 1 CNP — `kubectl apply -f <file>`
- Re-deploy 1 microservice — `bash rebuild-service.sh <name>`
- Update label — `bash scripts/zta-apply-workload-labels.sh --apply`
- Re-install 1 trong 4 module nặng — script tương ứng tự cleanup-on-fail + có flag `--reset`/`--uninstall`.

---

## 7. Bảo trì script

Khi thêm phase mới (ví dụ PR #N — tính năng mới):
1. Thêm script `scripts/zta-deploy-<feature>.sh`.
2. Edit `scripts/zta-rebuild.sh`:
   - Nếu là module nhẹ (chạy mỗi rebuild): thêm vào phase `zta` (sub-step 5x).
   - Nếu là module nặng (>500Mi RAM, >3 phút deploy): thêm vào block `--full-enforcement`.
3. Thêm Test 4x tương ứng vào `09-verify-zta.sh` + thêm row vào bảng test mục #3 ở trên.
4. Update bảng phase mục #2.

Khi đổi cấu trúc namespace, nhớ update:
- `scripts/zta-teardown.sh` HOST_PATHS array
- `scripts/zta-rebuild.sh` phase `zta` ns loop (`for ns in monitoring data vault security gateway management; do`)
- Bảng phase mục #5 ở trên
- `infras/k8s-yaml/cilium-policies/namespaces/` (thêm file `99-<ns>.yaml`)

Khi thêm helm-based module:
- Dùng `--cleanup-on-fail` cho `helm upgrade --install`.
- Source `scripts/utils/zta-common.sh` để dùng `require_node_ram_mi` pre-flight.
- Implement `--uninstall` path force-delete pod + PVC + cluster-scoped resources (webhook configs, CRDs do chart manage).
- Document trong `32-deploy-script-troubleshooting.md`.
