# CNP Egress Rules Check (Gateway Namespace)

## All CNP rules in gateway namespace
{
  "name": "allow-dns-egress-gateway",
  "ingress": 0,
  "egress": 1
}
{
  "name": "allow-kong-egress-apps",
  "ingress": 0,
  "egress": 1
}
{
  "name": "allow-kong-egress-keycloak",
  "ingress": 0,
  "egress": 1
}
{
  "name": "allow-kong-egress-management",
  "ingress": 0,
  "egress": 1
}
{
  "name": "allow-kong-egress-opa",
  "ingress": 0,
  "egress": 1
}
{
  "name": "allow-kong-proxy-ingress",
  "ingress": 3,
  "egress": 0
}
{
  "name": "allow-prometheus-scrape-gateway",
  "ingress": 1,
  "egress": 0
}
{
  "name": "default-deny-gateway",
  "ingress": 1,
  "egress": 1
}
{
  "name": "l7-kong-admin-readonly",
  "ingress": 1,
  "egress": 0
}

## Default deny in gateway?
```
{
  "name": "default-deny-gateway",
  "spec": {
    "egress": [
      {
        "toEndpoints": [
          {
            "matchLabels": {
              "cilium.zta/marker": "umbrella-deny"
            }
          }
        ]
      }
    ],
    "endpointSelector": {},
    "ingress": [
      {
        "fromEndpoints": [
          {
            "matchLabels": {
              "cilium.zta/marker": "umbrella-deny"
            }
          }
        ]
      }
    ]
  }
}
```

## Kong egress rules
```
{
  "name": "allow-kong-egress-apps",
  "egress": [
    {
      "toEndpoints": [
        {
          "matchLabels": {
            "k8s:io.kubernetes.pod.namespace": "job7189-apps"
          }
        }
      ],
      "toPorts": [
        {
          "ports": [
            {
              "port": "80",
              "protocol": "TCP"
            }
          ]
        }
      ]
    }
  ]
}
{
  "name": "allow-kong-egress-keycloak",
  "egress": [
    {
      "toEndpoints": [
        {
          "matchLabels": {
            "app": "keycloak",
            "k8s:io.kubernetes.pod.namespace": "security"
          }
        }
      ],
      "toPorts": [
        {
          "ports": [
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
{
  "name": "allow-kong-egress-management",
  "egress": [
    {
      "toEndpoints": [
        {
          "matchLabels": {
            "k8s:io.kubernetes.pod.namespace": "management"
          }
        }
      ],
      "toPorts": [
        {
          "ports": [
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
{
  "name": "allow-kong-egress-opa",
  "egress": [
    {
      "toEndpoints": [
        {
          "matchLabels": {
            "app": "opa",
            "k8s:io.kubernetes.pod.namespace": "security"
          }
        }
      ],
      "toPorts": [
        {
          "ports": [
            {
              "port": "8181",
              "protocol": "TCP"
            }
          ]
        }
      ]
    }
  ]
}
{
  "name": "allow-kong-proxy-ingress",
  "egress": null
}
{
  "name": "l7-kong-admin-readonly",
  "egress": null
}
```
