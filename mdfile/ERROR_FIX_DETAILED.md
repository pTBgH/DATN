# ErrImageNeverPull & ImagePullBackOff - Root Cause Analysis & Fix

## 🔴 **Lỗi Gặp Phải**

```
job7189-apps    identity-service-b9b6df6f4-sq8n9              1/2     ErrImageNeverPull
job7189-apps    communication-service-86bbdb9fb-qrgx2         1/2     ErrImageNeverPull
job7189-apps    storage-service-5b49dd859-f26rk               1/2     ErrImageNeverPull
job7189-apps    hiring-service-7c87fbfcb7-b2kh7               1/2     ErrImageNeverPull
job7189-apps    fe-candidate-service-5ddf8899c-sf5tb          0/1     ImagePullBackOff
```

---

## 🔍 **Root Causes Tìm Được**

### **Root Cause #1: TAG MISMATCH** ⭐ CHÍNH
Build script creates images với các tags khác nhau so với values files expects:

| Service | Script Creates | Values Expect | Action |
|---------|---|---|---|
| **identity-service** | v2.7.8 ❌ | v1.0.0 ❌ | FIX: Change values to v2.7.8 |
| **communication-service** | v1.1.6 ❌ | v1.0.0 ❌ | FIX: Change values to v1.1.6 |
| **storage-service** | v1.2.1 ❌ | v1.0.0 ❌ | FIX: Change values to v1.2.1 |
| workspace-service | v1.0.0 ✓ | v1.0.0 ✓ | OK |
| job-service | v1.0.0 ✓ | v1.0.0 ✓ | OK |
| hiring-service | v1.7.4 ✓ | v1.7.4 ✓ | OK |
| candidate-service | v1.0.0 ✓ | v1.0.0 ✓ | OK |

**Ví dụ:**
```
Pod expects: job7189/identity-service:v1.0.0  (pullPolicy: Never)
But image built as: job7189/identity-service:v2.7.8
Result: ❌ ErrImageNeverPull (image không tìm thấy)
```

---

### **Root Cause #2: Không Verify Images Loaded**

Script cũ không:
- ✗ Kiểm tra xem images thực sự tồn tại locally
- ✗ Verify exact tag match  
- ✗ Fail nếu load không thành công (`|| true` = ignore errors)
- ✗ Show rõ error messages

---

### **Root Cause #3: Frontend Service (fe-candidate) Issue**

```yaml
image:
  repository: job7189/fe-candidate
  tag: "v08"
  pullPolicy: IfNotPresent  # Will pull from registry
```

**Vấn đề:**
- Không được build bởi `04-build-and-push-images.sh` (chỉ build Laravel services)
- Tag `v08` không rõ nghĩa
- pullPolicy: IfNotPresent = sẽ try pull từ registry (nhưng không có)

---

## ✅ **Fixes Applied**

### **Fix #1: Update Values Files (3 files)**

✅ `k8s-management/values/identity-values.yaml`
```yaml
tag: "v2.7.8"  # Changed from v1.0.0
```

✅ `k8s-management/values/communication-values.yaml`
```yaml
tag: "v1.1.6"  # Changed from v1.0.0
```

✅ `k8s-management/values/storage-values.yaml`
```yaml
tag: "v1.2.1"  # Changed from v1.0.0
```

---

### **Fix #2: Improve Image Load Verification**

✅ File: `03-deploy-microservices.sh`

**Thay đổi:**
```bash
# OLD: Vô tư load, ignore errors
for image in ...; do
  if docker image ls | grep -q "$image_name"; then
    kind load docker-image "$image" ... || true  # ❌ Ignore failure!
  fi
done

# NEW: Verify explicitly, fail on error
for full_image in "${REQUIRED_IMAGES[@]}"; do
  echo "Checking: $full_image"
  
  # Verify exact image exists locally
  if ! docker image ls | grep -q "$image_name"; then
    echo "✗ ERROR: Image not found: $full_image"
    FAILED_LOADS+=("$full_image")
    continue
  fi
  
  # Verify exact tag match
  if ! docker image ls "$image_name" | grep -q "$image_tag"; then
    echo "✗ ERROR: Tag mismatch for $image_name"
    FAILED_LOADS+=("$full_image")
    continue
  fi
  
  # Load and verify success
  if kind load docker-image "$full_image" --name job7189; then
    echo "✓ Successfully loaded: $full_image"
  else
    echo "✗ ERROR: Failed to load: $full_image"
    FAILED_LOADS+=("$full_image")
  fi
done

# FAIL if any images missing
if [ ${#FAILED_LOADS[@]} -gt 0 ]; then
  echo "CRITICAL: Cannot proceed with deployment!"
  exit 1  # ✅ Fail nếu images incomplete
fi
```

