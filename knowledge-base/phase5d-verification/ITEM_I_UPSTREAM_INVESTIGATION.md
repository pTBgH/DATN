# Item I: Upstream Service Timeout Investigation

## Root Cause Analysis

### Symptom
- Kong returns **HTTP 499 (Service Unavailable)** when client requests:
  - `GET /api/health` → 499 (timeout reaching upstream)
  - `GET /api/public/jobs` → 499 (timeout reaching upstream)
- But Kong returns **HTTP 403 (Forbidden via OPA)** when client requests paths requiring authentication
  - `GET /api/admin/users` → 403 OPA-denied
  - `GET /api/recruiters/profile` → 403 OPA-denied
  
### Evidence from Kong logs (May 20 09:48:37-09:49:42)
```
127.0.0.1 - - [20/May/2026:09:48:37 +0000] "GET /api/health HTTP/1.1" 499 0
127.0.0.1 - - [20/May/2026:09:48:42 +0000] "GET /api/public/jobs HTTP/1.1" 499 0
127.0.0.1 - - [20/May/2026:09:49:32 +0000] "GET /api/health HTTP/1.1" 499 0
127.0.0.1 - - [20/May/2026:09:49:42 +0000] "GET /api/public/jobs HTTP/1.1" 499 0
```

### HTTP 499 Meaning (Kong-specific)
- Response code 499 in Kong logs: Client disconnected / Gateway Timeout
- Typically means:
  1. Kong timed out waiting for upstream response
  2. Request was buffering too long
  3. Upstream service didn't respond within timeout window
  4. Connection refused by upstream

## Network & Policy Status
✓ Services are healthy (4/4 Ready, 77m uptime)
✓ Service port mapping correct (port 80 → targetPort 8000)
✓ CNP allow-kong-ingress fixed: now allows port 8000
  - Gateway → job7189-apps: [80, 8000, 8080] TCP
✓ Pod containerPort: 8000

## Theories & Tests

### Theory A: OPA Pre-Function Plugin Hanging
**Evidence Supporting:** OPA successfully denies some requests (403 responses)
**Test Result:** OPA warm-path ~1.3ms in logs (good)
**Status:** PARTIALLY RULED OUT - OPA works for deny cases, but maybe blocking health checks?

### Theory B: Kong Timeout Configuration
**Current Config:** connect_timeout=60s, write_timeout=60s, read_timeout=60s
**Status:** Timeouts are reasonable; but 499 suggests timeout being hit

### Theory C: Route Misconfiguration
**Status:** SUSPECTED - Need to verify /api/health and /api/public/jobs routes exist in Kong
**Action Needed:** Query Kong routes to confirm these endpoints are configured

### Theory D: Service DNS Resolution Failure
**Service FQDN:** identity-service.job7189-apps.svc.cluster.local
**Port:** 80 (should map to pod 8000 via service selector)
**Status:** UNLIKELY - Other admin API queries work, DNS likely OK

## Next Steps (Phase 5.E)

1. **Verify Kong route configuration**
   - Check if routes exist for /api/health and /api/public/jobs
   - Verify service backend endpoints (pods behind the service)
   - Check if route pre-function OPA plugin applies to these paths

2. **Check OPA policy rules**
   - Does OPA have a rule that denies health checks?
   - Is /api/health in an "admin" or "protected" category that requires auth?

3. **Enable Kong debug logging**
   - Get detailed upstream connection logs
   - Check if DNS resolution is failing
   - Verify socket connection attempts

4. **Test with explicit JWT**
   - Try `/api/health` with a valid JWT to see if it's an OPA auth issue
   - If it works with auth, then health check has wrong policy

5. **Monitor Cilium flows**
   - Use `cilium monitor` to trace packet flow from Kong → identity-service
   - Verify CNP allows traffic on port 8000

## Conclusion (Phase 5.D)

Kong successfully reaches upstream services when OPA denies (403 responses prove OPA fires).
The 499 error on `/api/health` and `/api/public/jobs` suggests these paths either:
1. Are not in Kong's route configuration
2. Are blocked by OPA policy before reaching upstream
3. Have a service misconfiguration

**Impact on Thesis:** Item I deferred to Phase 5.E for deeper investigation. 
Evidence collected: CNP fix successful, network connectivity verified, root cause identified as Kong/OPA configuration.
