# Lệnh Đúng & Sai - Quick Reference

## 🔴 LỖI BẠN VỪA GẶP

```bash
ptb@ptbsrv:~/project/DOAN2$ kubectl apply -f 04-build-and-push-images.sh
error: error validating "04-build-and-push-images.sh": error validating data: 
invalid object to validate; if you choose to ignore these errors, 
turn validation off with --validate=false
```

---

## ❌ SAI vs ✅ ĐÚNG

### Loại 1: Bash Scripts

| SAI ❌ | ĐÚNG ✅ | Ghi Chú |
|--------|---------|--------|
| `kubectl apply -f 04-build-and-push-images.sh` | `bash 04-build-and-push-images.sh` | Script bash, không YAML |
| `kubectl apply -f 03-deploy-microservices.sh` | `bash 03-deploy-microservices.sh` | Script bash, không YAML |
| `kubectl apply -f *.sh` | `bash *.sh` | Tất cả .sh files |

**Lý do:** `kubectl apply` chỉ hiểu Kubernetes YAML, không hiểu bash scripts.

---

### Loại 2: Kubernetes YAML Files

| SAI ❌ | ĐÚNG ✅ | File |
|--------|---------|------|
| `bash infras/k8s-yaml/12-docker-registry.yaml` | `kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml` | YAML config |
| `bash infras/k8s-yaml/02-keycloak.yaml` | `kubectl apply -f infras/k8s-yaml/02-keycloak.yaml` | YAML config |
| `bash *.yaml` | `kubectl apply -f *.yaml` | Tất cả .yaml files |

**Lý do:** `kubectl apply` nhận Kubernetes YAML để deploy resources.

---

### Loại 3: Docker Compose Files

| SAI ❌ | ĐÚNG ✅ | Ghi Chú |
|--------|---------|--------|
| `kubectl apply -f infras/local-registry/docker-compose.yml` | `docker-compose -f infras/local-registry/docker-compose.yml up -d` | Docker Compose |
| `bash docker-compose.yml` | `docker-compose up -d` | Docker Compose |
| `kubectl apply -f docker-compose.yml` | `docker-compose down` | Dừng services |

**Lý do:** `docker-compose` là công cụ riêng, không phải `kubectl`.

---

## 📋 Cheat Sheet - Dùng Cái Nào?

### 🐳 Bash Scripts (.sh)
```bash
bash script-name.sh
bash 03-deploy-microservices.sh
bash 04-build-and-push-images.sh
```

### ☸️ Kubernetes Configs (.yaml/.yml)
```bash
kubectl apply -f config.yaml
kubectl apply -f infras/k8s-yaml/
kubectl get pod        # kiểm tra kết quả
```

### 🐝 Docker Compose (.yml)
```bash
docker-compose up -d        # start services
docker-compose down         # stop services
docker-compose logs -f      # view logs
```

---

## 📝 File Types Trong Project

### Bash Scripts (→ `bash` command)
```
03-deploy-microservices.sh      ← bash lệnh này
04-build-and-push-images.sh     ← bash lệnh này
01-setup-cluster.sh             ← bash lệnh này
02-deploy-infrastructure.sh     ← bash lệnh này
get-keycloak-token.sh           ← bash lệnh này
setup-keycloak-clients.sh       ← bash lệnh này
system-health-check.sh          ← bash lệnh này
```

### Kubernetes Configs (→ `kubectl apply` command)
```
infras/k8s-yaml/01-mysql-phpmyadmin.yaml     ← kubectl apply -f lệnh này
infras/k8s-yaml/02-keycloak.yaml             ← kubectl apply -f lệnh này
infras/k8s-yaml/03-kafka.yaml                ← kubectl apply -f lệnh này
infras/k8s-yaml/12-docker-registry.yaml      ← kubectl apply -f lệnh này
infras/k8s-yaml/99-ingress.yaml              ← kubectl apply -f lệnh này
```

### Docker Compose (→ `docker-compose` command)
```
infras/local-registry/docker-compose.yml    ← docker-compose up -d lệnh này
Structurizr/docker-compose.yml              ← docker-compose up -d lệnh này
```

---

## 🎯 Deployment Flow (Đúng Cách)

```bash
# Step 1: Setup cluster (bash script)
bash 01-setup-cluster.sh

# Step 2: Deploy infrastructure (bash script)
bash 02-deploy-infrastructure.sh

# Step 3: Deploy microservices (bash script)
bash 03-deploy-microservices.sh
  └─ Gọi 04-build-and-push-images.sh (bash script)

# KHÔNG CẦN chạy thủ công:
# ❌ kubectl apply -f 03-deploy-microservices.sh
# ❌ kubectl apply -f 04-build-and-push-images.sh
# ✅ bash 03-deploy-microservices.sh (script xử lý tất cả)
```

---

## ✅ Correct Commands for Your Project

```bash
# 1. Setup cluster
bash 01-setup-cluster.sh

# 2. Deploy infrastructure 
bash 02-deploy-infrastructure.sh

# 3. Deploy microservices
bash 03-deploy-microservices.sh        # ← TỪ ĐÂY TRỞ ĐI
  # Interior script sẽ:
  # - Start docker-compose registry
  # - Call 04-build-and-push-images.sh
  # - Deploy via helmfile

# 4. Check status
kubectl get pod -A
kubectl get services -A
kubectl logs -n job7189-apps -f

# 5. Access registry UI
open http://localhost:8088

# 6. Access services (port-forward or use ingress)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &
# Then access: http://localhost:8080
```

---

## 🧪 Quick Test

```bash
# Test: Bash script OK?
bash -n 04-build-and-push-images.sh     # Syntax check, no execute
echo $?  # Should be 0 (OK)

# Test: YAML valid?
kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml --dry-run=client

# Test: Docker compose working?
docker-compose -f infras/local-registry/docker-compose.yml config | head
```

---

## 📚 Summary

| File Type | Command | Tool | Example |
|-----------|---------|------|---------|
| `.sh` (Bash) | `bash` | bash shell | `bash 03-deploy-microservices.sh` |
| `.yaml/.yml` (K8s) | `kubectl apply -f` | kubectl | `kubectl apply -f 12-docker-registry.yaml` |
| `docker-compose.yml` | `docker-compose` | docker-compose | `docker-compose up -d` |

---

## 🎓 Remember

- **Shell Scripts (.sh)** → Run with `bash`
- **Kubernetes Configs (.yaml)** → Deploy with `kubectl apply -f`
- **Docker Compose (.yml)** → Manage with `docker-compose`

**Mixing them up = Errors!**

