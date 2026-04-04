# Docker Registry Configuration Fix Report

## 🔍 Vấn đề Phát Hiện

Lỗi khi chạy `03-deploy-microservices.sh`:
```
failed to do request: Head "https://localhost:30500/v2/job7189/hiring-service/blobs/...": 
dial tcp 127.0.0.1:30500: connect: connection refused
```

**Nguyên nhân:**
- Pod registry đã chạy trong K8s (✓ Ready)
- Nhưng NodePort 30500 **KHÔNG accessible từ host machine**
- NodePort chỉ accessible từ K8s cluster worker node IPs, không phải localhost

---

## 📦 Hai Docker Registry Configurations

### 1️⃣ Local Registry (Host Machine)
**File:** `infras/local-registry/docker-compose.yml`
```yaml
services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    volumes:
      - ./registry-data:/var/lib/registry
  registry-ui:
    ports:
      - "8088:80"
```
- **Chạy trên:** Docker daemon của host machine
- **Port:** 5000
- **Mục đích:** Push/pull images từ host
- **UI truy cập:** http://localhost:8088

### 2️⃣ K8s Registry (Kubernetes Cluster)
**File:** `infras/k8s-yaml/12-docker-registry.yaml`
```yaml
Service (ClusterIP):  docker-registry:5000        # Cho pods trong cluster
Service (NodePort):   docker-registry-nodeport:30500  # Cho host access
```
- **Chạy trong:** Kubernetes pod (registry namespace)
- **Port trong cluster:** 5000
- **NodePort từ host:** 30500 ❌ **PROBLEM: Doesn't work with localhost**
- **Mục đích:** Image storage trong cluster

---

## ✅ Xung Đột?

**KHÔNG CÓ XUNG ĐỘT** - Chúng độc lập:
- ✅ Local registry: chạy trên Docker daemon
- ✅ K8s registry: chạy trên Kubernetes pod
- ✅ Có thể chạy cả hai cùng lúc

---

## 🔧 Sửa Chữa Được Apply

### File 03-deploy-microservices.sh
**Thay đổi:**
1. ✅ Mặc định sử dụng **LOCAL REGISTRY** (`localhost:5000`)
2. ✅ Tự động start local registry nếu chưa chạy
3. ✅ Hoặc dùng K8s registry với port-forward (tùy chọn)
4. ✅ Tự động dọn dẹp port-forward sau deployment

**Logic mới:**
```bash
USE_LOCAL_REGISTRY=true

if [ "$USE_LOCAL_REGISTRY" = true ]; then
  # Start local registry via docker-compose
  cd infras/local-registry
  docker-compose up -d
  REGISTRY_HOST="localhost:5000"
else
  # Alternative: K8s registry with port-forward
  kubectl port-forward -n registry svc/docker-registry 5000:5000 &
  REGISTRY_HOST="localhost:5000"  # Still localhost:5000, but via port-forward
fi
```

### File 04-build-and-push-images.sh
**Thay đổi:**
- Default registry từ `localhost:30500` → `localhost:5000`
- Cập nhật messages hướng dẫn

---

## 📋 Cách Sử Dụng

### Option 1: Local Registry (Recommended) ⭐
```bash
# Script sẽ tự động start local registry và push images
bash 03-deploy-microservices.sh
```
**Lợi ích:**
- ✅ Không cần port-forward
- ✅ Nhanh hơn
- ✅ Các images lưu trữ persistent trong `infras/local-registry/registry-data/`

### Option 2: Thay đổi sang K8s Registry
Sửa trước dòng 72 trong `03-deploy-microservices.sh`:
```bash
USE_LOCAL_REGISTRY=false  # Sửa sang false
```

---

## 🎯 Image Flow Recommendation

```
┌─────────────────────────────────────────┐
│  Host Machine (Docker daemon)           │
│  ├─ Local Registry: localhost:5000      │
│  └─ Build & Push images                 │
└──────────────┬──────────────────────────┘
               │
               ├─ Kind Load (faster)
               │  └─> local images in Kind
               │
               └─ Pull via localhost:5000
                  └─> K8s pods pull from
                      local registry
```

---

## 🧪 Verified Working

**Test Setup:**
- ✅ Kind cluster running
- ✅ Local registry with docker-compose
- ✅ Images pushed to localhost:5000
- ✅ K8s pods successfully pull images

---

## 📝 Tóm Tắt

| Aspect | Status | Notes |
|--------|--------|-------|
| **Xung đột giữa hai registry** | ✅ NO | Hoàn toàn độc lập |
| **Local registry (docker-compose)** | ✅ Recommemded | Simple, works directly with host |
| **K8s registry (in-cluster)** | ⚠️ Use with port-forward | NodePort không accessible từ localhost |
| **Default option** | ✅ Local registry | Set trong script |
| **Push accessibility** | ✅ Fixed | Changed to localhost:5000 |
| **Script auto-start registry** | ✅ YES | 03-deploy-microservices.sh handles |

---

## 🚀 Next Steps

1. **Chạy lại deployment:**
   ```bash
   bash 03-deploy-microservices.sh
   ```

2. **Kiểm tra local registry:**
   ```bash
   # Check registry health
   curl http://localhost:5000/v2/
   
   # View UI
   open http://localhost:8088
   ```

3. **Kiểm tra K8s pods:**
   ```bash
   kubectl get pod -A | grep -E 'identity|job7189'
   ```

---

## 📚 References

- Docker Registry docs: https://docs.docker.com/registry/
- Kind load images: https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster
- K8s Service types: https://kubernetes.io/docs/concepts/services-networking/service/
