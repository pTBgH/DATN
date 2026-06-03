# Upstream Service Test After CNP Fix

**Time:** $(date)
**Fix Applied:** Added port 8000 to allow-kong-ingress CNP

---

## Test Results

### Test 1: /api/health endpoint
**Command:** `curl http://localhost:18000/api/health`
```
TIMEOUT/ERROR
```

### Test 2: /api/public/jobs endpoint
```
TIMEOUT/ERROR
```
