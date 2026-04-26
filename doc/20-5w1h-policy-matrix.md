# 5W1H Policy Matrix (ZTA Step 2.3.4)

> Reference: Đồ án 1, Mục 2.3.4 / 3.4.4 — *Xây dựng ma trận 5W1H cho mọi luồng
> giao tiếp cross-pod, áp dụng selector identity-based (label) + L7 enforcement
> + mTLS-required cho mọi flow chạm dữ liệu nhạy cảm.*

PR #7 đã có baseline (Hubble flows). PR #8 đặt default-deny per ns. PR #9 gắn
6 ZTA label cho mọi workload. PR #10 (file này) trả lời câu hỏi gốc của ZTA:

> *Có quyền truy cập tài nguyên **gì**, từ **ai**, **lúc nào**, **ở đâu**,
> **vì sao**, **bằng cách nào**?*

---

## 1. Khung 5W1H

| Cột | Câu hỏi | Trả lời (ví dụ) | Cilium primitive |
|----|---------|------------------|-----------------|
| **Who** | Source identity | `zta.job7189/role: api`, `team: backend`, `tier: T2` (pod hiring-service) | `fromEndpoints.matchLabels` (identity-based, NOT IP) |
| **What** | Tài nguyên + thao tác | MySQL `data/3306` SELECT — Vault `/v1/database/creds/identity-service` GET | `toPorts.ports`, `rules.http.method`+`path` |
| **When** | Thời điểm | (default: 24/7) — *future PR #11 thêm time-bounded JIT* | annotation `zta.job7189/time-window` (PR #11) |
| **Where** | Cluster boundary | namespace `job7189-apps` → `data` (cross-ns intra-cluster) | `toEndpoints.matchLabels[io.kubernetes.pod.namespace]` |
| **Why** | Business reason | "identity-service cần DB credential JIT từ Vault để phục vụ login" | annotation `zta.job7189/justification` + audit log |
| **How** | Protocol + auth | TCP/8200 + `serviceAccount=identity-service` + mTLS (Cilium mesh-auth) | `authentication.mode: required` |

