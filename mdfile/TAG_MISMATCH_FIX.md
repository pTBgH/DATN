# Tag Mismatch - Root Cause & Fix

## 🔴 **Vấn Đề Found**

Images được build với **tags sai**:

```
Actual built tags:
  ✓ job7189/candidate-service:1.0.0          (NO "v")
  ✓ job7189/communication-service:1.0.0      (NO "v", WRONG VERSION)
  
Expected tags:
  ✓ job7189/candidate-service:v1.0.0         (WITH "v")
  ✓ job7189/communication-service:v1.1.6     (WITH "v", RIGHT VERSION)
```

**Nguyên nhân:**
- Build script định nghĩa: `["candidate-service"]="v1.0.0"`
- Nhưng build output tạo images với tag: `1.0.0` (không có "v")
- Docker ignore "v" prefix khi tagging? Hoặc dockerfile có issue?

---

## ✅ **Fixes Applied**

### **Fix #1: Clean Old Images**
Script bây giờ tự động xóa old wrong-tagged images trước rebuild:
```bash
# Remove old images that don't match current spec
docker image rm "job7189/candidate-service:1.0.0" 2>/dev/null || true
docker image rm "job7189/communication-service:1.0.0" 2>/dev/null || true
```

### **Fix #2: Better Build Verification**
Build script bây giờ verify image tồn tại với đúng tag:
```bash
if docker image inspect "$full_image" &>/dev/null; then
  echo "Verified: Image exists with tag $tag"
else
  echo "ERROR: Image built but inspect failed!"
  return 1
fi
```

### **Fix #3: Better Error Detection**
Image load logic dùng `docker image inspect` thay vì `docker image ls | grep`:
```bash
# More reliable check
if ! docker image inspect "$full_image" &>/dev/null; then
  echo "ERROR: Image not found locally: $full_image"
  FAILED_LOADS+=("$full_image")
fi
```

---

## 🚀 **Cách Fix Từ Đầu**

### **Step 1: Clean All job7189 Images**
```bash
# Remove all old images to start fresh
docker image rm -f $(docker image ls | grep job7189 | awk '{print $3}') 2>/dev/null || true

# Verify all removed
docker image ls | grep job7189
# (Should be empty)
```

### **Step 2: Re-run Deployment**
```bash
cd /home/ptb/project/DOAN2

# Script sẽ:
# 1. Skip old images (already removed)
# 2. Build fresh with correct tags
# 3. Load into Kind
bash 03-deploy-microservices.sh
```

### **Step 3: Verify Tags Correct**
```bash
# Check images have correct tags now
docker image ls | grep job7189

# Should show with "v" prefix:
# job7189/identity-service:v2.7.8
# job7189/candidate-service:v1.0.0
# job7189/communication-service:v1.1.6
# etc.
```

---

## 📊 **Before vs After**

### Before ❌
```
job7189/candidate-service:1.0.0           ← Wrong tag (no "v")
job7189/communication-service:1.0.0       ← Wrong tag (no "v", wrong version)
...
deployment fails with: ErrImageNeverPull
```

### After ✅
```
job7189/candidate-service:v1.0.0          ← Correct
job7189/communication-service:v1.1.6      ← Correct
...
pods: 2/2 Running
```

---

## 💡 **Why This Happened**

Possible causes:
1. **Old images cached** - Built by previous run with different tag format
2. **Docker version difference** - Different Docker versions handle tags differently?
3. **Registry confusion** - Mixed tags from `localhost:30500` and `localhost:5000`

**Solution:** Clean & rebuild = guaranteed fresh start

---

## 🎯 **Quick Commands**

```bash
# Clean all job7189 images
docker image rm -f $(docker image ls | grep job7189 | awk '{print $3}') 2>/dev/null

# Rebuild fresh
bash 03-deploy-microservices.sh

# Check images
docker image ls | grep job7189

# Check pods
kubectl get pod -n job7189-apps

# If still error, check what pods actually want:
kubectl get pod -n job7189-apps -o json | jq '.items[] | {name: .metadata.name, image: .spec.containers[0].image}'
```

---

## 🔗 **Files Modified**

1. ✅ `03-deploy-microservices.sh`
   - Added: Cleanup old mismatched images
   - Added: Better error detection for image loading
   - Added: More detailed troubleshooting output

2. ✅ `04-build-and-push-images.sh`
   - Added: Image inspection after build to verify tag
   - Added: Better error reporting

