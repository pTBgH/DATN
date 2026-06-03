# Upstream Service Investigation — Item I (Phase 5.D)

**Date:** $(date)
**Objective:** Diagnose why `/api/health` and `/api/public/jobs` hang via Kong

---

## 1. Kong Route Configuration Check

### 1.1 List all routes via Kong admin API


### 1.2 Specific routes for /api/health and /api/public/jobs
```
{
  "name": "identity-health",
  "paths": [
    "/api/health"
  ],
  "service": {
    "id": "6d9819aa-b13d-535c-a128-d01a42ea02e4"
  },
  "upstream": null
}
{
  "name": "job-public",
  "paths": [
    "/api/public/jobs"
  ],
  "service": {
    "id": "0cde01b0-df77-5323-b663-d985d372803a"
  },
  "upstream": null
}