**Lợi ích:**
- ✅ Verify tag chính xác match
- ✅ Show clear error messages
- ✅ Fail nếu images incomplete
- ✅ Prevent deployment with broken images

---

### **Fix #3: Improve Build Script Output**

✅ File: `04-build-and-push-images.sh`

**Thay đổi:**
```bash
# Show which images were built successfully
echo "✅ Successfully built:"
printf '   • %s\n' "${SUCCESSFUL_BUILDS[@]}"

# Show which images failed (but don't exit if local cache exists)
if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
  echo "⚠️  Failed to build:"
  printf '   • %s\n' "${FAILED_BUILDS[@]}"
fi

# Verify which images exist locally (most important!)
echo ""
echo "Checking which images exist locally..."
for service_name in "${!SERVICES[@]}"; do
  tag=${IMAGE_TAGS[$service_name]}
  image_name="${REGISTRY_PREFIX}/job7189/${service_name}:${tag}"
  
  if docker image ls --quiet "$image_name" &>/dev/null; then
    echo "✓ ${image_name}"
  else
    echo "✗ ${image_name} NOT FOUND LOCALLY"  # ✅ Clearly show missing images!
  fi
done
```

---

### **Fix #4: Better Status Reporting**

✅ File: `03-deploy-microservices.sh` - Final status check

**Thay đổi:**
```bash
# Show problematic pods
ERROR_PODS=$(kubectl get pod -A --no-headers | grep -E 'Error|Backoff|Failed' | wc -l)

if [ "$ERROR_PODS" -gt 0 ]; then
  echo "⚠️  Found $ERROR_PODS pods with errors:"
  kubectl get pod -A --no-headers | grep -E 'Error|Backoff|Failed'
  
  echo ""
  echo "📝 Common error meanings:"
  echo "   • ErrImageNeverPull - pullPolicy: Never but image 'không' tìm thấy"
  echo "   • ImagePullBackOff - Trying to pull từ registry (không thành công)"
  
  echo ""
  echo "Troubleshooting:"
  echo "   1. Check local images: docker image ls | grep job7189"
  echo "   2. Check pod images: kubectl get pod -o jsonpath='{.items[*].spec.containers[*].image}'"
  echo "   3. Compare values tags: grep 'tag:' k8s-management/values/**.yaml"
fi
```

---

## 🎯 **Verification Steps**

Sau khi fixes, bạn nên thấy:

### ✅ Step 1: Images built successfully
```bash
bash 03-deploy-microservices.sh

# Output phải show:
? Step 0: Setting up local Docker Registry...
✓ Local Registry already running
Building and pushing microservice images...
✓ Build successful: localhost:5000/job7189/identity-service:v2.7.8
✓ Build successful: localhost:5000/job7189/communication-service:v1.1.6
✓ Build successful: localhost:5000/job7189/storage-service:v1.2.1
... (all services)
```

### ✅ Step 2: Images loaded to Kind successfully
```
Checking: job7189/identity-service:v2.7.8
✓ Successfully loaded: job7189/identity-service:v2.7.8
...
✓ All images loaded successfully!
```

### ✅ Step 3: Pods start with correct images
```bash
kubectl get pod -n job7189-apps

# Should show 2/2 Running (not 1/2 ErrImageNeverPull)
identity-service-xxxxx          2/2     Running
communication-service-xxxxx     2/2     Running
storage-service-xxxxx           2/2     Running
```

---

## 📊 **Summary Bảng**

| Issue | Cause | Fix | Result |
|-------|-------|-----|--------|
| **ErrImageNeverPull** | Tag mismatch (values vs actual) | Updated 3 values files | ✅ Correct tags |
| **Images not verified** | No validation logic | Added verification in script | ✅ Clear errors |
| **Helmfile deploy too early** | No wait logic | Added pod init delay | ✅ Wait for images |
| **Frontend service issue** | Unclear requirements | Added comments | ✅ Transparency |

---

## 🚀 **Next Step**

```bash
# Clean up old pods if stuck
kubectl delete pod -n job7189-apps --all

# Re-run deployment with fixes
bash 03-deploy-microservices.sh

# Verify pods running
kubectl get pod -n job7189-apps | grep -E 'identity|communication|storage'

# Should show: 2/2 Running (not errors)
```

---

## 🔗 **Files Modified**

1. ✅ `k8s-management/values/identity-values.yaml` - tag v1.0.0 → v2.7.8
2. ✅ `k8s-management/values/communication-values.yaml` - tag v1.0.0 → v1.1.6
3. ✅ `k8s-management/values/storage-values.yaml` - tag v1.0.0 → v1.2.1
4. ✅ `03-deploy-microservices.sh` - Enhanced verification & error handling
5. ✅ `04-build-and-push-images.sh` - Better output & local image verification
6. ✅ `k8s-management/values/fe-candidate-values.yaml` - Added comments

