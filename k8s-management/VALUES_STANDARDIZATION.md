# Values Files Standardization Guide

**Last Updated:** 2026-06-06  
**Status:** ✅ All service values files standardized

---

## 📋 Standard Template for All Services

Every service's values file must follow this structure:

```yaml
replicaCount: 1

internalReloadToken: "{service}-secure-reload-token-{unique}"

image:
  repository: job7189/{service}[-service]  # Short form (no registry)
  fullImage: "100.74.189.43:5000/job7189/{service}@sha256:{digest}"  # Full digest-pinned ref
  pullPolicy: Always

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  host: "{service}.job7189.local"

redis:
  enabled: true

env:
  APP_NAME: "Job7189 {Service Name}"
  DB_CONNECTION: mysql
  DB_HOST: mysql.data.svc.cluster.local
  DB_PORT: "3306"
  DB_DATABASE: job7189_{service}_db
  CACHE_PREFIX: {service}_
  LOG_CHANNEL: "stderr"
  LOG_LEVEL: "info"  # or "debug" for workspace-service
  # Service-specific env variables...

vault:
  role: {service}-service  # MUST match Vault database role name
  extraSecret: false  # CRITICAL: prevents YAML injection into .env
  secretTemplate: |
    {{- with secret "database/creds/{service}-service" -}}
    DB_USERNAME="{{ .Data.username }}"
    DB_PASSWORD="{{ .Data.password }}"
    LEASE_ID="{{ .Data.lease_id }}"
    {{- end }}

zta:
  role: api
  tier: T2
  env: prod
  dataClassification: internal
  exposure: internal
  team: backend
```

---

## 🔍 Checklist for New/Modified Values Files

- [ ] `replicaCount: 1` at top level
- [ ] `internalReloadToken: "{service}-...-{unique}"` (unique value per service)
- [ ] `image.repository: job7189/{service}[-service]` (no registry in short form)
- [ ] `image.fullImage: 100.74.189.43:5000/job7189/{service}@sha256:{digest}` (digest-pinned, reachable registry)
- [ ] `service.type: ClusterIP` and `service.port: 80`
- [ ] `ingress.enabled: true` and `ingress.host: "{service}.job7189.local"`
- [ ] `redis.enabled: true`
- [ ] `env.APP_NAME`, `env.DB_*` fields populated
- [ ] `env.CACHE_PREFIX: {service}_`
- [ ] `env.LOG_CHANNEL: "stderr"` and `env.LOG_LEVEL` set
- [ ] **`vault.role: {service}-service`** (matches Vault database role)
- [ ] **`vault.extraSecret: false`** (CRITICAL - prevents YAML injection)
- [ ] `vault.secretTemplate` renders DB_USERNAME, DB_PASSWORD, LEASE_ID
- [ ] `zta:` labels present (role, tier, env, dataClassification, exposure, team)

---

## 📁 Current Standardized Services

| Service | File | Status | LastUpdated |
|---------|------|--------|-------------|
| hiring-service | `hiring-values.yaml` | ✅ | 2026-06-06 |
| identity-service | `identity-values.yaml` | ✅ | 2026-06-06 |
| candidate-service | `candidate-values.yaml` | ✅ | 2026-06-06 |
| communication-service | `communication-values.yaml` | ✅ | 2026-06-06 |
| storage-service | `storage-values.yaml` | ✅ | 2026-06-06 |
| job-service | `job-values.yaml` | ✅ | 2026-06-06 |
| workspace-service | `workspace-values.yaml` | ✅ | 2026-06-06 |

---

## ⚠️ Common Mistakes to Avoid

### ❌ Wrong
```yaml
image:
  registry: "100.74.189.43:5000"
  repository: "job7189/identity"
  tag: "v2.8.21"
```

### ✅ Correct
```yaml
image:
  repository: job7189/identity
  fullImage: "100.74.189.43:5000/job7189/identity@sha256:{digest}"
```

---

### ❌ Wrong
```yaml
image:
  repository: "100.74.189.43:5000/job7189/hiring-service"
```

### ✅ Correct
```yaml
image:
  repository: job7189/hiring-service
  fullImage: "100.74.189.43:5000/job7189/hiring-service@sha256:{digest}"
```

---

### ❌ Wrong
```yaml
vault:
  extraSecret: true  # CAUSES YAML INJECTION
```

### ✅ Correct
```yaml
vault:
  extraSecret: false
  secretTemplate: |
    {{- with secret "database/creds/..." -}}
    DB_USERNAME="{{ .Data.username }}"
    ...
    {{- end }}
```

---

## 🚀 How to Add a New Service

1. Copy any existing values file (e.g., `candidate-values.yaml`)
2. Replace all occurrences of `candidate` with new service name
3. Update `internalReloadToken` to unique value
4. Update service-specific env variables (LOG_LEVEL, CACHE_PREFIX, etc.)
5. Verify against checklist above
6. Test deployment: `helm install {service}-service ... -f {service}-values.yaml --dry-run`

---

## 📚 Related Documentation

- **Vault Rotation:** `knowledge-base/43-vault-laravel-rotation-debug.md`
- **ZTA Labels:** `knowledge-base/19-label-schema.md`
- **Helm Chart:** `k8s-management/charts/laravel-app/`

---

## ✅ Verification Command

```bash
# Check all values files follow standard structure
for f in k8s-management/values/*-values.yaml; do
  echo "=== $f ==="
  grep -E "^replicaCount|^  repository|^  fullImage|^vault:|^  role:|^  extraSecret" "$f" | head -7
done
```

