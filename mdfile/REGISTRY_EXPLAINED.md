# Docker Registry - Thừa Hay Không?

## 🎯 Câu Trả Lời Trực Tiếp

**Có, bạn hiện tại đang cài 2 registries, nhưng KHÔNG phải sử dụng cả hai.**

---

## 📊 Two Registry Setups

### Setup 1️⃣: Local Registry (Docker Compose)
```
Location: infras/local-registry/
├─ registry:2                        [Port 5000]
├─ registry-ui (joxit)               [Port 8088]
└─ Persistent storage: ./registry-data

Chạy: docker-compose up -d
Access từ host: localhost:5000
Access từ K8s: localhost:5000 (thông qua host bridge)
```

**Đặc điểm:**
- ✅ Chạy trên host machine (Docker daemon)
- ✅ Không phụ thuộc Kubernetes
- ✅ Đơn giản, nhanh
- ✅ **Đúng loại cho development**

---

### Setup 2️⃣: K8s Registry (Native Kubernetes)
```
Location: infras/k8s-yaml/12-docker-registry.yaml
├─ Deployment: docker-registry pod [Port 5000]
├─ Service ClusterIP               [Port 5000]
├─ Service NodePort                [Port 30500] ❌ BROKEN
└─ PVC: 50Gi storage

Chạy: kubectl apply -f 12-docker-registry.yaml
Access từ cluster: docker-registry.registry.svc.cluster.local:5000
Access từ host: localhost:30500 (NodePort) ❌ KHÔNG WORK
```

**Đặc điểm:**
- ⚠️ Chạy bên trong K8s cluster
- ⚠️ Phụ thuộc NodePort (không accessible từ host)
- ⚠️ Phức tạp, cần port-forward
- ❌ **Không phù hợp cho development**

---

## ❓ CÓ XUNG ĐỘT?

```
Local Registry        K8s Registry
(localhost:5000)      (registry namespace)
    ✅                     ❌
  HOẠT ĐỘNG        KHÔNG HOẠT ĐỘNG
     GỌI                   từ HOST
 TỪCHỈ DEPLOYMENT
```

**Kết luận:** 
- ✅ **KHÔNG xung đột** - chúng chạy ở 2 chỗ khác nhau
- ❌ **LÀ THỪA** - K8s registry không cần thiết cho dev/test

---

## 🧹 GIẢI PHÁP: Bỏ K8s Registry

**File:** `infras/k8s-yaml/12-docker-registry.yaml` 

**Lựa chọn:**

### Option A: XÓA hoàn toàn (Recommended)
```bash
# Xóa file YAML (bỏ K8s registry)
rm infras/k8s-yaml/12-docker-registry.yaml

# Script mới sẽ chỉ dùng local registry
bash 03-deploy-microservices.sh
```

### Option B: Để nhưng không dùng
```bash
# Giữ file nhưng không deploy
# Script mới sẽ ignore K8s registry
bash 03-deploy-microservices.sh
```

---

## ✅ Sửa Chữa Đã Apply

### File: `03-deploy-microservices.sh`

**Thay đổi:**
```bash
# ❌ CŨ: Có option chọn USE_LOCAL_REGISTRY=true/false
# ✅ MỚI: Chỉ dùng LOCAL REGISTRY, bỏ K8s registry hoàn toàn

echo "? Using LOCAL REGISTRY for image management..."
cd infras/local-registry
docker-compose up -d
REGISTRY_HOST="localhost:5000"
```

**Lợi ích:**
- ✅ Bỏ deployment K8s registry (tiết kiệm resources)
- ✅ Bỏ port-forward complexity
- ✅ Push/pull images trực tiếp từ localhost:5000
- ✅ Script đơn giản, dễ maintain

---

## 📋 Cách Sử Dụng Đúng

### ✅ Chạy Deployment
```bash
cd /home/ptb/project/DOAN2

# Script sẽ:
# 1. Start local registry (docker-compose)
# 2. Build images
# 3. Push to localhost:5000
# 4. Load into Kind cluster
bash 03-deploy-microservices.sh
```

