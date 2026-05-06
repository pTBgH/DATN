# 31. Falco Runtime Detection (DEPRECATED — Tetragon replaced)

> **STATUS: DEPRECATED (2026-05).** Falco đã bị gỡ khỏi pipeline ZTA và
> repo này từ PR-D cleanup parallel. Tetragon (xem `doc/14-tetragon-runtime.md`)
> phủ toàn bộ runtime detection use-cases mà Falco từng làm trên cụm 1-node lab.
>
> **Lý do gỡ:** xem `doc/incident-falco-tetragon-ram-overcommit.md`. Tóm tắt:
> Falco DS-per-node (~1 GiB tổng cluster) gây RAM overcommit trên lab box 12 GiB,
> cascading OOMKills (tetragon, metrics-server, cilium-operator,
> policy-controller-webhook). Tetragon đã có sẵn (cùng dự án `cilium`,
> share kernel BPF probes) nên Falco trở thành redundant trong môi trường
> hạn chế tài nguyên.
>
> **Artefact đã xóa khỏi repo:**
> - `scripts/zta-deploy-falco.sh`
> - `infras/k8s-yaml/falco/values.yaml`
> - Test 4m trong `09-verify-zta.sh`
> - Step 25-falco trong `scripts/zta-rebuild.sh` (đã loại từ trước, comment vẫn còn)
>
> Tài liệu này được giữ lại làm chứng cứ thiết kế (thesis Chapter 4) — KHÔNG
> phải hướng dẫn vận hành. Đừng triển khai theo các bước bên dưới.

---

## 1. Bối cảnh (lịch sử)

PR #12 deploy Tetragon — kernel-level eBPF observation tool, focus tracking syscall + process events. Falco là rules-based detection engine, focus alerting trên policy violation. Hai tool **bổ sung**, không thay thế:

