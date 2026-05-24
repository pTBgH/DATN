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
| Tich hop deploy chain | ✅ Hoan thanh | `10-deploy-tetragon.sh` (Helm chart 1.7.0) |
| DaemonSet 3/3 worker | ✅ Hoat dong | srv02 + srv03 + srv05 |
| Prometheus scrape | ✅ Hoat dong | 3 target `up`, port 2112, annotation-based |
| TracingPolicy applied | ✅ 5 policy | block-suspicious-exec (4 ns) + monitor-sensitive-files + monitor-kernel-module-load |
| BPF kprobe sensor load | ✅ OK | chart 1.7 ships rebuilt `bpf_multi_kprobe_v61.o` cho kernel ≥6.10 |
| Resource thuc te | ~128Mi req / 384Mi limit per node | 3 worker × 128Mi = 384Mi them |

## Luu y chart cilium/tetragon 1.7.0 (Helm values schema)

Chart 1.2.0+ co cac values path dang note vi de nham:

| Muc dich | Path DUNG | Path SAI (bi ignore) |
|----------|-----------|---------------------|
| Pod annotations | `podAnnotations` (top-level) | `tetragon.podAnnotations` |
| Prometheus listen addr | `tetragon.prometheus.address` (IP, vd `""` hoac `"127.0.0.1"`) | `tetragon.prometheus.address=:2112` (bi render `:2112:2112`) |
| Prometheus port | `tetragon.prometheus.port` (int, default 2112) | — |

ConfigMap render: `metrics-server: <address>:<port>`. Neu address="" → `:2112` (bind all
interfaces). Neu address=":2112" → `:2112:2112` (agent KHONG bind).

Chart 1.7.0 them field bat buoc:

| Field | Gia tri dung | Ghi chu |
|-------|--------------|---------|
| `tetragon.processAncestors.enabled` | `"base"` (string, comma-separated list) | Nil pointer neu khong set; `--set-string` de tranh helm parse `,` lam separator |
| `tetragon.grpc.address` | `localhost:54321` (giu TCP cho PDP §6.1) | Default 1.7 chuyen sang Unix socket `unix:///var/run/tetragon/tetragon.sock` |

## Han che metric label (chart 1.7.0 va truoc)

Chart hard-code `metrics-label-filter: "namespace,workload,pod,binary"` (xem
`templates/tetragon_configmap.yaml`). Metric `tetragon_events_total` chi co 5
label: `namespace, workload, pod, binary, type` (type = PROCESS_EXEC, PROCESS_EXIT,
PROCESS_KPROBE, ...). KHONG co `function`, `file`, `policy`, `arg0`.

He qua cho Prometheus alert rule (PR-O):

| Alert | Phu hop voi label set? | Cach work-around |
|-------|------------------------|------------------|
| `ZTATetragonShellExec` | ✅ (dung `type="PROCESS_EXEC"` + `binary=~".../sh"`) | Fire ngay khi user exec shell trong workload |
| `ZTATetragonSensitiveFileRead` | ⚠ (khong co `file` label) | Match `type="PROCESS_KPROBE"` + `namespace="job7189-apps"` — alert proxy, can `tetra getevents` de xem path cu the |
| `ZTATetragonKernelModuleLoad` | ⚠ (khong co `function` label) | Match `type="PROCESS_KPROBE"` voi `namespace` ngoai cac NS dang co policy nguon-mo |

Ky thuat unblock alert lop file/function: chuyen sang stdout/JSON export +
Filebeat → ES → alert ES query (path/function la field trong JSON event, khong
phai metric label). Hoac patch chart de mo `--metrics-label-filter` cho thu them.

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

## BPF kprobe load fail (chart 1.2.0 → 1.7.0, fix 2026-05-24)

Tren cluster Debian trixie (kernel 6.12.86), chart 1.2.0 dong goi BPF object
`bpf_multi_kprobe_v61.o` build cho kernel ≤5.x. TAT CA TracingPolicy co
`kprobes:` section deu fail load:

```
sensor gkp-sensor-5 from collection block-suspicious-exec failed to load:
  failed prog /var/lib/tetragon/bpf_multi_kprobe_v61.o kern_version 396288
  loadInstance: opening collection ... failed:
  program generic_kprobe_process_event: load program: invalid argument
```

Log agent ke ra ca `block-suspicious-exec` lan `monitor-sensitive-files` deu
fail — cluster KHONG co policy nao thuc su trien khai du `kubectl get
tracingpolicy` van liet ke 5 doi tuong CRD. PR-N B3 nang chart → 1.7.0 voi
BPF object rebuilt cho kernel ≥6.10. Verify log agent sau upgrade:

```
Loaded generic kprobe sensor: /var/lib/tetragon/bpf_multi_kprobe_v61.o
  -> kprobe_multi (1 functions)
```

Khong con `level=warning msg="adding tracing policy failed"`.

## Xem them

- Thesis: chapter2.tex, Muc 2.3.3 (PEP tang Runtime)
- Thesis: chapter1.tex, Bang 1.3 (NIST mapping → Tetragon/Falco)
- MITRE: `doc/12-threat-model.md`
- Tetragon docs: https://tetragon.io/docs/
