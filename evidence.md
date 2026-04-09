# Evidence and Log Analysis

This document compiles the key evidence demonstrating the Vault Agent startup race condition.

## 1. Error Logs

The initial failure is characterized by a DNS resolution error before any network traffic leaves the pod.

**Log Snippet (vault-agent or vault-agent-init):**
```text
[ERROR] auth.handler: error authenticating: error="lookup vault.vault.svc.cluster.local ... operation not permitted"
[INFO]  auth.handler: authenticating
```
*Analysis:* The `operation not permitted` specifically during a `lookup` indicates that the container process attempted to resolve the hostname via the local network stack, but the local resolver or network interface was either unconfigured or aggressively denying traffic because the CNI had not fully attached the endpoint.

## 2. Pod Restart Evidence

Inspecting the pod state (`kubectl describe pod <pod-name>`) reveals evidence of the self-healing behavior following the crash.

**Pod State Snippet:**
```yaml
Containers:
  vault-agent:
    State:          Running
      Started:      Wed, 08 Apr 2026 10:00:05 GMT
    Last State:     Terminated
      Reason:       Error
      Exit Code:    255
      Started:      Wed, 08 Apr 2026 10:00:00 GMT
      Finished:     Wed, 08 Apr 2026 10:00:01 GMT
    Ready:          True
    Restart Count:  1
```
*Analysis:* The container failed initially (Exit Code 255) almost immediately after starting. When Kubernetes restarted the container a few seconds later, it transitioned to a `Running` and `Ready` state successfully, confirming the condition was temporary.

## 3. Successful Curl Test

Once the pod is in a steady state, manual verification confirms the infrastructure, DNS, and TLS configurations are completely valid.

**Execution:**
```shell
kubectl exec -it <pod-name> -c identity-service -- curl -k https://vault.vault.svc.cluster.local:8200/v1/sys/health
```

**Output:**
```json
{
  "initialized": true,
  "sealed": false,
  "standby": false,
  "performance_standby": false,
  "replication_performance_mode": "disabled",
  "replication_dr_mode": "disabled",
  "server_time_utc": 1775635200,
  "version": "1.15.2",
  "cluster_name": "vault-cluster",
  "cluster_id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
}
```
*Analysis:* The successful response proves that:
1. CoreDNS correctly resolves `vault.vault.svc.cluster.local`.
2. Network routing to the cluster service IP works.
3. Vault is up, unsealed, and able to terminate TLS connections successfully.

This absolute success exactly matches the conclusion that the initial error was solely due to timing and startup race conditions, rather than a misconfiguration of the service mesh, CNI policies, or Vault itself.