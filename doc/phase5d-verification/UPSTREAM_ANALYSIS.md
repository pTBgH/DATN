# Phase 5.D: Upstream Service Analysis

## Status Summary

### Pods Running: ✓
- identity-service (4/4) - 67m uptime
- job-service (4/4) - 67m uptime
- All services on node 7189srv02

### Issue Investigation

Since Kong pod has no curl, we need to check:
1. CNP rules blocking gateway→job7189-apps ingress
2. Service readiness probe status
3. Kong upstream configuration

## Expected Root Causes

A) **Cilium CNP blocking Kong→app traffic**
   - Check: `kubectl get cnp -n job7189-apps`
   - Look for ingress rules from gateway namespace

B) **Service readiness probe failing**
   - Check: Pod describe → readinessProbe configuration
   - Check: Application logs for startup errors

C) **Kong upstream misconfiguration**
   - Services may not be registered in Kong upstreams
   - Endpoints may not be discovered

---
## 1. Check CNP ingress rules

```
{
  "name": "allow-dns-egress",
  "ingressRules": 0
}
{
  "name": "allow-egress-vault-db",
  "ingressRules": 0
}
{
  "name": "allow-internal-identity",
  "ingressRules": 1
}
{
  "name": "allow-internal-job-to-workspace",
  "ingressRules": 1
}
{
  "name": "allow-kong-ingress",
  "ingressRules": 1
}
{
  "name": "default-deny-all",
  "ingressRules": 0
}
```

## 2. CNP Kong ingress rule details
```
{
  "name": "allow-kong-ingress",
  "ingress": [
    {
      "fromEndpoints": [
        {
          "matchLabels": {
            "k8s:io.kubernetes.pod.namespace": "gateway"
          }
        }
      ],
      "toPorts": [
        {
          "ports": [
            {
              "port": "80",
              "protocol": "TCP"
            },
            {
              "port": "8080",
              "protocol": "TCP"
            }
          ]
        }
      ]
    }
  ]
}
```

## 3. Identity service readiness probe
```
```
