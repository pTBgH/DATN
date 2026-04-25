# Policy Enforcement — Kong JWT + Cilium Microsegmentation

## PEP Bien (North-South): Kong Gateway

### Deployment
- Namespace: `gateway`
- Mode: DB-less (Declarative)
- Config file: `infras/kong/kong.yml`
- YAML: `infras/k8s-yaml/04-kong-dbless.yaml`

### Nguyen tac
- Khong co "trusted internal bypass"
- Moi request den route bao mat phai co JWT hop le
- Khong co IP whitelist, khong basic auth, khong ngoai le

### Ma tran route JWT

| Service | Route mau | JWT? | Ly do |
|---------|-----------|------|-------|
| identity-service | `/api/recruiters/profile` | Co | Du lieu ca nhan |
| identity-service | `/api/health` | Khong | Health check |
| workspace-service | `/api/workspaces` | Co | Du lieu doanh nghiep |
| job-service | `/api/jobs` | Khong | Listing cong khai |
| job-service | `/api/admin/jobs` | Co | Quan tri |
| hiring-service | `/api/jobs/{id}/apply` | Khong | Ung tuyen cong khai |
| hiring-service | `/api/applications` | Co | Du lieu ung vien |
| candidate-service | `/api/resumes` | Co | CV ca nhan |
| communication-service | `/api/conversations` | Co | Tin nhan rieng tu |
| storage-service | `/api/presigned-url` | Khong | URL tam |

### JWT Verification
- Algorithm: RS256
- Key source: Keycloak JWKS endpoint (hien tai static RSA public key trong `kong.yml`)
- Issuer: `http://auth.job7189.local/realms/job7189`

### Ingress Routing
- `api.job7189.com` → Kong Gateway (namespace: gateway)
- `auth.job7189.local` → Keycloak (namespace: security)
- File: `infras/k8s-yaml/ingress/01_ingress_public.yaml`

---

## PEP Mang (East-West): Cilium Microsegmentation

### File chinh sach

| File | Muc dich | Thu tu |
|------|----------|--------|
| `00-default-deny.yaml` | Chan 100% traffic | Buoc 1 |
| `01-allow-egress-dns.yaml` | Cho phep DNS (CoreDNS port 53) | Buoc 2 |
| `02-allow-egress-data.yaml` | Cho phep MySQL/Redis/Kafka/Vault | Buoc 3 |
| `03-allow-ingress-kong.yaml` | Cho phep ingress tu Kong | Buoc 4 |
| `04-allow-internal-api-strict.yaml` | L7 E-W giua services | Buoc 5 |
| `20-security-policies.yaml` | SA-based microseg + default-deny data ns | Bo sung |

**Apply script**: `infras/k8s-yaml/cilium-policies/apply-zta-microsegmentation.sh`
**Destroy script**: `infras/k8s-yaml/cilium-policies/destroy-zta-microsegmentation.sh`

### BUG TRACKER
- ~~⚠️ `03-allow-ingress-kong.yaml` namespace `kong`~~ → ✅ DA FIX: da la `gateway`

### GAP TRACKER (da close)
- ~~❌ Policy files chua hook vao deploy chain~~ → ✅ DA FIX: Script 02 Step 9c auto-apply
- ~~❌ Hai bo policy trung nhau~~ → `cilium-policies/*` la canonical, `20-security-policies.yaml` la bo sung

### ENCRYPTION
- mTLS sidecarless: ✅ DA BAT (script 08)
- WireGuard: ✅ DA BAT (script 08)
- Xem chi tiet: `doc/15-encryption-mtls-spiffe.md`

### Ma tran truy cap E-W

| Nguon | Dich | Port | L7 Rule | Phep? |
|-------|------|------|---------|-------|
| Kong (gateway) | Moi service | 80 | — | ✅ |
| Moi service | CoreDNS | 53/UDP | — | ✅ |
| Moi service | MySQL (data) | 3306 | — | ✅ |
| Moi service | Redis (data) | 6379 | — | ✅ |
| Moi service | Kafka (data) | 9092 | — | ✅ |
| Moi service | Vault (vault) | 8200 | — | ✅ |
| job-service | workspace-service | 80 | GET /api/v1/internal/workspaces/.* | ✅ |
| hiring-service | identity-service | 80 | GET /api/v1/internal/profile/.* | ✅ |
| job-service | identity-service | 80 | — | ❌ |
| candidate-service | workspace-service | 80 | — | ❌ |
| Moi service | Internet | * | — | ❌ |
| Moi service | Moi service khac | * | — | ❌ |

### L7 HTTP Policy Examples
- `job-service` → `workspace-service`: CHI `GET /api/v1/internal/workspaces/.*`
- `hiring-service` → `identity-service`: CHI `GET /api/v1/internal/profile/.*`
- Kich ban bi chan:
  - POST → 403 (chi GET duoc phep)
  - GET path khac → 403 (path khong khop)
  - Request den service khong co policy → Drop

### Xac minh
- Hubble CLI: `hubble observe -n job7189-apps --verdict DROPPED`
- Test Pod: tao pod voi SA khong co policy → verify timeout/deny
- Allowed Pod: tao pod voi SA co policy → verify 200 OK
