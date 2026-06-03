# Port Configuration Check

## 1. App service definition
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8000
  selector:
    app: identity-service
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}

## 2. Pod port definition
```
[
  {
    "containerPort": 8000,
    "protocol": "TCP"
  }
]
```

## 3. CNP allowed ports for Kong
```
[
  {
    "port": "80",
    "protocol": "TCP"
  },
  {
    "port": "8080",
    "protocol": "TCP"
  }
]
```
