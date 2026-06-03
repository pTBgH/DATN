# Identity Layer — Keycloak + Vault + ServiceAccount

## Keycloak (User Identity)

### Deployment
- Namespace: `security`
- Image: `job7189/keycloak-custom:v1.0` (custom build)
- Mode: `start-dev --import-realm` (internal-only)
- Domain: `auth.job7189.local`
- File: `infras/k8s-yaml/02-keycloak.yaml`
- Dockerfile: `infras/keycloak/Dockerfile`

### Dual-Realm Architecture
| Realm | Muc dich | Nguoi dung | File |
|-------|----------|------------|------|
| `7189_internal` | Admin/SysOps dashboards | SysAdmin | `infras/keycloak/realm-infra.json` (baked vao image) |
| `job7189` | End-user (recruiter, candidate) | End-user | `infras/keycloak/realms/realm-job7189.json` (import qua API) |

### OIDC Flow
1. Client goi `/realms/job7189/protocol/openid-connect/token` voi
   `client_id=recruiter-app-dev` hoac `candidate-app-dev`
2. Keycloak tra JWT: `sub`, `iss`, `exp`, `azp` (la `client_id` da dung de login)
3. Client gui JWT trong `Authorization: Bearer <token>`
4. Kong xac minh RS256 bang Public Key tu JWKS endpoint

### JWT Structure (Payload)
```json
{
  "exp": 1713245000,
  "iat": 1713235000,
  "iss": "https://auth.job7189.local/realms/job7189",
  "sub": "user123",
  "azp": "recruiter-app-dev",
  "preferred_username": "recruiter1"
}
```

### Role model
- **Keycloak realm `job7189` khong gan business realm-roles cho user.** Hai
  client `recruiter-app-*` va `candidate-app-*` la dau hieu duy nhat phan
  biet user nghiep vu o tang ha tang — `azp` cua JWT cho biet client da mint
  token. Laravel doc `azp` de set `users.type = 'recruiter' | 'candidate'`.
- **Platform admin** xac dinh boi membership active cua workspace co ID
  trong env `SUPER_ADMIN_WORKSPACE_ID`. Khong co realm-role `admin`.
  Middleware `super.admin` cua moi Laravel service hoi `is-super-admin` Gate
  → query `workspace_members` cua admin workspace.
- **Cac role nghiep vu khac** (rec_ops, sourcer, coordinator, hiring_manager,
  interviewer, member) hoan toan o trong Laravel: bitmask
  `workspace_members.{job,workspace,candidate,pipeline}_permissions` per
  (user, workspace). Khong leak sang Keycloak hay OPA.
- **Realm `7189_internal`** rieng cho SysOps dashboards, khong lien quan
  user nghiep vu.

### Credential Bootstrap
- Mat khau sinh random: `openssl rand -base64 16`
- Luu trong K8s Secret `app-secrets` (namespace: security)
- Khong hardcode trong code

---

## Vault (Workload Identity + Dynamic Secrets)

### Dual-Vault Architecture
```
vault-dev (Dev mode, port 8300)
  └── Transit Engine: key "vault-prod-unseal-key"
      └── Auto-unseal cho vault-prod

vault-prod (StatefulSet, port 8200 TLS)
  ├── Storage: file backend tren PVC 2Gi
  ├── TLS: cert-manager self-signed certificate
  ├── Auth: Kubernetes Auth Method
  └── Secret Engines:
      ├── KV v2 (path: secret/) — APP_KEY, Keycloak secrets
      └── Database (MySQL dynamic credentials)
```
File: `infras/k8s-yaml/11-vault.yaml`

### Known Limitation
> vault-dev chay dev mode (RAM-only). Neu restart → mat Transit key → vault-prod khong tu unseal.
> Production can: Raft storage + PV hoac Cloud KMS.

### Kubernetes Auth
- Moi service co 1 ServiceAccount → map 1:1 voi 1 Vault role
- File: `infras/k8s-yaml/vault-scripts/99-fast-rebuild-vault.sh`
```
vault write auth/kubernetes/role/"$SVC" \
  bound_service_account_names="$SVC" \
  bound_service_account_namespaces=job7189-apps \
  policies="$SVC" ttl=1h max_ttl=24h
```

### Dynamic Database Credentials (JIT)
- Moi service nhan MySQL user random, TTL 1h
- Chi 4 quyen CRUD tren dung 1 database
- Revoke tu dong: `DROP USER IF EXISTS`
- Username format: `usr_<random 12>`

### Vault Agent Injector Lifecycle
1. Pod tao → MutatingWebhook inject `vault-agent-init`
2. Init container auth voi Vault qua SA token
3. Vault tao MySQL user → ghi `/vault/secrets/.env.db` tren **tmpfs**
4. `env-loader` merge `.env.common` + `.env.db` + `.env.extra` → `/app-secrets/.env`
5. App doc `.env`, ket noi MySQL
6. `env-watcher` detect rotation → goi `/api/internal/reload-db` → Laravel reconnect
7. TTL het → Vault revoke → Agent tu dong lay credential moi

### Vault Policies (7 services)
Moi service chi doc duoc:
- `secret/data/laravel-common` (APP_KEY, shared config)
- `database/creds/<service-name>` (JIT MySQL creds)
- `secret/data/<service-name>` (service-specific secrets)

---

## ServiceAccount Mapping

| Service | ServiceAccount | Vault Role | Database |
|---------|---------------|------------|----------|
| identity-service | identity-service | identity-service | job7189_identity_db |
| workspace-service | workspace-service | workspace-service | job7189_workspace_db |
| job-service | job-service | job-service | job7189_job_db |
| hiring-service | hiring-service | hiring-service | job7189_hiring_db |
| candidate-service | candidate-service | candidate-service | job7189_candidate_db |
| communication-service | communication-service | communication-service | job7189_communication_db |
| storage-service | storage-service | storage-service | job7189_storage_db |