| Aspect | Tetragon (PR #12) | Falco (PR #22) |
|---|---|---|
| Engine | eBPF programs (BPF maps + helpers) | Rules engine + eBPF driver |
| Output | Hubble events / kprobe traces | Alert events (priority, JSON) |
| Strength | low-level syscall monitoring | declarative rules + alerting + sinks |
| Ecosystem | k8s-native, smaller community | larger ecosystem (Falcosidekick, plugins) |
| ZTA fit | adaptive enforcement (kill on violation) | detection + alert + audit |

## 2. Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ Each node                                                           │
│  ┌──────────────────────────────────────┐                          │
│  │ falco DaemonSet                      │                          │
│  │  - modern_ebpf CO-RE probe           │                          │
│  │  - rules: built-in + ZTA custom      │                          │
│  │  - mode: alert (no enforcement)      │                          │
│  │  - output: stdout + HTTP             │                          │
│  └────────────────┬─────────────────────┘                          │
│                   │ HTTP POST (port 2801)                          │
│                   ▼                                                 │
│  ┌──────────────────────────────────────┐                          │
│  │ falco-falcosidekick (Deployment)     │                          │
│  │  - alert router + enrichment         │                          │
│  │  - sinks: Elasticsearch, Slack, etc. │                          │
│  └────────────────┬─────────────────────┘                          │
└───────────────────┼─────────────────────────────────────────────────┘
                    │ HTTP POST /falco-events-YYYY.MM.DD/_doc
                    ▼
   ┌────────────────────────────────────────────┐
   │ Elasticsearch (monitoring ns) — index            │
   │   falco-events-*                           │
   │ Kibana dashboards (manual setup):          │
   │ - Top rules triggered (24h)                │
   │ - Critical alerts timeline                 │
   │ - Per-namespace breakdown                  │
   └────────────────────────────────────────────┘
```

## 3. ZTA Custom Rules (5 rules)

`infras/k8s-yaml/falco/values.yaml` → `customRules.zta-rules.yaml`:

### Rule 1: Vault Secret File Read by Foreign Process
- **MITRE**: T1552.001 (Credentials in Files)
- **Trigger**: Read `/vault/secrets/*` by process not in vault sidecar list
- **Priority**: WARNING
- **Use case**: Vault Agent injects secrets vào tmpfs; bất kỳ process khác đọc → leak risk

### Rule 2: Cosign Private Key Access
- **MITRE**: T1552.004 (Private Keys)
- **Trigger**: ANY read of `/cosign-keys/*`
- **Priority**: CRITICAL
- **Use case**: PR #16 cosign sign-time keys. Runtime workload không bao giờ access. Trigger = breach

### Rule 3: Shell in Security Namespace Pod
- **MITRE**: TA0008 (Lateral Movement)
- **Trigger**: `kubectl exec` shell vào pod ở `security`/`vault`/`spire`/`cosign-system`
- **Priority**: WARNING
- **Use case**: Operator hợp lệ thỉnh thoảng exec, nhưng lateral movement attacker cũng vậy → audit trail

### Rule 4: Privilege Escalation via setuid root
- **MITRE**: T1068 (Exploitation for Privilege Escalation)
- **Trigger**: setuid(0) called by non-root inside container
- **Priority**: CRITICAL
- **Use case**: Container security policy yêu cầu non-root; setuid → exploit

### Rule 5: SPIRE Workload API Socket Tampering
- **MITRE**: T1078.004 (Cloud Accounts → Service Accounts equivalent)
- **Trigger**: write/unlink to `spire-agent.sock`
- **Priority**: CRITICAL
- **Use case**: Hijack workload identity issuance — break-glass for entire ZTA identity layer

## 4. Triển khai

```bash
# Prerequisite: PR #21 deployed (ES at elasticsearch.monitoring:9200)
bash scripts/zta-deploy-falco.sh

# Verify driver loaded
kubectl -n falco logs ds/falco -c falco --tail=20 | grep -i "loading rules\|driver"

# Verify ZTA rules loaded
kubectl -n falco exec ds/falco -c falco -- grep -c "^- rule: ZTA" /etc/falco/rules.d/zta-rules.yaml
# → 5

# Trigger test alert (Critical)
kubectl run alert-test --image=alpine --restart=Never --rm -it -- cat /etc/shadow
# → Falco built-in rule "Read sensitive file untrusted" triggers

# Watch sidekick forward to ES
kubectl -n falco logs deploy/falco-falcosidekick --tail=5

# Query ES alerts
kubectl -n monitoring exec es-0 -- \
  curl -s "http://localhost:9200/falco-events-*/_search?pretty&q=rule:ZTA*&size=5"

# Test 4m
bash 09-verify-zta.sh | grep "Test 4m" -A 12
```

## 5. Demo for thesis (5 phút)

Tạo 3 alert thực sự khác nhau cho Chapter 4 evidence:

```bash
# A. Built-in alert: read sensitive file
kubectl run alert-A --image=alpine --restart=Never --rm -it -- cat /etc/shadow

# B. ZTA Rule 3: shell in security ns
kubectl -n security run -it --rm shell-test --image=alpine --restart=Never -- sh

# C. ZTA Rule 4: setuid root (need privileged image)
kubectl run privesc --image=alpine --restart=Never --rm -it -- \
  sh -c 'cp /bin/busybox /tmp/x && chmod 4755 /tmp/x && /tmp/x setuidgid 0 sh -c "id"'

# Query Kibana — discover index falco-events-* sorted by @timestamp
```

## 6. Resource budget

| Component | RAM req/limit | CPU | Replicas |
|---|---|---|---|
| falco DS | 200/512 Mi | 100m/500m | 4 (per node) |
| falcosidekick | 64/128 Mi | 25m/100m | 1 |
| **Total RAM** |  |  | **~800-2200Mi** |

Tip: nếu RAM chật, giảm `falco.resources.limits.memory` xuống 256Mi (không nhiều rules) hoặc disable Falcosidekick (alert chỉ ra stdout).

## 7. CISA ZTMM mapping

| Pillar | Trước (PR #21) | Sau (PR #22) |
|---|---|---|
| **Visibility & Analytics** | persistent flow audit | + **runtime threat detection** + alert correlation |
| **Cross-cutting Automation** | adaptive enforcement (Tetragon) | + alert routing → SIEM |
| **Networks** | Advanced+ | unchanged |
| **Devices** | Optimal (PR #20) | unchanged |
| **Data** | Advanced | + Vault tmpfs leak detection (Rule 1) |

PR #22 không lift CISA tier (đã optimal/advanced từ PRs trước) nhưng **tăng confidence** trong các pillars hiện tại — defence in depth.

## 8. Limitations

- **Alert-only mode**: Falco không enforce. Nếu alert quan trọng, trigger phản ứng phải qua Falcosidekick → Slack/PagerDuty/Webhook → automated runbook (ngoài scope PR #22).
- **eBPF kernel requirement**: modern_ebpf cần kernel ≥ 5.8. Cluster Kind chạy trên host kernel; nếu host < 5.8 phải dùng `driver.kind: ebpf` (legacy).
- **No Slack/PagerDuty integration enabled**: webhookurl trống trong values.yaml. Add via `kubectl set env` cho Falcosidekick deployment.
- **Custom rules ngắn — chỉ 5 ZTA rules**: thực tế production cần 50-100 rules tùy workload pattern. PR #22 chỉ là baseline.
- **False positives**: Rule 3 (shell in security ns) sẽ alert mỗi lần operator legit exec. Cần whitelist by user qua macro.

## 9. Roadmap mở rộng

- **PR #22a**: Add 20+ MITRE ATT&CK k8s rules (Falco's k8s_audit_rules.yaml + community rules).
- **PR #22b**: Slack/Teams webhook setup với alert deduplication.
- **PR #22c**: PagerDuty integration cho CRITICAL priority.
- **PR #22d**: Automated response — Falco webhook → ZTA controller → quarantine pod via Cilium label patch.
- **PR #22e**: Falco Talon (native enforcement: kill pod, network policy block) — graduate detection-only → enforcement.
