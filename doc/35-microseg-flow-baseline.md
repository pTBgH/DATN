# Microsegmentation — Flow Baseline & Draft Refinement Report

> Companion to `doc/34-microseg-phase2c-plan.md`. Captures observed traffic
> pattern from a real Hubble flow dump and lists the refinements applied to
> the Phase 2C draft CNPs (`infras/k8s-yaml/cilium-policies/namespaces/17-*`
> through `24-*`).

## 1. Capture metadata

| Field | Value |
|---|---|
| Captured at | 2026-05-22 13:38 UTC, duration 10 min |
| Cilium pod | `cilium-578zg` (host-network, cluster default) |
| Hubble relay | reached via pod IP `10.244.2.58:4245` (DNS workaround merged in PR #1) |
| Raw flow file | `07-flows.jsonl` — **155 905 events** (≈248 MB) |
| Unique 7-tuple flows | **5 540** |
| FORWARDED | 5 493 |
| DROPPED | 19 (13 of those are noise: IPv6 NDP from `reserved:unknown`) |
| Real (non-noise) drops | **6** — all `job7189-apps → data/kafka-0:9092 TCP` |

## 2. Parser bug fix (root cause of script failure)

The inline `python3 -` heredoc in `zta-microseg-step1-flow-capture.sh` step
3/4 crashed with:

```
Traceback (most recent call last):
  File "<stdin>", line 31, in <module>
AttributeError: 'str' object has no attribute 'get'
```

### Why

Hubble flow JSON encodes `source.labels` / `destination.labels` as
`list[str]` like `["reserved:host", "k8s:app=foo"]` (split key/value at the
first `=`).  The old code did:

```python
"src_ns": src.get("namespace","") or
          src.get("labels",[{}])[0].get("key","") if src.get("labels") else "",
```

…which tries to call `.get("key", "")` on a *string*. It also has bogus
operator precedence: `or … if … else ""` binds the `if/else` only to the
last expression.

### Fix

Parser moved to a standalone Python file
`scripts/zta-microseg-parse-flows.py` with defensive handling for both
`list[str]` (modern Hubble) and `list[dict]` (legacy) label encodings.
`zta-microseg-step1-flow-capture.sh` auto-locates and invokes that file.

### Re-run instructions (no need to recapture)

```bash
cd ~/projects/DATN
python3 scripts/zta-microseg-parse-flows.py \
    ~/zta-microseg/<TS>           # the same dir produced by step 1
# Outputs:
#   08-unique-flows.csv
#   09-dropped-flows.csv
#   10-forwarded-flows.csv
#   11-flows-by-src-ns.md
#   12-summary.md
```

## 3. DROPPED-flow inventory

| # | src_ns | src_pod | dst_ns / pod | port/proto | Legitimate? | Action |
|---|---|---|---|---|---|---|
| 1 | job7189-apps | communication-service | data / kafka-0 | 9092/TCP | **YES** | Apply `10-data.yaml::allow-apps-egress-kafka` (already in repo, not on cluster) |
| 2 | job7189-apps | job-service | data / kafka-0 | 9092/TCP | YES | same |
| 3 | job7189-apps | workspace-service | data / kafka-0 | 9092/TCP | YES | same |
| 4 | job7189-apps | hiring-service | data / kafka-0 | 9092/TCP | YES | same |
| 5 | job7189-apps | candidate-service | data / kafka-0 | 9092/TCP | YES | same |
| 6 | reserved:remote-node | — | reserved:host | — | NDP/keep-alive | ignore |
| 7-19 | various ns | — | reserved:unknown | ICMPv6 | IPv6 link-local NDP / RA | ignore (IPv6 not used in cluster) |

> **Critical**: All 5 Laravel services have been hitting Kafka and getting
> dropped silently for the entire observation window. The allow rule exists
> in `infras/k8s-yaml/cilium-policies/namespaces/10-data.yaml` as
> `allow-apps-egress-kafka` but the live cluster does NOT have it (verify
> with `kubectl get cnp -n job7189-apps allow-apps-egress-kafka`). Apply it.

## 4. Per-namespace traffic summary (well-known dest ports)

Filter: `verdict=FORWARDED` + `dst_port < 32768` (drop ephemeral reply
ports). Source pods column counts unique pod identities.

```
== cert-manager egress ==
  → reserved:kube-apiserver  :6443/TCP    (3 src pods)

== cosign-system egress ==
  → kube-system              :  53/UDP    (2 src pods)
  → reserved:world           :5000/TCP    (2 src pods)   ← registry sigverify
  → reserved:world           : 443/TCP    (1 src pods)   ← Sigstore TUF refresh
  → reserved:kube-apiserver  :6443/TCP    (1 src pods)

== data egress (ns has no CNP yet) ==
  → vault :48634, security :*, job7189-apps :* (reply traffic — fine)

== gatekeeper-system egress ==
  → reserved:kube-apiserver  :6443/TCP    (2 src pods)

== ingress-nginx egress ==
  → reserved:kube-apiserver  :6443/TCP    (1 src pods)

== job7189-apps egress ==
  → kube-system :53/UDP                   (14 src pods)
  → vault       :8200/TCP                 (7 src pods)
  → job7189-apps:6379/TCP (intra-redis)   (6 src pods)
  → data        :3306/TCP (one-off)       (1 src pod)
  → data        :9092/TCP  *** DROPPED ***  (5 src pods, see §3)

== kube-system egress ==
  → reserved:world :53/UDP                (3 src pods)   ← upstream DNS
  → reserved:host  :6443/10250/4244 TCP   (control-plane)

== monitoring egress ==
  → kube-system :53/UDP                   (4 src pods)
  → reserved:world :443/TCP               (2 src pods)
  → reserved:kube-apiserver :6443/TCP     (2 src pods)
  → monitoring  :8080/TCP                 (2 src pods)
  → cert-manager:9402/TCP                 (1 src pods)   ← scrape
  → security    :9100/TCP                 (1 src pods)   ← node-exporter scrape
  → reserved:kube-apiserver :9963/TCP     (1 src pods)   ← cilium-operator

== security egress ==
  → kube-system :53/UDP                   (2 src pods)
  → reserved:kube-apiserver :6443/TCP     (2 src pods)
  → data        :3306/TCP                 (1 src pods)   ← keycloak

== spire egress ==
  → reserved:kube-apiserver :6443/TCP     (1 src pods)

== vault egress ==
  → data :3306/TCP                        (1 src pods)
  → reserved:kube-apiserver :6443/TCP     (1 src pods)
```

```
== cert-manager ingress ==
  ← monitoring  :9402/TCP                 (Prometheus scrape)
  ← reserved:host :6080/TCP               (cainjector healthz probe)
  ← reserved:host :9403/TCP               (webhook metrics/healthz)

== cosign-system ingress ==
  ← reserved:host       :8443/TCP        (webhook callback, apiserver SNAT)
  ← reserved:remote-node:8443/TCP

== data ingress ==
  ← job7189-apps :3306/TCP                (mysql)
  ← security     :3306/TCP                (keycloak)
  ← vault        :3306/TCP                (dynamic creds)

== gatekeeper-system ingress ==
  ← reserved:host       :9090/TCP         (kubelet probe)
  ← reserved:remote-node:8443/TCP         (webhook callback)

== ingress-nginx ingress ==
  ← reserved:host :10254/TCP              (metrics/healthz)

== job7189-apps ingress ==
  ← job7189-apps :6379/TCP                (intra-redis, 6 src pods)

== kube-system ingress ==
  ← job7189-apps   :53/UDP (14)
  ← monitoring     :53/UDP (4)
  ← cosign-system  :53/UDP (2)
  ← security       :53/UDP (2)
  ← reserved:host  :8080/8081/8181/TCP    (coredns metrics scrape)
  ← reserved:remote-node :4245/TCP        (hubble-relay)

== monitoring ingress ==
  ← monitoring     :8080/9200 TCP
  ← reserved:host  :8080/8081/9200 TCP
  ← reserved:remote-node :9200/TCP        (ES inter-node)

== security ingress ==
  ← monitoring     :9100/TCP              (node-exporter scrape)
  ← reserved:host  :4180/8080/8181/9100   (probes + scrape)
  ← security       :8080/TCP

== spire ingress ==
  ← reserved:host  :9809/TCP (3)          (controller-manager healthz)
  ← reserved:host  :8080/8081/8083/TCP    (server + agent probes)

== vault ingress ==
  ← job7189-apps   :8200/TCP (7 pods)
  ← reserved:host  :8080/TCP              (probe)
```

## 5. Refinements applied to draft CNPs

| File | Change | Justification |
|---|---|---|
| `17-cert-manager.yaml` | Add `allow-cert-manager-probe-ingress` (host/remote-node → 6080, 9402, 9403 TCP). Add 9403 to Prometheus scrape. | Observed kubelet probes to cainjector :6080 + webhook :9403. Without these, liveness probes drop after default-deny → cert-manager pods restart. |
| `18-cosign-system.yaml` | Add `allow-cosign-egress-sigstore-public` (policy-controller → world:443 TCP). | Observed policy-controller → reserved:world:443. Even verify-via-public-key mode refreshes TUF root metadata from Sigstore-public. |
| `21-spire.yaml` | Add `allow-spire-probe-ingress` (host/remote-node → 8080/8081/8083/9809 TCP). Add 9809 to Prometheus scrape. | Observed kubelet probes to spire-controller-manager :9809 + spire-server :8080/8081 + spire-agent :8083. |

`19-gatekeeper-system.yaml`, `20-ingress-nginx.yaml`, `22-local-path-storage.yaml`,
`23-kube-system.yaml`, `24-trivy-system.yaml` — flow data confirmed their
existing allow rules match observed ports; **no change needed**.

## 6. Pre-apply checklist

Before applying any default-deny CNP to a previously open namespace, run:

```bash
bash scripts/zta-microseg-step2-validate.sh
# Inspect:
#   ~/zta-microseg-validate/<TS>/03-dry-run-apply.md     (schema validation)
#   ~/zta-microseg-validate/<TS>/04-recent-hubble-drops.md (live drops < 30m)
#   ~/zta-microseg-validate/<TS>/05-policy-vs-pods.md    (selector vs labels)
```

Apply order (lowest blast radius first):

```
22-local-path-storage   → 24-trivy-system      → 17-cert-manager
→ 21-spire              → 19-gatekeeper-system → 18-cosign-system
→ 20-ingress-nginx      → 23-kube-system (DNS allow only, no ns-wide deny)
```

After each apply, watch Hubble for 5 minutes:

```bash
CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $CILIUM -- hubble observe \
    --verdict DROPPED --since 5m -n <ns>
```

If a DROP appears for a legitimate flow → add a new allow rule, do NOT
remove the default-deny.

## 7. Outstanding work (not in this PR)

1. **Apply `10-data.yaml` to the live cluster** so `allow-apps-egress-kafka`
   becomes active. The CNP is already in main but apparently the file was
   never `kubectl apply`-ed (live cluster snapshot confirmed absent).
2. **Persistent vault token-reviewer** in `infras/k8s-yaml/vault-scripts/*`
   (Phase 2E) — separate PR.
3. **L7 CNP refinement** (Phase 2D) — only after ≥ 1 week of Phase 2C in
   enforcement with no false-positive drops.