> **Lưu ý**: Cilium không có "When" native (tới Cilium 1.16). Time-window
> được tracker bằng annotation + Tetragon TracingPolicy (PR #11).

---

## 2. Ma trận flow (Who → Where → What/How)

Hợp nhất từ baseline (`evidence/baseline-*/SUMMARY.md`) + DAAS (PR #8) + label
schema (PR #9). Cột "Why" tóm tắt; chi tiết trong audit log Hubble + Falco
(PR #11).

### 2.1 Luồng vào tier T1 (data, vault, security)

| # | Who (src) | Where → | What/How | Why | L7? | mTLS? | CNP file |
|---|-----------|----------|----------|-----|-----|-------|----------|
| 1 | `role=api,team=backend` (identity/hiring/job/candidate) | `data/mysql:3306` TCP | Cred từ Vault, không hardcoded | App đọc/ghi user/job/cv | — (DB layer) | ✓ | `10-data.yaml` |
| 2 | `role=sso` (keycloak) | `data/mysql:3306` TCP | Static cred (chưa Vault) | Keycloak realm config | — | ✓ | `10-data.yaml` |
| 3 | `role=ui,team=platform` (phpmyadmin) | `data/mysql:3306` TCP | DBA console, qua oauth2-proxy | Quản lý DB | — | ✓ | `10-data.yaml` |
| 4 | `role=api` (mọi backend) | `data/kafka:9092` TCP | Event publish | Audit/notify/stream | — | ✓ | `10-data.yaml` |
| 5 | `role=api,team=backend` (identity-service ServiceAccount) | `vault/vault:8200` TCP | `POST /v1/database/creds/<role>` | Issue JIT DB cred | **L7 — POST /v1/database/creds/* + GET /v1/sys/health** | ✓ | `30-l7-vault-api.yaml` (PR #10) |
| 6 | `role=secret-store,env=prod` (vault-prod) | `vault/vault-dev:8300` TCP | Auto-unseal transit | Cluster boot | — | ✓ | `11-vault.yaml` |
| 7 | `role=proxy,team=security` (oauth2-proxy) | `security/keycloak:8080` TCP | OIDC code exchange | SSO flow | **L7 — GET/POST /realms/zta/protocol/openid-connect/* + GET /realms/zta/.well-known/openid-configuration** | ✓ | `30-l7-keycloak-oidc.yaml` (PR #10) |
| 8 | `role=proxy,team=platform` (kong-gateway) | `security/keycloak:8080` TCP | JWKS fetch (verify JWT) | Kong validate JWT | **L7 — GET /realms/zta/protocol/openid-connect/certs** | ✓ | `30-l7-keycloak-jwks.yaml` (PR #10) |

### 2.2 Luồng vào tier T2 (gateway, monitoring, job7189-apps API)

| # | Who | Where → | What/How | Why | L7? | mTLS? | CNP file |
|---|-----|---------|----------|-----|-----|-------|---------|
| 9 | `entity=ingress-nginx` + `world` | `gateway/kong-gateway:8000,8443` TCP | Public proxy | North-south | — (kong tự enforce JWT) | ✗ (north-south không mTLS internal) | `14-gateway.yaml` |
| 10 | `entity=host,remote-node` | `gateway/kong-gateway:8001` TCP | Admin API | kubectl port-forward, healthcheck | **L7 — GET /status, GET /metrics** | — | `30-l7-kong-admin.yaml` (PR #10) |
| 11 | `role=proxy` (kong) | `job7189-apps/role=api:80` TCP | Reverse proxy | Route public requests | — | ✓ | `14-gateway.yaml` |
| 12 | `role=monitoring,team=platform` (prometheus) | `*/scrape:metrics` TCP | Scrape all pods :metrics | Observability | — | ✓ | per-ns `allow-prometheus-scrape-*` |
| 13 | `role=ui,team=platform` (kibana,grafana) | `monitoring/es:9200`, `monitoring/prometheus:9090` | UI query | Dashboard | — | ✓ | `13-monitoring.yaml` |
| 14 | `role=api,team=backend` | `job7189-apps/role=cache:6379` (intra-ns Redis) | Session/cache | Per-service Redis | — | ✓ | `10-data.yaml::allow-apps-intra-ns-services` |
| 15 | `role=api,team=backend` | `job7189-apps/role=api:80` (intra-ns API) | Service-to-service call | Microservice mesh | (default L4) | ✓ | `10-data.yaml::allow-apps-intra-ns-services` |

### 2.3 Luồng quản trị (T3 admin)

| # | Who | Where → | What/How | Why | L7? | mTLS? | CNP file |
|---|-----|---------|----------|-----|-----|-------|---------|
| 16 | `entity=host` | `*/8001 (kong-admin)`, `vault/8200/sys/*` | Admin operations | Operator hands-on | **L7** | — | `30-l7-*.yaml` (PR #10) |
| 17 | `role=ui,team=data` (kafbat) | `data/kafka:9093` TCP | Kafka admin UI | View topics/consumers | — (Kafka tự auth) | ✓ | `10-data.yaml::allow-kafka-from-kafbat` |

### 2.4 Egress ra Internet

| # | Who | Where → | Why | Phép? |
|---|-----|---------|-----|--------|
| 18 | `*` (all pods) | `world:443/53` | (none — không có service nào cần) | **DENIED** (không có CNP `to-fqdn`) |
| 19 | `tier=T1` | `world:*` | (forbidden by policy) | **DENIED** mạnh hơn — Tetragon TracingPolicy block exec netcat (PR #11) |

> **Tổng cộng**: 17 luồng allow-listed cross-ns + 1 luồng intra-ns wildcard
> (job7189-apps redis/api). Mọi flow khác → default-deny (PR #8).

---

## 3. L7 enforcement (added trong PR #10)

PR #10 thêm **5 CNP L7-aware** cho các endpoint nhạy cảm — mọi route ngoài
allow-list bị Cilium reject ngay tại data-plane (Envoy redirect):

| File | Selector | Allowed methods/paths | Tier |
|------|---------|----------------------|------|
| `30-l7-vault-api.yaml` | `vault/vault` (StatefulSet) | `POST /v1/database/creds/*`, `GET /v1/sys/health`, `GET /v1/sys/seal-status`, `POST /v1/auth/kubernetes/login` | T1 |
| `30-l7-keycloak-oidc.yaml` | `security/keycloak` | `GET/POST /realms/zta/protocol/openid-connect/*`, `GET /realms/zta/.well-known/openid-configuration` | T1 |
| `30-l7-keycloak-jwks.yaml` | `security/keycloak` ← `gateway/kong-gateway` | `GET /realms/zta/protocol/openid-connect/certs` (chỉ JWKS) | T1 |
| `30-l7-kong-admin.yaml` | `gateway/kong-gateway:8001` | `GET /status`, `GET /metrics` (read-only health/metrics) | T2 |
| `30-l7-prom-metrics.yaml` | mọi pod chứa `zta.job7189/role=monitoring` đến mọi pod có port `metrics` | `GET /metrics` (read-only) | T2 |

> **Lý do tách file**: mỗi L7 CNP có scope nhỏ → dễ rollback nếu app phát sinh
> route mới mà chưa update policy. Hubble drops sẽ chỉ rõ
> `Policy denied DROPPED` cho method/path bị reject.

### Cách thêm endpoint mới vào allow-list

```yaml
# Ví dụ: identity-service phát sinh route POST /api/v1/auth/refresh
# Bước 1: edit infras/k8s-yaml/cilium-policies/30-l7-identity.yaml
# Bước 2: thêm vào rules.http:
#   - method: "POST"
#     path: "/api/v1/auth/refresh"
# Bước 3: kubectl apply -f 30-l7-identity.yaml
# Cilium reload Envoy filter trong <2s, không restart pod.
```

---

## 4. mTLS-required (Cilium mesh-auth)

PR #7 đã enable mesh-auth ở mức **cluster** (`mesh-auth-enabled: true` trong
cilium-config). Khi enable, Cilium agent yêu cầu SPIFFE handshake giữa mọi
endpoint trước khi forward L4/L7 traffic — KHÔNG cần per-CNP annotation.
Pod không có Cilium identity hợp lệ (vd attacker chạy raw pod trong cluster)
sẽ bị reject ở data-plane bởi mesh-auth chứ không bởi CNP rule.

> **Trạng thái hiện tại (PR #10)**: KHÔNG đặt `authentication.mode: required`
> trong từng CNP vì cần Cilium ≥1.15 + cấu hình SPIFFE issuer cho schema này
> được validation chấp nhận. mesh-auth global đủ cho mục tiêu Phase 4 hiện
> tại — verify qua Test 5 của `09-verify-zta.sh` (Cilium Mutual Authentication
> ENABLED + WireGuard ENABLED).
>
> **Roadmap**: PR #11 (hoặc later) sẽ thêm per-CNP `authentication.mode:
> required` sau khi xác nhận Cilium version ≥1.15 và SPIFFE issuer trong
> cluster đã sẵn sàng.

---

## 5. Migration: từ `app:` → `zta.job7189/*` selector

PR #8 dùng `app: <name>` cho selector. PR #10 ưu tiên `zta.job7189/role` +
`zta.job7189/tier` (do PR #9 đã gắn). Lý do:

| Cách cũ (PR #8) | Cách mới (PR #10) | Lợi ích |
|----------------|-------------------|---------|
| `app: identity-service` | `zta.job7189/role=api, zta.job7189/team=backend, zta.job7189/tier=T1` | Selector reusable: thêm `payment-service` cùng pattern → policy không phải sửa |
| Per-name allow | Per-role allow | Scale tốt hơn (mỗi role 1 rule, không phải mỗi service) |
| Không phân biệt tier | Tier-aware | T1 mới được L7-deep, T3 chỉ L4 |

> **Backward compat**: PR #10 KHÔNG xoá CNP cũ. Hai loại selector tồn tại
> song song; CNP mới có scope hẹp hơn (label-based). Sau 1 tuần mà
> không có drop sai (verify qua Hubble), PR #11 sẽ retire CNP cũ.

---

## 6. Anti-patterns (KHÔNG làm)

1. **Cho phép `world` egress qua FQDN policy không scope**: `toFQDNs: "*"` =
   open Internet. Mỗi external dest phải allowlist riêng (vd:
   `keycloak.example.com:443`, không phải `*`).
2. **Cho phép selector rỗng** (`fromEndpoints: []`) → match all. Phải luôn
   matchLabels cụ thể.
3. **Spoof identity bằng label**: pod attacker cố gán
   `zta.job7189/role=api`. Không khả thi vì PR #11 sẽ thêm OPA-Gatekeeper
   block tạo pod có ZTA label nếu không có ServiceAccount tương ứng.
4. **Bypass L7 bằng đổi method**: `OPTIONS` thường được allow CORS. PR #10
   chỉ allow `GET/POST/PUT/DELETE` + `OPTIONS` cho route public. Admin route
   chỉ `GET`.
5. **Block mTLS trong CNP nhưng không enable mesh-auth**: dẫn đến mọi flow
   bị deny. Phải verify `mesh-auth-enabled: true` trong cilium-config TRƯỚC
   khi áp `authentication.mode: required`.

---

## 7. Verify (PR #10 testing)

```bash
# 1. Apply L7 policies
kubectl apply -f infras/k8s-yaml/cilium-policies/30-l7-vault-api.yaml \
              -f infras/k8s-yaml/cilium-policies/30-l7-keycloak-oidc.yaml \
              -f infras/k8s-yaml/cilium-policies/30-l7-keycloak-jwks.yaml \
              -f infras/k8s-yaml/cilium-policies/30-l7-kong-admin.yaml \
              -f infras/k8s-yaml/cilium-policies/30-l7-prom-metrics.yaml

# 2. Verify all VALID=True
kubectl get cnp -A | grep -E '30-l7|VALID'

# 3. Test L7 enforcement
# 3a. Vault — GET /v1/sys/health (allowed) → 200/429
kubectl run -it --rm test-vault --image=curlimages/curl --restart=Never \
  --command -- curl -sk -m 5 https://vault.vault.svc.cluster.local:8200/v1/sys/health
# 3b. Vault — POST /v1/sys/seal (NOT allowed) → connection reset / Envoy 403
kubectl run -it --rm test-vault-bad --image=curlimages/curl --restart=Never \
  --command -- curl -sk -m 5 -X POST https://vault.vault.svc.cluster.local:8200/v1/sys/seal

# 4. Verify Hubble shows L7 verdict
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  hubble observe --to-namespace vault --type l7 --last 20 -o compact

# 5. Run full audit
bash 09-verify-zta.sh   # Test 4e (L7 coverage) phải PASS
```

Mong đợi:
- 5/5 CNP L7 VALID=True
- Hubble L7 flows > 0 (PR #7 baseline có L7=0; sau PR #10 phải > 0)
- Allowed paths trả 200/4xx (depending on app); blocked paths trả Envoy 403 hoặc connection reset