### ✅ Kiểm Tra Registry
```bash
# Check container running
docker ps | grep local-registry

# Check images in registry
curl http://localhost:5000/v2/_catalog | jq .

# Check UI
curl http://localhost:8088

# Or open browser
open http://localhost:8088
```

### ✅ Dừng/Restart Registry
```bash
cd infras/local-registry

# Stop
docker-compose down

# Restart
docker-compose up -d
```

---

## 🎯 Architecture Diagram (New)

```
┌─────────────────────────────────────────────────────┐
│            Host Machine (Docker)                    │
│  ┌─────────────────────────────────────────────────┐│
│  │  Docker Registry (docker-compose)               ││
│  │  ├─ registry:2          ← Port 5000            ││
│  │  ├─ registry-ui:static  ← Port 8088            ││
│  │  └─ Storage: registry-data/                    ││
│  └─────────────────────────────────────────────────┘│
│         │                                           │
│         ├─ docker build & push                     │
│         └─ kind load docker-image                 │
│                                                     │
│  ┌─────────────────────────────────────────────────┐│
│  │  Docker Daemon                                  ││
│  │  ├─ Local images                               ││
│  │  └─ Kind cluster integration                   ││
│  └─────────────────────────────────────────────────┘│
│                                                     │
└──────────────────┬──────────────────────────────────┘
                   │
         ┌─────────▼──────────┐
         │   Kind Cluster     │
         ├─────────────────────┤
         │ job7189-apps (ns)  │
         ├─ identity-service  │
         ├─ job-service       │
         ├─ hiring-service    │
         ├─ candidate-service │
         ├─ etc...            │
         │                    │
         │ Pods pull images   │
         │ from loaded cache  │
         └─────────────────────┘

❌ K8s Registry (bỏ - không cần)
```

---

## 📝 Summary

| Aspect | Local Registry | K8s Registry | Decision |
|--------|----------------|--------------|----------|
| **Vị trí** | Host machine | K8s pod | Host = Simple ✅ |
| **Port** | 5000 (works) | 30500 (broken) | 5000 = Works ✅ |
| **Push from host** | ✅ Direct | ⚠️ Via port-forward | Direct = Better ✅ |
| **Nested setup complexity** | ✅ Low | ⚠️ High | Low = Prefer ✅ |
| **Cần dùng?** | ✅ YES | ❌ NO | Chỉ dùng Local ✅ |
| **Xung đột?** | ✅ NO | ✅ NO | Độc lập, không xung ✅ |

---

## 🚀 Next Steps

1. **Xác nhận:**
   ```bash
   # Local registry should be running
   docker ps | grep local-registry
   ```

2. **Cơ bản:** Nếu K8s registry YAML còn, xóa nó:
   ```bash
   rm infras/k8s-yaml/12-docker-registry.yaml
   ```

3. **Chạy deployment:**
   ```bash
   bash 03-deploy-microservices.sh
   ```

4. **Verify:**
   ```bash
   # Check pods
   kubectl get pod -A | grep -E 'identity|job|hiring'
   
   # Check logs
   kubectl logs -n job7189-apps <pod-name>
   ```

---

## ❓ FAQs

**Q: Có thể chạy cả 2 registry không?**
> Có thể, nhưng không cần thiết. Local registry đủ cho dev/test. K8s registry chỉ hữu dụng nếu bạn muốn image storage bên trong K8s (production scenario).

**Q: Tại sao K8s registry không work từ host?**
> NodePort chỉ accessible từ K8s node IPs, không phải localhost. Để dùng được phải port-forward.

**Q: Nếu xóa K8s registry YAML, pods sẽ sao?**
> Không ảnh hưởng. Pods pull images từ local registry (khi load vào Kind cluster) hoặc cache. K8s registry hoàn toàn optional.

**Q: Local registry data lưu ở đâu?**
> `infras/local-registry/registry-data/` - persistent volume trên host.

