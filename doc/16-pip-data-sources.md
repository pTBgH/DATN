# Policy Information Points (PIP) — Cong cu cung cap du lieu cho PE

## Khai niem

Theo **NIST SP 800-207** (Figure 2), PE (Policy Engine) can **nguon du lieu dau vao**
de tinh toan Trust Score va ra quyet dinh Allow/Deny. NIST goi chung la
"Data Sources". Thuat ngu **PIP (Policy Information Point)** chinh thuc thuoc
**NIST SP 800-162** (ABAC), nhung thesis su dung PIP de chi cung mot khai niem.

**Quan trong:** PIP KHONG phai khai niem ly thuyet — moi PIP la **mot cong cu thuc**
dang chay trong cluster, co pod/service rieng, expose API hoac du lieu cho PE su dung.

> Cong thuc ABAC: `Decision = f(Subject, Resource, Action, Environment)`
> PIP la cac **tools thuc te** cung cap thuoc tinh Subject, Resource, Environment cho PE.

## PIP Tools dang chay trong cluster

| PIP Role | Tool cu the | Namespace | Pod/Service | Port |
|----------|-------------|-----------|-------------|------|
| User Identity | **Keycloak** | `security` | `keycloak` | 8080 |
| Workload Identity | **Cilium Agent** (SPIFFE) | `kube-system` | `cilium-*` (DaemonSet) | — |
| Secret Management | **Vault** | `vault` | `vault-0` (StatefulSet) | 8200 |
| Log Aggregation | **Elasticsearch** | `monitoring` | `elasticsearch` | 9200 |
| Log Collection | **Filebeat** | `monitoring` | `filebeat-*` (DaemonSet) | — |
| Metrics | **Prometheus** | `monitoring` | `prometheus` | 9090 |
| Node Metrics | **node-exporter** | `monitoring` | `node-exporter` (DaemonSet) | 9100 |
| K8s State | **kube-state-metrics** | `monitoring` | `kube-state-metrics` | 8080 |
| Network Flow | **Hubble Relay** | `kube-system` | `hubble-relay` | 4245 |
| Visualization | **Grafana** | `monitoring` | `grafana` | 3000 |
| Log Query | **Kibana** | `monitoring` | `kibana` | 5601 |

## Anh xa PIP sang code thuc te

```
                        ┌──────────────┐
                        │  PE (OPA +   │
                        │  Kong rules) │
                        └──────┬───────┘
                               │ truy van
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
    ┌──────────┐       ┌──────────────┐     ┌──────────────┐
    │ PIP: IdP │       │ PIP: Workload│     │ PIP: Observ. │
    │ Keycloak │       │ Vault + SPIFFE│     │ EFK+Prom+Hub │
    └──────────┘       └──────────────┘     └──────────────┘
```

## Bang anh xa chi tiet

### PIP 1: Identity Provider (IdP) — Keycloak

| Thuoc tinh | Gia tri | Nguon | File code |
|------------|---------|-------|-----------|
| `sub` (Subject ID) | `user123` | JWT payload | `infras/kong/kong.yml` |
| `iss` (Issuer) | `http://auth.job7189.local/realms/job7189` | JWT header | `infras/keycloak/realms/realm-job7189.json` |
| `azp` (Authorized Party) | `recruiter-app-dev` hoac `candidate-app-dev` | JWT payload | Keycloak client config (`realm-job7189.json`) — phan biet recruiter vs candidate o tang ha tang. Per-workspace business roles enforced o Laravel (`workspace_members` bitmask). |
| `exp` (Expiration) | Unix timestamp | JWT payload | Keycloak token settings |
| `email_verified` | `true/false` | JWT payload | Keycloak user attributes |

**PE su dung de:** Xac dinh nguoi dung la ai, co role gi, token con han khong.
**Trang thai:** ✅ Deployed — Keycloak + Kong JWT validation

---

### PIP 2: Workload Identity — SPIFFE/SVID (Cilium mesh-auth)

| Thuoc tinh | Gia tri | Nguon | File code |
|------------|---------|-------|-----------|
| SPIFFE ID | `spiffe://job7189.local/ns/job7189-apps/sa/identity-service` | Cilium agent | `08-harden-security.sh` |
| X.509 Certificate | Short-lived SVID | Cilium mesh-auth CA | `cilium-config` |
| Namespace | `job7189-apps` | K8s metadata | SA binding |
| ServiceAccount | `identity-service` | K8s SA | `deployment.yaml` |

**PE su dung de:** Xac dinh workload la ai, co cert hop le khong.
**Trang thai:** ✅ Deployed — Cilium mesh-auth enabled

---

### PIP 3: Secret Manager — Vault

| Thuoc tinh | Gia tri | Nguon | File code |
|------------|---------|-------|-----------|
| Vault Auth Method | `kubernetes` | Vault K8s auth | `99-fast-rebuild-vault.sh` |
| Dynamic Credentials | `usr_<random12>:<password>` | Database Engine | Vault DB roles |
| Lease ID | `database/creds/identity-service/abc123` | Vault lease | Vault Agent |
| TTL | `3600s` (1h) | Vault role config | `99-fast-rebuild-vault.sh` |
| Policy | `identity-service` | Vault RBAC | `99-fast-rebuild-vault.sh` |

**PE su dung de:** PA cap phat credential dong; PE biet service nao co quyen truy cap DB nao.
**Trang thai:** ✅ Deployed — 7 active leases, TTL 1h

---

### PIP 4: CDM (Continuous Diagnostics & Mitigation)

| Thuoc tinh | Gia tri | Nguon | Trang thai |
|------------|---------|-------|------------|
| Container Image CVE | CVSS score | Trivy scan | ⚠️ Manual (chua tu dong) |
| K8s CIS Benchmark | Pass/Fail | kube-bench | ❌ Chua deploy |
| Pod Security Standards | Restricted/Baseline | K8s PSA | ⚠️ Partial |

