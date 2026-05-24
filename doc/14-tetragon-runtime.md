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
| Tich hop deploy chain | ✅ Hoan thanh | `10-deploy-tetragon.sh` (Helm chart 1.2.0) |
| DaemonSet 3/3 worker | ✅ Hoat dong | srv02 + srv03 + srv05 |
| Prometheus scrape | ✅ Hoat dong | 3 target `up`, port 2112, annotation-based |
| TracingPolicy applied | ✅ 5 policy | block-suspicious-exec (4 ns) + monitor-sensitive-files |
| Test thu nghiem | ⚠ Mot phan | block-suspicious-exec OK; monitor-sensitive-files kprobe load fail (kernel 6.12.86) |
| Resource thuc te | ~128Mi req / 384Mi limit per node | 3 worker × 128Mi = 384Mi them |

## Luu y chart cilium/tetragon 1.2.0 (Helm values schema)

Chart 1.2.0 co cac values path dang note vi de nham:

| Muc dich | Path DUNG | Path SAI (bi ignore) |
|----------|-----------|---------------------|
| Pod annotations | `podAnnotations` (top-level) | `tetragon.podAnnotations` |
| Prometheus listen addr | `tetragon.prometheus.address` (IP, vd `""` hoac `"127.0.0.1"`) | `tetragon.prometheus.address=:2112` (bi render `:2112:2112`) |
| Prometheus port | `tetragon.prometheus.port` (int, default 2112) | — |

ConfigMap render: `metrics-server: <address>:<port>`. Neu address="" → `:2112` (bind all
interfaces). Neu address=":2112" → `:2112:2112` (agent KHONG bind).

## Deploy command (hien tai)

```bash
# Full deploy (bao gom preflight + cleanup + helm install + TracingPolicy apply)
bash 10-deploy-tetragon.sh

# Override headroom check (rui ro thap nếu node thuc te con >=200Mi)
TETRAGON_PER_NODE_HEADROOM_MI=200 bash 10-deploy-tetragon.sh
```

## Ordering luu y (fix 2026-05-24)

Script cu chay cleanup (helm uninstall + delete CRD) TRUOC preflight → neu preflight
fail (thieu RAM), cluster mat Tetragon + CRD khong phuc hoi duoc. Script moi chay:

1. **Step 0**: Pre-flight (RAM check, per-node headroom) — abort som neu fail
2. **Step 1**: Cleanup existing release (chi chay neu Step 0 pass)
3. **Step 2+**: Helm install, wait CRD, apply TracingPolicy

## BPF kprobe known issue (kernel 6.12.86)

TracingPolicy `monitor-sensitive-files` dung `multi_kprobe` de hook `do_filp_open`.
Kernel 6.12.86 (Debian trixie) thay doi kprobe function signature, gay:
```
load program: invalid argument
```
Khong anh huong den cac TracingPolicy `block-suspicious-exec` (dung `sys_execve` —
stable ABI). Doi tetragon chart 1.3.x hoac patch BTF-aware kprobe.

## Xem them

- Thesis: chapter2.tex, Muc 2.3.3 (PEP tang Runtime)
- Thesis: chapter1.tex, Bang 1.3 (NIST mapping → Tetragon/Falco)
- MITRE: `doc/12-threat-model.md`
- Tetragon docs: https://tetragon.io/docs/
