# Cilium Flow Log Analysis

## Checking recent flow denials between gateway and job7189-apps

```
```

## Check Cilium endpoint status
```
identity-service-7d96b99dd8-t4cfx              29174                                                          ready            10.244.1.173   
identity-service-redis-5657c455c9-t99mw        46485                                                          ready            10.244.4.250   
job-service-6c45458cc6-wmjpm                   37198                                                          ready            10.244.1.181   
job-service-redis-d5457f577-lkjzv              4964                                                           ready            10.244.4.139   
```

## Check Kong pod label (for CNP matching)
```
{
  "app": "kong-gateway",
  "pod-template-hash": "6784c9f4cd",
  "zta.job7189/data-classification": "none",
  "zta.job7189/env": "prod",
  "zta.job7189/exposure": "external",
  "zta.job7189/role": "proxy",
  "zta.job7189/score-bucket": "high",
  "zta.job7189/team": "platform",
  "zta.job7189/tier": "T2"
}
```