**PE su dung de:** Tu choi luong giao tiep neu workload co loi hong CVSS > 7.0.
**Trang thai:** ⚠️ Partial — Trivy manual, kube-bench chua deploy

---

### PIP 5: Device Posture (End-User)

| Thuoc tinh | Gia tri | Nguon | Trang thai |
|------------|---------|-------|------------|
| OS version | - | MDM agent | ❌ |
| Disk encryption | - | MDM agent | ❌ |
| Jailbreak status | - | MDM agent | ❌ |
| Antivirus active | - | EDR agent | ❌ |

**PE su dung de:** Tu choi truy cap neu thiet bi khong dat tieu chuan.
**Trang thai:** ❌ Chua co MDM/EDR — thesis ghi ro "Initial" cho CISA Devices pillar

---

### PIP 6: Threat Intelligence

| Thuoc tinh | Gia tri | Nguon | Trang thai |
|------------|---------|-------|------------|
| Malicious IPs | Blacklist | External feeds | ❌ |
| Compromised certs | Revoked SVID | SPIRE/CRL | ❌ |
| IoC (Indicators of Compromise) | Signatures | STIX/TAXII | ❌ |

**PE su dung de:** Tu choi request tu nguon da biet la nguy hiem.
**Trang thai:** ❌ Chua tich hop — du kien

---

### PIP 7: Observability & Activity Logs

| Thuoc tinh | Gia tri | Nguon | File code |
|------------|---------|-------|-----------|
| API access logs | Kong 401/403 events | EFK (Filebeat → ES) | `06-filebeat.yaml` |
| Auth events | Login success/fail | Keycloak audit log → EFK | `06-filebeat.yaml` |
| Network flows | FORWARDED/DROPPED | Cilium Hubble | `hubble observe` |
| Resource metrics | CPU/RAM/Network | Prometheus + node-exporter | `08-prometheus.yaml` |
| Vault lease events | Create/Revoke/Expire | Vault audit log | Vault config |
| K8s object state | Pod restart, CrashLoop | kube-state-metrics | Script 07 |

**PE su dung de:** Phat hien anomaly → giam Trust Score → PE ra lenh PEP ngan chan.
**Trang thai:** ✅ Deployed — EFK + Prometheus + Grafana + Hubble + exporters

---

## Tong hop trang thai PIP

| PIP | Thanh phan | Trang thai |
|-----|-----------|------------|
| 1. Identity (User) | Keycloak OIDC → JWT | ✅ |
| 2. Identity (Workload) | SPIFFE/SVID Cilium mesh-auth | ✅ |
| 3. Secret Manager | Vault K8s Auth + Database Engine | ✅ |
| 4. CDM | Trivy (manual), kube-bench | ⚠️ Partial |
| 5. Device Posture | MDM/EDR | ❌ |
| 6. Threat Intel | External feeds | ❌ |
| 7. Observability | EFK + Prometheus + Hubble | ✅ |

**Ket luan**: 4/7 PIP da trien khai day du. 1 partial. 2 chua co (declared trong thesis).

## Phase 4 — PIP hardening roadmap

Trien khai tuan tu theo **5 buoc** cua do an 1 (Muc 2.3 / 3.4):

| Phase | Buoc thesis | Tac dong len PIP |
|-------|-------------|------------------|
| PR #7 | 2.3.1 Observability | PIP 7 — them baseline snapshot tool (`scripts/zta-observability-baseline.sh`); doc `17-observability-baseline.md` |
| PR #8 | 2.3.2 Zero Trust DAAS + microperimeter | PIP 4 — DAAS classification van ban hoa (`doc/18-daas-classification.md`); CNP per-namespace dat trong `infras/k8s-yaml/cilium-policies/namespaces/`; audit findings F-1/F-2/F-4 fixed (`doc/22-audit-findings-remediation.md`) |
| PR #9 | 2.3.3 Workload labeling | PIP 2 — Cilium identity mo rong (4-6 nhan), PE co them subject attributes |
| PR #10 | 2.3.4 5W1H comprehensive policy | PIP 1+2+3+7 — moi luong duoc mo ta theo Who/What/When/Where/Why/How |
| PR #11 | 2.3.5 Adaptive security | PIP 7 — closed loop Tetragon → controller → Cilium label patcher; chuan bi cau truc cho PIP 6 (Threat Intel) |

PIP 5 (Device Posture) va PIP 6 (Threat Intel) duoc dat o **Phase 5** vi can
nguon du lieu external (MDM/EDR / threat feed) chua available trong cluster.

## Vong doi du lieu PIP → PE → PEP

```
1. Request den → PEP (Kong/Cilium) chan bat
2. PEP gui metadata → PE
3. PE truy van cac PIP:
   - PIP 1 (Keycloak): JWT claims?
   - PIP 2 (SPIFFE): SVID hop le?
   - PIP 3 (Vault): Credential con han?
   - PIP 7 (Observability): Co anomaly nao?
4. PE tinh Trust Score → Allow/Deny
5. PE gui quyet dinh → PA
6. PA cau hinh PEP → Allow/Deny request
```

## Xem them

- Thesis: chapter1.tex, Muc 1.2.2 (Data Sources / PIP)
- Thesis: chapter2.tex, Muc 2.3.2 (Lop 2: Posture & Threat Intel)
- NIST SP 800-207: Figure 2 (Logical Components)
- NIST SP 800-162: ABAC PIP definition
- Architecture: `doc/02-architecture-layers.md`
- Identity: `doc/03-identity-layer.md`
- Observability: `doc/05-observability-stack.md`
