# Architecture Layers — Khung ZTA 5 Lop

> **Cảnh báo drift:** file này có nguồn gốc trước snapshot 2026-06-20. Trạng thái
> cluster chuẩn mới nhất xem `00-SYSTEM-SNAPSHOT.md`; các dòng cũ về Tetragon/mTLS
> đã được reconcile dưới đây.

Anh xa tu khung 5 lop ZTA (chapter2) sang code thuc te.
Cap nhat: 2026-04-24 (sau script 01-09)

## Tong quan

```
Lop 1: Dinh danh da thuc the (Identity)
Lop 2: Danh gia tu the & Tinh bao (Posture & Threat Intel)
Lop 3: Thuc thi chinh sach da tang (Multi-layer Enforcement)
Lop 4: Quan tri bi mat dong (Dynamic Secrets)
Lop 5: Quan sat & Phan tich hanh vi (Observability)
```

## Anh xa NIST → CNCF → Code

| Thanh phan NIST | CNCF Tool | File Code | Trang thai |
|-----------------|-----------|-----------|------------|
| PE (Policy Engine) | OPA/Rego + Keycloak | `infras/kong/kong.yml` (JWT rules) | ⚠️ Partial — OPA chua deploy rieng, logic tuong duong qua Kong+Cilium |
| PA (Policy Admin) | HashiCorp Vault | `infras/k8s-yaml/11-vault.yaml` | ✅ Deployed |
| PEP North-South | Kong Gateway | `infras/k8s-yaml/04-kong-dbless.yaml`, `infras/kong/kong.yml` | ✅ Deployed + JWT verified (401 test) |
| PEP East-West | Cilium eBPF | `infras/k8s-yaml/cilium-policies/*` | ✅ 6 policies, hook script 02 Step 9c |
| PEP Runtime | Tetragon | `knowledge-base/14-tetragon-runtime.md` | ✅ v1.7.0 DS 3/3; `Sigkill` enforce + `Post` audit ở 4 ns |
| Data Source (User ID) | Keycloak | `infras/k8s-yaml/02-keycloak.yaml`, `infras/keycloak/` | ✅ Deployed |
| Data Source (Workload ID) | SPIFFE/SPIRE (Cilium mesh-auth) | `08-harden-security.sh` | ✅ DA KICH HOAT |
| Data Source (Observability) | EFK + Prometheus + Grafana | Scripts 02 (9a+9b) + 07 | ✅ Full stack deployed |

## Chi tiet tung lop

### Lop 1: Dinh danh da thuc the
- **User Identity**: Keycloak OIDC → JWT (RS256)
  - Dual-Realm: `7189_internal` (admin) + `job7189` (end-user)
  - File: `infras/keycloak/realm-infra.json`, `infras/keycloak/realms/realm-job7189.json`
- **Workload Identity**: Cilium mesh-auth SPIFFE SVID
  - Moi pod duoc cap X.509 cert tu dong
  - Format: `spiffe://job7189.local/ns/job7189-apps/sa/<service-name>`
  - Trang thai: ✅ DA KICH HOAT (script 08 Phase 1)
- Xem chi tiet: `knowledge-base/15-encryption-mtls-spiffe.md`

### Lop 2: Danh gia tu the
- **Workload Posture**: Trivy Operator scan tu dong (deployed ns `security-cdm`)
- **Device Posture**: ❌ Chua co MDM/EDR (thesis ghi ro "Initial")
- **Threat Intel**: ✅ Threat-intel CronJob (FireHOL/URLhaus) deployed ns `security-cdm`, 1h cadence
- Trang thai: **Initial** theo CISA ZTMM

### Lop 3: Thuc thi chinh sach
- **Bien (N-S)**: Kong JWT plugin tren tung route
  - File: `infras/kong/kong.yml`
  - Test: Request khong JWT → 401 (da verify script 09)
  - Xem chi tiet: `knowledge-base/04-policy-enforcement.md`
- **Mang (E-W)**: Cilium L3/L4/L7
  - 6 CiliumNetworkPolicy trong namespace job7189-apps
  - Default Deny: `00-default-deny.yaml`
  - Allow DNS/Data/Kong/Internal API: 4 allow policies
  - Hook: Script 02 Step 9c (auto-apply)
  - Xem chi tiet: `knowledge-base/04-policy-enforcement.md`
- **Runtime**: Tetragon v1.7.0 đã deploy, enforce `Sigkill` cho `block-suspicious-exec` ở 4 namespace
  - TracingPolicy: chan /bin/sh, curl, wget trong container
  - Xem chi tiet: `knowledge-base/14-tetragon-runtime.md`

### Lop 4: Quan tri bi mat dong
- **Vault Dual Architecture**:
  - `vault-dev` (Transit Auto-Unseal) — RAM-only, mat khi restart
  - `vault-prod` (TLS, PVC 2Gi, Database Engine)
- **JIT Credentials**: TTL 1h, MySQL user random, auto-revoke
- **Vault Agent Injector**: Sidecar inject secrets vao tmpfs
- 7 active leases da verify (script 09 Test 2)
- Xem chi tiet: `knowledge-base/03-identity-layer.md`

### Lop 5: Quan sat
- **Logging**: EFK (Elasticsearch + Filebeat + Kibana)
  - Filebeat filter: 4 namespace (job7189-apps, gateway, security, data)
  - Deploy: Script 02 Step 9a
- **Metrics**: Prometheus + Grafana + node-exporter + kube-state-metrics
  - node-exporter: 4 nodes (DaemonSet, ~32Mi/node)
  - kube-state-metrics: 1 pod (~32Mi)
  - Deploy: Script 02 Step 9b + Script 07
- **Network flow**: Cilium Hubble UI/CLI
  - Hubble post-check: Script 01 Step 5d
  - Evidence: dropped + forwarded flows (script 09)
- **Alerting**: ❌ Alertmanager chua trien khai (du kien)
- Xem chi tiet: `knowledge-base/05-observability-stack.md`

## Ma hoa lien lac

| Lop | Cong nghe | Trang thai |
|-----|-----------|------------|
| L3 (kernel) | Tailscale WireGuard; Cilium WireGuard tắt | ✅ Tailscale DA BAT; Cilium `enable-wireguard=false` |
| L4/L7 (sidecarless) | Cilium Mesh Auth mTLS (SPIFFE) | ✅ DA BAT |
| N-S (API) | Kong HTTPS + JWT RS256 | ✅ DA BAT |

Xem chi tiet: `knowledge-base/15-encryption-mtls-spiffe.md`
