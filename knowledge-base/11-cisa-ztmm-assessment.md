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
| Kiem ke thiet bi | Trivy Operator quet image (VulnerabilityReport CRD) | ✅ |
| Danh gia suc khoe | Kube-bench (ke hoach, chua deploy) | ❌ |
| MDM/EDR (client device) | Khong co — ngoai pham vi (chi quan workload, khong quan client) | ❌ |

**De dat Advanced**: Can kube-bench (CIS) cho node health. MDM/EDR cho end-user device la ngoai pham vi de an (xem `52-limitations-and-known-gaps.md`).

### 3. Networks — **Advanced+**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| Microsegmentation | Cilium eBPF L3/L4/L7, 6 policies, Default Deny | ✅ |
| mTLS sidecarless | Cilium mesh-auth (SPIFFE SVID) | ✅ DA BAT |
| Ma hoa L3 node-to-node | Tailscale WireGuard (mesh CGNAT 100.64.0.0/10) | ✅ DA BAT (Cilium WireGuard TAT, Tailscale dam nhan L3) |
| Egress filtering | Cilium egress policy | ✅ |
| Network flow visibility | Hubble UI/CLI + Hubble Relay | ✅ |
| PIP Network tools | Hubble Relay (port 4245), Prometheus (port 9090) | ✅ |

**De dat Optimal**: Can AI/ML-driven policy adaptation.

### 4. Applications & Workloads — **Advanced**

| Tieu chi | Trien khai | |
|----------|-----------|---|
| API Gateway JWT | Kong RS256 per-route | ✅ |
| CI/CD bao mat | Build pipeline tu dong, ko hardcode secret | ✅ |
| Runtime enforcement | Tetragon v1.7.0 (DaemonSet 3/3): `block-suspicious-exec` Sigkill enforce o 4 ns + Post audit | ✅ |
| Image admission | Sigstore Cosign (3 ClusterImagePolicy, **mode=warn**) | ⚠️ WARN (chua ENFORCE) |
| Image scanning | Trivy Operator (VulnerabilityReport CRD) | ✅ |

**De dat Optimal**: Chuyen Cosign tu WARN sang ENFORCE + tu dong scan images trong CI.

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
| Identity | Advanced | CAEP/ITDR (thu hoi phien) |
| Devices | Initial | kube-bench; MDM/EDR ngoai pham vi |
| Networks | **Advanced+** | AI/ML policy |
| Apps & Workloads | **Advanced** | Cosign WARN→ENFORCE; image scan trong CI |
| Data | Advanced | Data classification |

**Tong the**: He thong dat **Advanced** (Networks dat Advanced+). Tetragon runtime da deploy va enforce (Sigkill); gap con lai chu yeu la CAEP (Identity) + Cosign ENFORCE (Apps). Xem `52-limitations-and-known-gaps.md`.

## Xem them

- PIP tools chi tiet: `knowledge-base/16-pip-data-sources.md`
- Encryption: `knowledge-base/15-encryption-mtls-spiffe.md`
- Tetragon: `knowledge-base/14-tetragon-runtime.md`
