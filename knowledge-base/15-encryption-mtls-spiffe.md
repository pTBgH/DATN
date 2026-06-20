# Encryption & Mutual Authentication — mTLS + WireGuard + SPIFFE

## Tong quan

He thong su dung 2 lop ma hoa chong cheo:

```
┌─────────────────────────────────────────┐
│ WireGuard (Layer 3 — kernel)            │
│ Ma hoa moi goi tin pod-to-pod           │
│ Khong can app biet                      │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Cilium Mesh Auth (Layer 4/7)   │    │
│  │ Mutual TLS sidecarless         │    │
│  │ SPIFFE identity verification   │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

> ✅ **Trang thai thuc te (cluster 2026-06-20):** Cilium **mesh-auth-enabled = true** —
> peer-mTLS sidecarless qua Cilium mesh-auth DA duoc kich hoat (SPIFFE SVID do SPIRE cap
> phat, xem chuong 03). Cilium **WireGuard = false**; lop ma hoa L3 node-to-node do
> **Tailscale WireGuard** (mesh CGNAT 100.64.0.0/10) dam nhan.
>
> Lich su: snapshot 2026-06-03 tung ghi `mesh-auth-enabled=false` (so do tren khi do la
> THIET KE muc tieu); cluster da bat mesh-auth tu sau do — xac nhan lai bang
> `kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.mesh-auth-enabled}'`.

## mTLS Sidecarless (Cilium Mesh Auth)

### Co che hoat dong
- Cilium agent tren moi node tu dong cap **SPIFFE SVID** (X.509 cert) cho moi pod
- Khi pod A goi pod B, Cilium agent thuc hien **TLS handshake** o tang kernel
- Khong can sidecar proxy (khac voi Istio), giam "Thue Sidecar"
- SPIFFE ID format: `spiffe://job7189.local/ns/<namespace>/sa/<serviceaccount>`

### SPIFFE Identity cua 7 services

| Service | SPIFFE ID |
|---------|-----------|
| identity-service | `spiffe://job7189.local/ns/job7189-apps/sa/identity-service` |
| workspace-service | `spiffe://job7189.local/ns/job7189-apps/sa/workspace-service` |
| job-service | `spiffe://job7189.local/ns/job7189-apps/sa/job-service` |
| hiring-service | `spiffe://job7189.local/ns/job7189-apps/sa/hiring-service` |
| candidate-service | `spiffe://job7189.local/ns/job7189-apps/sa/candidate-service` |
| communication-service | `spiffe://job7189.local/ns/job7189-apps/sa/communication-service` |
| storage-service | `spiffe://job7189.local/ns/job7189-apps/sa/storage-service` |

### Config tren cluster (xac nhan 2026-06-20)
```
cilium-config:
  mesh-auth-enabled: "true"    # XAC NHAN BAT tren cluster
  mesh-auth-gc-interval: "5m0s"
  mesh-auth-queue-size: "1024"
  mesh-auth-rotated-identities-queue-size: "1024"
```
> Script 08 bat `mesh-auth-enabled=true` va gia tri thuc te tren `cilium-config`
> hien la `true` — peer-mTLS sidecarless DA active. SPIFFE SVID do SPIRE cap (xem chuong 03).

### Trang thai: ✅ DA KICH HOAT (cluster: `mesh-auth-enabled=true`)

---

## WireGuard Transparent Encryption

### Co che hoat dong
- Cilium tao interface `cilium_wg0` tren moi node
- Moi node co WireGuard keypair rieng
- Traffic giua cac node tu dong ma hoa tai Layer 3 — **trong suot voi app**
- Su dung ChaCha20-Poly1305 (nhanh hon AES tren CPU khong co AES-NI)

### Config tren cluster (xac nhan 2026-06-03, snapshot 40)
```
cilium-config:
  enable-wireguard: "false"   # Cilium WireGuard HIEN DANG TAT
# Baseline ma hoa L3 node-to-node dung Tailscale WireGuard (mesh CGNAT), KHONG
# phai Cilium WireGuard. Vi du verify (khi bat) o duoi chi mang tinh tham khao:

# Verify:
# cilium encrypt status
# → Interface: cilium_wg0
# → Public key: fZEvIbXXM2rWjEzmlPxQj1xz3AvTK5+cmrj2lWNpXTM=
# → Number of peers: 3
```

