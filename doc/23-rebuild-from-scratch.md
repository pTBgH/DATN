# Rebuild From Scratch (ZTA Phase 4 stack)

> Audience: operator. Mục tiêu: từ máy đã từng deploy → wipe sạch → fresh
> deploy với toàn bộ ZTA enforcement (PR #7 → PR #10) chạy trong **một
> lệnh**.

---

## TL;DR

```bash
# 1) Tắt và wipe sạch (idempotent)
bash scripts/zta-teardown.sh --yes

# 2) Rebuild + apply ZTA enforcement
bash scripts/zta-rebuild.sh --yes
```

Hoặc qua menu:
```bash
bash deploy-all.sh
# → option 7 (teardown) → option 8 (rebuild)
```

Kết quả mong đợi (cluster trắng → cluster Phase 4 sẵn sàng): **~25-35 phút**
trên máy 32GB RAM / 8 vCPU. Phase nào lâu nhất xem `STEP_TIMES` log của từng
script con.

---

## 1. Teardown (`scripts/zta-teardown.sh`)

Mục đích: dọn sạch để rebuild không kế thừa state cũ.

| Bước | Hành động | Có thể tắt |
|----|----------|----------|
| 1 | `kind delete cluster job7189` | (không) |
| 2 | `docker rmi` images project (job7189/datn/*-service) | `--keep-images` |
| 3 | Xoá `/mnt/data/job7189`, `/var/lib/job7189-{mysql,vault,kafka,elasticsearch}` | `--keep-volumes` |
| 4 | Dọn file evidence/ cũ hơn 7 ngày | (luôn chạy, không xoá folder) |

Flags:
- `--yes` — bỏ confirm prompt (phục vụ CI / batch)
- `--keep-images` — giữ docker images đã build (rebuild nhanh hơn ~5 phút)
- `--keep-volumes` — giữ data Vault/MySQL (rebuild dùng lại data cũ — KHÔNG khuyến nghị nếu thay schema)

---

## 2. Rebuild (`scripts/zta-rebuild.sh`)

Sau teardown (hoặc trên máy chưa có cluster), script này dựng lại toàn bộ
6 phase tuần tự. Mỗi phase fail → script dừng, in tổng thời gian, không
silently tiếp tục.

| Phase | Script gọi | Thời gian (~) | Output chính |
|-------|-----------|----------------|--------------|
| `cluster` | `01-setup-cluster.sh` | 4-6 phút | Kind + Cilium 1.19 + cert-manager + ingress-nginx |
| `infra` | `02-deploy-infrastructure.sh` (`ZTA_ENABLE_POLICIES=0`) | 8-12 phút | Vault + MySQL + Keycloak + Kafka + Kong + ELK |
| `apps` | `03-deploy-microservices.sh` | 6-10 phút | 8 microservices + Redis sidecars |
| `harden` | `08-harden-security.sh` | 1-2 phút | Cilium mesh-auth + WireGuard ENABLED |
| `zta` | `apply-zta-namespace-policies.sh` × 7 ns + `zta-apply-workload-labels.sh --apply` + `zta-apply-l7-policies.sh --apply` | 1-2 phút | 60+ CNPs (per-ns default-deny + L7) |
| `verify` | `09-verify-zta.sh` + `zta-observability-baseline.sh` | 5-8 phút | evidence/ + baseline-* |

> Lý do `ZTA_ENABLE_POLICIES=0` ở phase `infra`: step 9c của
> `02-deploy-infrastructure.sh` chỉ apply legacy 5 monolithic CNPs cho
> `job7189-apps` (PR cũ). Phase `zta` của rebuild script áp PR #8/#9/#10
> đầy đủ cho 7 ns — thay thế hoàn toàn step 9c.

Flags:
- `--yes` — bỏ confirm prompt
- `--skip-cluster` — cluster đã có (sau khi 01 chạy), chỉ làm 02 → verify
- `--skip-frontend` — bỏ build FE images (test backend nhanh hơn)
- `--until=phase` — dừng sau 1 phase. Giá trị: `cluster | infra | apps | harden | zta | verify`

Ví dụ chạy phase by phase để debug:
```bash
bash scripts/zta-rebuild.sh --until=cluster --yes
# debug cluster ở đây nếu cần
bash scripts/zta-rebuild.sh --skip-cluster --until=infra --yes
# vv
```

---

## 3. Verify sau rebuild

`scripts/zta-rebuild.sh` tự gọi `09-verify-zta.sh` ở phase cuối. Output kỳ
vọng (cluster healthy):

```
   ✅ PASS: 35-40
   ❌ FAIL: 0-2  (Vault sealed initial là expected; chạy unseal)
   ⚠️ WARN: 3-5
```

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
| Phase `infra` fail (Vault không init) | `kubectl logs -n vault vault-0` debug, sau đó: `bash scripts/zta-rebuild.sh --skip-cluster --yes` |
| Phase `apps` fail (image pull / migration) | Check `kubectl get pod -n job7189-apps`. Sau khi fix: `bash 03-deploy-microservices.sh` lại, rồi `bash scripts/zta-rebuild.sh --skip-cluster --until=zta --yes` (chạy harden + zta + verify) |
| Phase `harden` fail (Cilium agent crash) | Rất hiếm. Reboot Cilium DS: `kubectl -n kube-system rollout restart ds/cilium` |
| Phase `zta` fail (CNP VALID=False) | `kubectl describe cnp <name> -n <ns>` xem error message; thường do label workload chưa apply (PR #9). Re-run `bash scripts/zta-apply-workload-labels.sh --apply` |

---

## 5. Tài nguyên cluster sau rebuild

```text
namespaces:
  - job7189-apps        (12+ microservice pods + 6 Redis)
  - data                (mysql, kafka)
  - vault               (vault-0, vault-dev, agent-injector)
  - security            (keycloak, oauth2-proxy)
  - gateway             (kong-gateway)
  - management          (phpmyadmin, kafbat)
  - monitoring          (prometheus, grafana, kibana, elasticsearch, hubble-ui, exporters)

CNPs (~60):
  - default-deny-{ns} × 7
  - allow-dns-egress-{ns} × 7
  - allow-prometheus-scrape-{ns} × 7
  - allow-{flow-specific} × 30+  (PR #8)
  - l7-{vault-api,keycloak-oidc,keycloak-jwks,kong-admin,prom-*}  (PR #10)

Cilium config keys:
  - mesh-auth-enabled: true
  - enable-wireguard:  true
  - enable-l7-proxy:   true
```

---

## 6. Khi nào cần rebuild?

- Sau khi sửa `01-setup-cluster.sh` hoặc `kind` config (network mode, port mappings).
- Sau khi update Cilium version (cilium-config bị reset, mesh-auth status có thể inconsistent).
- Khi muốn reset Vault data (drop secrets / leases).
- Cuối mỗi sprint (clean baseline để so sánh evidence).

KHÔNG cần rebuild nếu chỉ:
- Đổi 1 CNP — `kubectl apply -f <file>`
- Re-deploy 1 microservice — `bash rebuild-service.sh <name>`
- Update label — `bash scripts/zta-apply-workload-labels.sh --apply`

---

## 7. Bảo trì script

Khi thêm phase mới (ví dụ PR #11 — Adaptive security loop):
1. Thêm script `scripts/zta-apply-adaptive.sh` (hoặc tương tự).
2. Edit `scripts/zta-rebuild.sh` phase `zta` thêm dòng `bash $ADAPTIVE_APPLY --apply`.
3. Update bảng phase ở mục #2 trong file này.
4. Tăng số test trong checklist sau rebuild ở mục #3.

Khi đổi cấu trúc namespace, nhớ update:
- `scripts/zta-teardown.sh` HOST_PATHS array
- `scripts/zta-rebuild.sh` phase `zta` ns loop
- Bảng phase mục #5 ở trên
