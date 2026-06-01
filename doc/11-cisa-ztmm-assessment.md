# CISA ZTMM 2.0 Self-Assessment — job7189

Danh gia theo Mo hinh Truong thanh Zero Trust cua CISA (ZTMM v2.0).
4 cap do: Traditional → Initial → Advanced → Optimal.

## 5 Tru cot

### 1. Identity — **Advanced**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| IdP tap trung | Keycloak OIDC (Dual-Realm) | ✅ |
| Workload Identity | SA + Vault K8s Auth + **SPIFFE SVID** (Cilium mesh-auth) | ✅ |
| MFA | Keycloak ho tro, chua bat buoc | ⚠️ |
| Phan quyen thuoc tinh | Kong JWT + OPA (public vs authenticated); business roles (per-workspace) duoc Laravel `workspace_members` bitmask enforce | ✅ |
| Danh gia rui ro lien tuc | CAEP chua trien khai | ❌ |
| PIP Identity tools | Keycloak (port 8080) + Cilium Agent (SPIFFE) + Vault (port 8200) | ✅ |

**De dat Optimal**: Can CAEP/ITDR de thu hoi token giua phien.

### 2. Devices — **Initial**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| Kiem ke thiet bi | Container image scan (Trivy — ly thuyet) | ⚠️ |
| Danh gia suc khoe | Kube-bench (ke hoach) | ❌ |
| MDM/EDR | Khong co | ❌ |

**De dat Advanced**: Can Trivy tu dong + kube-bench. Can MDM cho end-user devices.

### 3. Networks — **Advanced+**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| Microsegmentation | Cilium eBPF L3/L4/L7, 6 policies, Default Deny | ✅ |
| mTLS sidecarless | Cilium mesh-auth (SPIFFE SVID) | ✅ DA BAT |
| WireGuard encryption | Transparent node-to-node (ChaCha20) | ✅ DA BAT |
| Egress filtering | Cilium egress policy | ✅ |
| Network flow visibility | Hubble UI/CLI + Hubble Relay | ✅ |
| PIP Network tools | Hubble Relay (port 4245), Prometheus (port 9090) | ✅ |

**De dat Optimal**: Can AI/ML-driven policy adaptation.

### 4. Applications & Workloads — **Advanced (mot phan)**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| API Gateway JWT | Kong RS256 per-route | ✅ |
| CI/CD bao mat | Build pipeline tu dong, ko hardcode secret | ✅ |
| Runtime enforcement | Tetragon (du kien, chua deploy) | ❌ |
| Image scanning | Trivy (ly thuyet) | ⚠️ |

**De dat Optimal**: Deploy Tetragon + tu dong scan images trong CI.

### 5. Data — **Advanced**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| Dynamic credentials | Vault JIT, TTL 1h, auto-revoke | ✅ |
| Secret tren tmpfs | emptyDir medium: Memory | ✅ |
| Auto rotation | Vault Agent renew + env-watcher reload | ✅ |
| Phan loai du lieu | Chua co data classification | ❌ |
| DLP | Chua co | ❌ |

**De dat Optimal**: Phan loai/gan nhan du lieu tu dong.

---

## 3 Nang luc xuyen suot

### Tam nhin & Phan tich (Visibility & Analytics)
- EFK tap trung log tu 4 namespace
- Prometheus + Grafana metrics
- Hubble network flow visualization
- **Gap**: Chua co UEBA/anomaly detection tu dong

### Tu dong hoa & Dieu phoi (Automation & Orchestration)
- Helmfile declarative deployment
- Vault Agent tu dong inject secrets
- CiliumNetworkPolicy auto-update theo labels
- **Gap**: Chua co SOAR playbook (detect anomaly → auto-response)

### Quan tri (Governance)
- RBAC K8s per-namespace
- Vault Policy per-service
- Kong JWT enforcement
- Allow-Explicit nguyen tac
- **Gap**: Chua co compliance audit tu dong

---

## Tong ket

| Tru cot | Cap do hien tai | Gap chinh |
|---------|-----------------|-----------|
| Identity | Advanced | CAEP/ITDR |
| Devices | Initial | MDM/EDR, Trivy CI |
| Networks | **Advanced+** | AI/ML policy |
| Apps & Workloads | Advanced (1 phan) | Tetragon runtime |
| Data | Advanced | Data classification |

**Tong the**: He thong dat **Advanced** (Networks dat Advanced+). Can CAEP + Tetragon de tien gan Optimal.

## Xem them

- PIP tools chi tiet: `doc/16-pip-data-sources.md`
- Encryption: `doc/15-encryption-mtls-spiffe.md`
- Tetragon: `doc/14-tetragon-runtime.md`
