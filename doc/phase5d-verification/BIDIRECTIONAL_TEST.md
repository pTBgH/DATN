# Bidirectional Connectivity Test

## Test 1: From identity-service pod to Kong pod directly
Pod: identity-service-7d96b99dd8-t4cfx

Can we ping Kong pod IP?
```
Error from server (BadRequest): container identity-app is not valid for pod identity-service-7d96b99dd8-t4cfx
FAILED
```

Test 2: Check DNS resolution
```
Error from server (BadRequest): container identity-app is not valid for pod identity-service-7d96b99dd8-t4cfx
```

Test 3: List container names in identity-service pod
```
env-loader
env-watcher
app
vault-agent```
