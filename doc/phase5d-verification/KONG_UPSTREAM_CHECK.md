# Kong Service & Upstream Configuration

## 1. Identity Service Configuration
```
{
  "name": "identity-service",
  "protocol": "http",
  "host": "identity-service.job7189-apps.svc.cluster.local",
  "port": 80,
  "path": null,
  "upstream": null
}
```

## 2. Job Service Configuration
```
{
  "name": "job-service",
  "protocol": "http",
  "host": "job-service.job7189-apps.svc.cluster.local",
  "port": 80,
  "path": null,
  "upstream": null
}
```

## 3. Service target endpoints
