# Tetragon — Runtime Enforcement (PEP Runtime)

## Vi tri trong khung ZTA 5 lop

Tetragon la **PEP tang Runtime** (Lop 3, tang thu 3) — giam sat va ngan chan
cac system call (syscall) bat thuong ben trong container.

## Chuc nang thiet ke

| Kha nang | Mo ta | Vi du |
|----------|-------|-------|
| Process Execution Control | Chan thuc thi binary nghi ngo | `/bin/sh`, `curl`, `wget` trong container web |
| File Access Monitoring | Phat hien doc file nhay cam | `/etc/passwd`, `/proc/self/environ` |
| Network Socket Control | Phat hien ket noi outbound la | Reverse shell, C2 callback |
| Privilege Escalation Detection | Leo thang quyen | `CAP_SYS_ADMIN`, `nsenter` |

## MITRE ATT&CK Coverage

| Giai doan | Ky thuat | Tetragon Response |
|-----------|---------|-------------------|
| Execution | T1609 — Container exec | Chan `sys_execve` cho binary khong trong allowlist |
| Persistence | T1053 — CronJob injection | Giam sat `sys_write` tren hostPath |
| Defense Evasion | T1070 — Clear logs | Chan `sys_unlink` tren /var/log |
| Exfiltration | T1048 — Exfil over alt protocol | Chan `sys_connect` den IP/port khong cho phep |

## Kien truc eBPF Hooks

```
Container Process
    │
    ▼
[ sys_execve ] ──→ Tetragon eBPF program (kernel)
    │                   │
    │               ┌───┴───┐
    │               │ Match │ ──→ SIGKILL (truoc khi kernel thuc thi)
    │               │Policy?│
    │               └───┬───┘
    │                   │ No match
    ▼                   ▼
Normal Execution    Allow (log event)
```

## TracingPolicy Example (thiet ke cho job7189)

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-suspicious-exec
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchArgs:
      - index: 0
        operator: "In"
        values:
        - "/bin/sh"
        - "/bin/bash"
        - "/usr/bin/curl"
        - "/usr/bin/wget"
        - "/usr/bin/nc"
        - "/usr/bin/ncat"
      matchNamespaces:
      - namespace: job7189-apps
        operator: In
      matchActions:
      - action: Sigkill
```

## Trang thai trien khai

| Hang muc | Trang thai | Ghi chu |
|----------|------------|---------|
| Thiet ke policy | ✅ Hoan thanh | TracingPolicy YAML da viet |
| Tich hop deploy chain | ❌ Chua | Can them vao script chain |
| Test thu nghiem | ❌ Chua | Can tao attacker pod de test |
| Resource estimate | ~128Mi/node (DaemonSet) | 4 nodes = 512Mi them |

## Ly do chua trien khai trong PoC

1. **Resource**: He thong dang 8.7Gi/12Gi, them 512Mi co the gay OOM
2. **Complexity**: TracingPolicy can fine-tune ky de tranh false positive
3. **Scope**: Bao cao thesis da khai bao ro "bo sung sau" — khong phai GAP
4. **Priority**: mTLS + WireGuard + Microseg da cover phan lon attack surface

## Ke hoach trien khai (neu co them RAM)

```bash
# 1. Cai Tetragon qua Helm
helm repo add cilium https://helm.cilium.io
helm install tetragon cilium/tetragon -n kube-system \
  --set tetragon.resources.limits.memory=128Mi

# 2. Apply TracingPolicy
kubectl apply -f infras/k8s-yaml/tetragon-policies/block-suspicious-exec.yaml

# 3. Verify
kubectl exec -n job7189-apps deploy/identity-service -- /bin/sh
# → SIGKILL expected
```

## Xem them

- Thesis: chapter2.tex, Muc 2.3.3 (PEP tang Runtime)
- Thesis: chapter1.tex, Bang 1.3 (NIST mapping → Tetragon/Falco)
- MITRE: `doc/12-threat-model.md`
- Tetragon docs: https://tetragon.io/docs/
