# Adaptive Security Loop — PR #12

> Phase 4, Step 2.3.5 — thesis 3.4.5 / 3.5
>
> Mục tiêu: chuyển ZTA từ **policy tĩnh** (PR #7-#11) sang **policy + adaptive
> enforcement runtime + admission** — phản ứng được khi label/binding sai và
> chặn syscall đáng ngờ trên T1 ngay tại kernel level.

---

## 1. Kiến trúc 2 PEP mới

```
┌──────────────────────────── ZTA Stack (sau PR #12) ────────────────────────┐
│                                                                            │
│  PEP 1: Network (Cilium CNP — PR #7-#10)         L3/L4 + L7 HTTP rules    │
│  PEP 2: Mesh-Auth (Cilium SPIFFE — PR #7)        per-pod mTLS identity    │
│  PEP 3: Admission (OPA Gatekeeper — PR #12)  ←── NEW — verify ZTA labels  │
│  PEP 4: Runtime (Tetragon TracingPolicy)     ←── EXTENDED to T1 ns         │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

| PEP | Khi kích hoạt | Hành động khi vi phạm |
|-----|---------------|----------------------|
| **OPA Gatekeeper** | Pod create/update API call | `dryrun` → audit + log violation; `deny` → reject API call |
| **Tetragon TracingPolicy** | kprobe `sys_execve`, `sys_openat`, `sys_connect` | `Sigkill` (kill process) hoặc `Override` (return -EPERM) |

---

## 2. OPA Gatekeeper — 3 ConstraintTemplates

### 2.1 `ztarequiredlabels` (audit-only đầu)

Yêu cầu mọi Pod (và Deployment/StatefulSet/DaemonSet) trong 8 namespace phải
có cả 6 label `zta.job7189/*` (xem `knowledge-base/19-label-schema.md`).

Constraint `zta-labels-required` (file `02-constraint-zta-labels.yaml`):

```yaml
spec:
  enforcementAction: dryrun   # ← bật 'deny' khi Test 4d = 100% PASS
  match:
    namespaces: [data, vault, security, monitoring, gateway, management,
                 job7189-apps, frontend]
  parameters:
    labels:
    - key: "zta.job7189/role"
      allowedRegex: "^(api|worker|cache|...)$"
    - key: "zta.job7189/tier"
      allowedRegex: "^T[123]$"
    - key: "zta.job7189/env"
      allowedRegex: "^(prod|dev|staging)$"
    ...
```

**Tại sao 2 vòng audit + enforce**:

1. **Phase 1 (audit/dryrun)**: Đo coverage. `kubectl get ztarequiredlabels
   zta-labels-required -o jsonpath='{.status.violations}'` → list pod thiếu
   label. Sửa qua `bash scripts/zta-apply-workload-labels.sh --apply`.
2. **Phase 2 (deny)**: Khi `status.totalViolations: 0`, đổi
   `enforcementAction: deny` + reapply. Từ đó ai create pod thiếu label →
   API server reject ngay tại admission.

### 2.2 `ztablockhostmounts` (deny ngay)

Reject Pod mount `/`, `/etc`, `/proc`, `/sys`, `/var/run/docker.sock`,
`/var/lib/docker`, `/root`, `/home` host paths. Bypass attack thường gặp:

- Container escape qua docker.sock.
- Đọc `/etc/shadow`, `/etc/kubernetes/admin.conf` từ pod.
- Mount `/proc/1/root` để chui vào host filesystem.

Excluded namespaces: `kube-system` (kubelet, calico, etc.), `monitoring`
(node-exporter cần `/proc`+`/sys`), `gatekeeper-system`.

### 2.3 `ztarestrictprivileged` (audit-only đầu)

Reject Pod nếu:
- `securityContext.privileged: true`
- `securityContext.allowPrivilegeEscalation: true`
- `hostNetwork`/`hostPID`/`hostIPC: true`
- `capabilities.add: [SYS_ADMIN]`

Bật `dryrun` đầu vì một số system pod (Cilium agent, kube-proxy) cần
`hostNetwork`. Sau khi review excluded list cho phù hợp → bật `deny`.

---

## 3. Tetragon TracingPolicy mở rộng (T1 ns)

PR #4-#6 đã deploy Tetragon + `block-suspicious-exec` cho `job7189-apps`.
PR #12 thêm `block-suspicious-exec` cho **vault**, **data**, **security** —
3 namespace T1 (data-classification=confidential).

File: `infras/k8s-yaml/tetragon-policies/block-suspicious-exec-t1.yaml`

```yaml
kind: TracingPolicyNamespaced
metadata: { name: block-suspicious-exec, namespace: vault }
spec:
  kprobes:
  - call: "sys_execve"
    selectors:
    - matchArgs:
      - operator: "Equal"
        values: [/bin/sh, /bin/bash, /usr/bin/curl, /usr/bin/wget,
                 /usr/bin/nc, /usr/bin/ncat, /usr/bin/nmap, /usr/bin/socat,
                 /usr/bin/ssh]
      matchActions:
      - action: Sigkill
```

**Mở rộng so với PR cũ**: thêm `socat`, `ssh` vào danh sách binary cấm
(hai công cụ phổ biến trong reverse-shell payload).

**Tại sao Sigkill chứ không Override**:
- Sigkill: process bị `kill -9` ngay khi syscall trả về → audit log có
  PID, parent, container, pod, container image. Forensic.
- Override (return -EPERM): nhẹ hơn nhưng attacker có thể retry hoặc thử
  binary khác. Không scale với T1.

**Tetragon NOT in scope của PR #12 (defer to PR #13)**:
- TracingPolicy theo `data-classification=confidential` label (Tetragon
  chưa hỗ trợ k8s label selector trực tiếp — phải hardcode namespace).
- Hook `sys_connect` để block egress IP ngoài Cilium identity.

---

## 4. Triển khai

### 4.1 Áp dụng (sau khi cluster đã có labels từ PR #9)

```bash
# Bước 1: install Gatekeeper + apply 3 constraints
bash scripts/zta-deploy-gatekeeper.sh

# Bước 2: extend Tetragon to T1 ns
bash scripts/zta-apply-tracing-policies.sh --apply

# Bước 3: verify
bash 09-verify-zta.sh    # Test 4f phải PASS 4/4 (Gatekeeper + 3 constraint check + Tetragon T1)
```

### 4.2 Kiểm tra audit violations (hàng ngày)

```bash
# Pod nào vi phạm zta-labels-required?
kubectl get ztarequiredlabels.constraints.gatekeeper.sh \
  zta-labels-required -o jsonpath='{.status.violations}' | jq

# Tổng số violation
kubectl get ztarequiredlabels.constraints.gatekeeper.sh \
  zta-labels-required -o jsonpath='{.status.totalViolations}'
```

### 4.3 Bật strict-deny mode (sau khi 0 violations)

```bash
# Edit 02-constraint-zta-labels.yaml và 06-constraint-restrict-privileged.yaml
# Đổi enforcementAction: dryrun → deny
sed -i 's/enforcementAction: dryrun/enforcementAction: deny/' \
  infras/k8s-yaml/opa-gatekeeper/02-constraint-zta-labels.yaml \
  infras/k8s-yaml/opa-gatekeeper/06-constraint-restrict-privileged.yaml

kubectl apply -f infras/k8s-yaml/opa-gatekeeper/02-constraint-zta-labels.yaml
kubectl apply -f infras/k8s-yaml/opa-gatekeeper/06-constraint-restrict-privileged.yaml
```

Verify: thử tạo pod thiếu label → kubectl error.
```bash
kubectl run rogue --image=busybox -n job7189-apps -- sleep 60
# expected: Error from server (Forbidden): admission webhook
#   "validation.gatekeeper.sh" denied the request: ZTA labels missing on
#   Pod/rogue: {"zta.job7189/role", "zta.job7189/tier", ...}
```

### 4.4 Kiểm tra Tetragon kill log

```bash
# Stream events từ Tetragon
kubectl -n kube-system logs ds/tetragon -c export-stdout --tail=50 | \
  grep process_kprobe | jq 'select(.process_kprobe.action == "ACTION_SIGKILL")'

# Test tay: thử chạy /bin/bash trong pod vault → bị kill ngay
kubectl exec -n vault vault-0 -- /bin/bash -c 'echo hi' 2>&1
# expected: command terminated with exit code 137 (SIGKILL)
```

---

## 5. Adaptive loop (PEP ↔ PDP feedback)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Detection (Tetragon)              Decision (manual / future PDP)   │
│  ┌─────────────┐                   ┌──────────────────────┐         │
│  │ kprobe fire │ → audit event →   │ Triage in Hubble UI  │         │
│  │ sys_execve  │                   │ + Gatekeeper viol.   │         │
│  └─────────────┘                   └──────┬───────────────┘         │
│                                            │                        │
│                                            ▼                        │
│  Enforcement (Gatekeeper / CNP / Sigkill)                           │
│  - Tetragon Sigkill kills process inline                            │
│  - Gatekeeper future strict-deny prevents new violations            │
│  - Operator updates ZTA label / CNP based on findings               │
└─────────────────────────────────────────────────────────────────────┘
```

**Maturity (CISA ZTMM)**:
- Trước PR #12: **Advanced** (network microseg + identity + L7).
- Sau PR #12: **Optimal** (admission gate + runtime kernel-level kill +
  feedback loop) — đặc biệt cho cột "Applications & Workloads" và
  "Visibility & Analytics" trong CISA ZTMM 2.0.

---

## 6. Roadmap kế tiếp (PR #13+)

- **PR #13**: Falco với rules-set tuỳ biến cho ZTA (overlap Tetragon nhưng
  rule format dễ đọc hơn) + Falcosidekick → Slack/PagerDuty alert.
- **PR #14**: PDP server (custom controller) tự move pod sang quarantine ns
  khi >N Tetragon kill event/giờ.
- **PR #15**: Tetragon TracingPolicy với `selectors.matchBinaries` +
  `matchPids` để target bộ binary đáng ngờ chứ không chỉ argv.
- **PR #16**: SBOM (Trivy / Anchore) tích hợp Gatekeeper validate digest
  (block image không có signed SBOM).
