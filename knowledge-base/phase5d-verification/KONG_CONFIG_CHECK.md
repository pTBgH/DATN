# Kong Route Configuration Analysis

## 1. Check if /api/health route exists
{
  "path_handling": "v0",
  "regex_priority": 0,
  "service": {
    "id": "6d9819aa-b13d-535c-a128-d01a42ea02e4"
  },
  "hosts": null,
  "destinations": null,
  "methods": null,
  "strip_path": false,
  "tags": null,
  "request_buffering": true,
  "paths": [
    "/api/health"
  ],
  "created_at": 1779266337,
  "name": "identity-health",
  "https_redirect_status_code": 426,
  "id": "b89e2a22-8e23-5f7d-b065-6be326731d29",
  "sources": null,
  "snis": null,
  "headers": null,
  "response_buffering": true,
  "preserve_host": false,
  "updated_at": 1779266337,
  "protocols": [
    "http",
    "https"
  ]
}

## 2. Check if /api/public/jobs route exists
{
  "path_handling": "v0",
  "regex_priority": 0,
  "service": {
    "id": "0cde01b0-df77-5323-b663-d985d372803a"
  },
  "hosts": null,
  "destinations": null,
  "methods": null,
  "strip_path": false,
  "tags": null,
  "request_buffering": true,
  "paths": [
    "/api/public/jobs"
  ],
  "created_at": 1779266337,
  "name": "job-public",
  "https_redirect_status_code": 426,
  "id": "44b8bb98-dbe6-516b-ba72-a577d1136265",
  "sources": null,
  "snis": null,
  "headers": null,
  "response_buffering": true,
  "preserve_host": false,
  "updated_at": 1779266337,
  "protocols": [
    "http",
    "https"
  ]
}

## 3. All app service routes (sample)
35
