# 📋 Hướng Dẫn Deploy Image Mới Lên Hệ Thống

## 🔄 Quy Trình Deploy Một Service

### **Bước 1: Build Docker Image**

```bash
cd /home/ptb/projects/DATN/src/<SERVICE_NAME>/laravel_back

# Kiểm tra phiên bản hiện tại (từ .env hoặc APP_VERSION)
cat .env | grep APP_VERSION

# Build image với tag version
docker build -t localhost:5000/job7189/<SERVICE_NAME>:v<VERSION> .
docker build -t localhost:5000/job7189/<SERVICE_NAME>:latest .
```

**Ví dụ:**
```bash
docker build -t localhost:5000/job7189/workspace-service:v2.8.19 .
docker build -t localhost:5000/job7189/workspace-service:latest .
```

---

### **Bước 2: Lấy SHA256 Digest**

Sau khi build, lấy digest của image:

```bash
docker inspect --format='{{index .RepoDigests 0}}' localhost:5000/job7189/<SERVICE_NAME>:v<VERSION>
```

**Output:** `localhost:5000/job7189/<SERVICE_NAME>@sha256:abcd1234...`

---

### **Bước 3: Push Image Lên Registry**

```bash
docker push localhost:5000/job7189/<SERVICE_NAME>:v<VERSION>
docker push localhost:5000/job7189/<SERVICE_NAME>:latest
```

---

### **Bước 4: Tạo/Cập Nhật Helm Values File**

Tạo file: `k8s-management/values/<SERVICE_NAME>-values.yaml`

**Template:**
```yaml
replicaCount: 1

image:
  repository: localhost:5000/job7189/<SERVICE_NAME>
  fullImage: "localhost:5000/job7189/<SERVICE_NAME>@sha256:<DIGEST>"
  pullPolicy: Always

vault:
  role: <SERVICE_NAME>
  extraSecret: true
  secretTemplate: |
    {{- with secret "database/creds/<SERVICE_NAME>" -}}
    DB_USERNAME="{{ .Data.username }}"
    DB_PASSWORD="{{ .Data.password }}"
    LEASE_ID="{{ .Data.lease_id }}"
    {{- end }}

env:
  APP_NAME: <SERVICE_NAME>
  DB_CONNECTION: mysql
  DB_HOST: mysql.data.svc.cluster.local
  DB_PORT: 3306
  DB_DATABASE: job7189_<SERVICE_NAME_DB>
  # ... thêm các env khác
```

---

### **Bước 5: Deploy với Helm**

```bash
# Cú pháp
helm upgrade --install <RELEASE_NAME> k8s-management/charts/laravel-app \
  -n job7189-apps \
  -f k8s-management/values/<SERVICE_NAME>-values.yaml

# Ví dụ
helm upgrade --install workspace-service k8s-management/charts/laravel-app \
  -n job7189-apps \
  -f k8s-management/values/workspace-values.yaml
```

---

### **Bước 6: Verify Deployment**

```bash
# Xem pod status
kubectl get pods -n job7189-apps -l app=<SERVICE_NAME>

# Xem logs
kubectl logs -n job7189-apps deploy/<SERVICE_NAME> -c app --tail=50

# Kiểm tra credentials được inject
kubectl exec -n job7189-apps deploy/<SERVICE_NAME> -c app -- \
  grep -E "DB_USERNAME|DB_PASSWORD|LEASE_ID" /var/www/.env

# Test DB connection
kubectl exec -n job7189-apps deploy/<SERVICE_NAME> -c app -- /bin/sh -c '
USER=$(grep "^DB_USERNAME=" /var/www/.env | cut -d"=" -f2)
PASS=$(grep "^DB_PASSWORD=" /var/www/.env | cut -d"=" -f2)
DB="job7189_<SERVICE_NAME_DB>"
php -r "try { $p = new PDO(\"mysql:host=mysql.data.svc.cluster.local;dbname=$DB\", \"$USER\", \"$PASS\"); echo \"✅ DB Connection OK\n\"; } catch (Exception $e) { echo \"❌ Failed: \" . $e->getMessage() . \"\n\"; }"
'
```

---

## 📊 Version Management

### **Quy Tắc Versioning:**
- **Major.Minor.Patch** (v2.8.19)
- Tăng patch khi: bug fixes, minor improvements
- Tăng minor khi: features mới
- Tăng major khi: breaking changes

### **Cách Kiểm Tra Version Hiện Tại:**
```bash
# Cách 1: Từ file version
find src/<SERVICE> -name "version.json" -o -name ".version"

# Cách 2: Từ docker build output
docker inspect <IMAGE_ID> | grep -i version

# Cách 3: Từ git tag (nếu có)
git describe --tags
```

---

## ✅ Checklist Trước Deploy

- [ ] Source code updated & tested locally
- [ ] Version incremented (check Dockerfile hoặc .env)
- [ ] Docker build successful: `docker build -t <image> .`
- [ ] Docker push successful: `docker push <image>`
- [ ] Digest SHA256 lấy được
- [ ] Helm values file updated với digest mới
- [ ] Vault database role tồn tại: `vault list database/roles/`
- [ ] Deployment manifest sạch (no old pods)

---

## 🔧 Services To Deploy

```
1. workspace-service     (DB: job7189_workspace_db)
2. job-service          (DB: job7189_job_db)
3. hiring-service       (DB: job7189_hiring_db)
4. candidate-service    (DB: job7189_candidate_db)
5. communication-service (DB: job7189_communication_db)
6. storage-service      (DB: job7189_storage_db)
```

---

## 📝 Notes

- **env-loader sidecar**: Watches `/vault/secrets/.env` → copies to `/app-secrets/.env`
- **env-watcher sidecar**: Detects changes → triggers `supervisorctl restart laravel-service:*`
- **watch-env script**: Monitors `/app-secrets/.env` → copies to `/var/www/.env` → reload
- **Vault Agent**: Auto-renews credentials every ~10 minutes (TTL=15m, renewal at 2/3)
- **Zero-downtime**: Pod never crashes, just reloads env & restarts php-fpm