### Trang thai: ❌ Cilium WireGuard CHUA KICH HOAT. Lop L3 thuc te = Tailscale WireGuard (node-to-node, mesh 100.64.0.0/10).

---

## Dual Identity Model (Thesis Chapter 2, Muc 2.3.1)

Thesis de xuat **Dual-Identity** — xac thuc kep:

| Lop | Cong nghe | Chuc nang | Trang thai |
|-----|-----------|-----------|------------|
| User Identity | Keycloak OIDC → JWT | Xac thuc nguoi dung | ✅ |
| Workload Identity | SPIFFE SVID (SPIRE) | Xac thuc service | ✅ (SPIRE cap SVID) |
| Peer verification | mTLS handshake (Cilium mesh-auth) | Dam bao 2 ben deu co cert hop le | ✅ DA bat (mesh-auth=true) |

### Luong xac thuc kep

```
User Request (JWT)
    │
    ▼
Kong Gateway ──→ Verify JWT signature (RS256, Keycloak JWKS)
    │              → 401 neu khong co token
    ▼
Cilium eBPF ──→ Verify SPIFFE SVID cua pod dich
    │              → Drop neu SVID khong hop le
    ▼
Application Pod ──→ Doc credentials tu Vault (JIT)
                     → Query database voi user tam thoi
```

---

## OPA/Rego (Policy Engine — Thiet ke)

Thesis (chapter 2, Muc 2.3.3) mo ta PE dung OPA/Rego.
Hien tai chua deploy OPA rieng, chinh sach duoc thuc thi qua:
- **Kong**: JWT validation rules (north-south)
- **Cilium**: CiliumNetworkPolicy L3/L4/L7 (east-west)

### OPA Policy Example (tu thesis)
```rego
package authz.internal_api

default allow = false

allow {
    input.workload_id == "spiffe://job7189.local/ns/job7189-apps/sa/job-service"
    input.request.method == "GET"
    startswith(input.request.path, "/api/v1/internal/workspaces/")
    "recruiter" in jwt_claims.roles
    input.workload_posture.vulnerabilities.critical == 0
}
```

### Trang thai: ⚠️ PARTIAL
- Logic tuong duong da duoc implement qua Kong + Cilium
- OPA server chua deploy rieng (du kien)

---

## ABAC Model (Thesis Chapter 2, Muc 2.4)

```
Decision = f(Subject, Resource, Action, Environment)
```

| Nhom thuoc tinh | Vi du | Nguon |
|-----------------|-------|-------|
| Subject | JWT claims (email, roles), SPIFFE ID | Keycloak, Cilium |
| Resource | Endpoint URL, Namespace, Labels | Kong route, CiliumNetworkPolicy |
| Action | HTTP method (GET/POST/DELETE) | Cilium L7 rule |
| Environment | Thoi gian, IP, Trust Score | Chua day du (CAEP/UEBA) |

---

## CAEP — Continuous Access Evaluation (Thesis Chapter 1, Muc 1.2.3)

### Thiet ke trong thesis
- Sau khi JWT duoc cap, he thong giam sat lien tuc
- Neu phat hien bat thuong (IP doi, UEBA anomaly), PE thu hoi token
- Khac voi cach truyen thong: JWT het han moi mat hieu luc

### Trang thai hien tai: ❌ CHUA TRIEN KHAI
- Keycloak co OIDC backchannel logout nhung chua cau hinh
- Chua co UEBA/anomaly detection pipeline
- Day la khoang trong lon nhat giua thesis va PoC

### Ke hoach (du kien)
1. Keycloak backchannel logout → Kong invalidate token
2. Prometheus alert → trigger Keycloak session revocation
3. Cilium policy update dynamic (increase deny)

---

## Xem them

- Thesis: chapter1.tex, Muc 1.2.3 (Vong doi quyet dinh truy cap)
- Thesis: chapter2.tex, Muc 2.3.1 (Dual-Identity)
- Thesis: chapter2.tex, Muc 2.3.3 (OPA/Rego)
- Thesis: chapter2.tex, Muc 2.4 (ABAC)
- Deploy script: `08-harden-security.sh`
- Verify script: `09-verify-zta.sh` (Test 5: Encryption Status)
