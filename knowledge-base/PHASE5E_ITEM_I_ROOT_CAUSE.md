# Phase 5.E Item I: Kong 499 Upstream Timeout - Root Cause Analysis

**Date**: May 20, 2026  
**Status**: ROOT CAUSE IDENTIFIED & MITIGATION APPLIED  
**Severity**: Critical (blocks all public API endpoints)  

## Summary

Kong returns HTTP 499 (Client Timeout / Upstream Lost Connection) for `/api/health` and `/api/public/jobs` endpoints. Root cause identified as **Cilium Network Policy blocking intra-namespace Redis access**.

## Problem Statement

```
Kong Request Log:
127.0.0.1 - - [20/May/2026:09:48:37 +0000] "GET /api/health HTTP/1.1" 499 0
127.0.0.1 - - [20/May/2026:09:48:42 +0000] "GET /api/public/jobs HTTP/1.1" 499 0
```

**Observed Behavior**:
- Kong proxy receives requests for `/api/health` and `/api/public/jobs`
- Kong returns HTTP 499 (0 bytes response, complete timeout)
- Other endpoints like `/api/admin/users` work fine (HTTP 403 from OPA, expected)
- No errors in Kong logs, OPA logs, or upstream service logs

**Contrasting Evidence**:
- `/api/admin/users` returns 403 immediately (~180-600ms P50-P99, HTTP overhead)
- OPA responds quickly to health checks (<69ms)
- Kong routes exist in config (35 total routes loaded)
- identity-service and job-service pods running

## Root Cause Analysis

### Layer 1: Kong Route Configuration ✓
**Status**: Routes exist, properly configured
- `/api/health` → identity-service (no JWT plugin, public)
- `/api/public/jobs` → job-service (no JWT plugin, public)  
- Both routes in declarative config with correct service mapping

### Layer 2: OPA Authorization ✓
**Status**: OPA reachable, policies working
- OPA pod: 2/2 Ready in security namespace
- CNP policies allow Kong → OPA on port 8181
- OPA logs show health checks responding <70ms
- No authorization request logs (expected for public routes)

### Layer 3: Network Policy (Cilium CNP) ✗
**Status**: DEFAULT-DENY blocking intra-namespace traffic

**Critical Finding**:
The job7189-apps namespace has a `default-deny-all` CNP with **empty egress rules**:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-all
  namespace: job7189-apps
spec:
  egress: []
  endpointSelector:
    matchLabels: {}
```

This means:
- **NO outbound traffic allowed by default** in job7189-apps
- Explicit allow rules required for each egress path
- Existing `allow-egress-vault-db` CNP allows egress to:
  - Vault namespace (port 8200)
  - Data namespace (MySQL 3306, Redis 6379)
  - Security namespace (ports 80, 8080, 443)
- **BUT**: These rules allow egress to DIFFERENT namespaces only
- **Intra-namespace traffic** (app pod → redis pod in same namespace) is **blocked**

### Layer 4: Service Pod Status ✗
**Status**: App containers failing due to Redis connection timeout

**Evidence**:

```bash
$ kubectl get pod -n job7189-apps identity-service-* -o jsonpath='{...containerStatuses}'
- app: ready=false    ← MAIN APP NOT READY
- env-loader: ready=true
- env-watcher: ready=true
- vault-agent: ready=true
```

**App Container Logs Show**:
```
PhpRedisConnector.php line 181:
  Connection timed out at Redis->connect('identity-service-redis', '6379', ...)
```

**Root Cause Chain**:
1. App container tries to connect to Redis service "identity-service-redis:6379"
2. Cilium CNP `default-deny-all` intercepts outbound traffic on port 6379
3. No CNP rule allows intra-namespace port 6379 traffic
4. Connection refused/timeout
5. App readiness probe fails (waits for Redis to be available)
6. Pod shows "3/4 Ready" (app container not ready)
7. Kong tries to send traffic to identity-service
8. Service receives request but has no ready app container
9. Kong times out waiting for response → HTTP 499

## Solution Implemented

**Mitigation**: Added CNP rule to allow intra-namespace Redis access

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-internal-redis
  namespace: job7189-apps
spec:
  egress:
  - toEndpoints:
    - matchLabels:
        app.kubernetes.io/name: redis
        k8s:io.kubernetes.pod.namespace: job7189-apps
    toPorts:
    - ports:
      - port: "6379"
        protocol: TCP
  endpointSelector:
    matchLabels: {}
```

**Applied**: `kubectl apply -f` (CNP created successfully, policy validated)

## Verification Status

**Before**: HTTP 499 (complete timeout)
**After Mitigation**: HTTP 502 (Bad Gateway - app still initializing)
**Expected Final**: HTTP 200 or 200 (once app containers become ready with Redis access)

## Next Steps (Phase 5.E Continuation)

1. **Wait for pod restart**: New pods (identity-service-6f8dd54f66-k8n6m) will fully initialize
2. **Verify app readiness**: App containers should connect to Redis successfully
3. **Test endpoints**: `/api/health` and `/api/public/jobs` should return 200/403 (not 499)
4. **Load test**: Re-run Kong+OPA latency measurement with working backend
5. **Document findings**: Update Chapter 4 with corrected understanding

## Lessons Learned

1. **CNP default-deny-all requires explicit intra-namespace rules**
   - Namespace-scoped default-deny blocks all egress by default
   - Cross-namespace rules don't cover same-namespace traffic
   - Must explicitly allow pods within namespace to communicate

2. **Multi-layer troubleshooting needed**
   - Kong logs: healthy (499 is timeout, not error)
   - OPA logs: healthy (policy evaluation working)
   - Pod logs: reveal the real issue (Redis connection timeout)
   - Network policy audit: confirm traffic blocked

3. **Service readiness propagates failures**
   - Unready app container blocks entire service
   - Kong times out waiting for ANY ready endpoint
   - Multiple layers must be healthy end-to-end

4. **HTTP status codes as diagnostic tools**
   - 403: Authorization policy working (OPA reachable)
   - 502: Upstream issue (service not responding)
   - 499: Client timeout (request too slow or upstream down)
   - Progression from 499→502 indicates progress in troubleshooting

## Timeline

- **2026-05-20 10:00:00Z**: Investigation started, Kong 499 observed
- **2026-05-20 10:20:00Z**: Identified app container 3/4 ready
- **2026-05-20 10:23:00Z**: Found Redis connection timeout in app logs
- **2026-05-20 10:25:00Z**: Identified default-deny-all CNP as root cause
- **2026-05-20 10:25:57Z**: Applied allow-internal-redis CNP mitigation
- **2026-05-20 10:30:00Z**: Verified mitigation with 502 response
- **Expected 2026-05-20 11:00:00Z**: App containers ready, 200/403 responses working

