# ZTA Alert Catalog (PR-O Phase 2 + Phase 3 — Tier 1 + Tier 2)

> Lives in `infras/k8s-yaml/prometheus-rules.yaml` as a single ConfigMap
> mounted into the Prometheus pod. Apply via
> `bash scripts/zta-deploy-observability-rules.sh`. Verify rule
> registration with `promtool check rules` locally or, on the cluster,
> `GET /api/v1/rules` against the Prometheus pod.

## 1. Scope of this document

This is the operator-facing reference for every alerting rule that the
ZTA control plane ships out of the box. Each entry maps the alert to:

- a metric source (which component must be scraped for the rule to
  ever fire);
- the MITRE ATT&CK technique the alert is meant to surface;
- a severity (`warning` / `critical`) and routing team label
  (consumed by Alertmanager in PR-R);
- a one-line runbook intent so an on-call engineer knows the first
  triage step.

Three tiers of detection are described in `doc/24-adaptive-security-loop.md`:

1. **Tier 1 (PR-L + PR-O) — threshold-based Prometheus rules.** Cheap,
   deterministic, easy to reason about. Misses long-tail anomalies.
2. **Tier 2 (Phase 3, this PR) — statistical UEBA.** Z-score over
   1h rolling baselines (mean + stddev) for the high-volume metrics
   that Phase 2's `*Spike` rules approximate with a fixed `> Nx
   baseline` shape. Backed by 9 recording rules in group
   `zta-baselines`.
3. **Tier 3 (PR-T, future) — ML detector.** Tetragon kprobe event
   stream piped through an Isolation-Forest model.

Tier 1 + Tier 2 rules coexist where the baseline metric is the same,
but Tier 2 supersedes Tier 1 for the three "spike" alerts
(`*EventRateSpike`, `*CrossTierDropSpike`, `*RequestRateSpike`).

## 2. Alert catalog

Total: 19 alerting rules + 9 recording rules across 6 groups
(4 PR-L baseline + 13 PR-O Phase 2 + 2 Phase 3 new) +
`zta-baselines` recording rules backing Tier-2 z-score alerts.

### Group `zta-trust-score` (PR-L)

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTATrustScoreDropped` | warning | T1078 | `pdp_trust_score < 60` for 2m | `doc/25-pdp-controller.md` |
| `ZTACVECriticalImage` | critical | T1190 | `pdp_cve_critical_total > 0` for 1m | `doc/zta-gap-decision.md` |
| `ZTALabelDriftHigh` | warning | — | label drift rate > 5/min for 5m | `doc/19-label-schema.md` |

### Group `zta-network` (PR-L + PR-O + Phase 3)

Pre-req for Hubble-sourced rules: Cilium Helm values must enable
`hubble.metrics.enabled` with `sourceContext` + `destinationContext` +
`labelsContext`. See `k8s-management/cilium/cilium-values.yaml`. Without
those, `hubble_drop_total` carries only `protocol` + `reason` and the
three Hubble rules below never fire. Upgrade an existing cluster with
`bash scripts/zta-upgrade-cilium-hubble-metrics.sh`.

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTACiliumDropsHigh` (PR-L) | warning | — | per-reason drop rate > 10/s for 5m | `doc/05-observability-stack.md` |
| `ZTACiliumCrossTierDropZScore` (**Tier 2**) | warning | T1071 | per-(src,dst)-ns drop z-score > 3 sigma for 10m | `doc/34-microseg-phase2c-plan.md` |
| `ZTAHubbleDNSExfilSuspect` (PR-O) | warning | T1071 | per-pod rate of DNS queries with subdomain length ≥ 60 > 0.2/s for 10m | `doc/30-hubble-flow-sink.md` |
| `ZTAHubbleEgressToThreatCIDR` (Phase 3) | critical | T1041 | sustained egress drop with `reason="Policy denied"`, `traffic_direction="EGRESS"`, `destination=~".*reserved:(world\|unknown).*"` for 2m | `doc/24-adaptive-security-loop.md` |

### Group `zta-l7` (PR-O + Phase 3)

Metric source: Kong gateway prometheus plugin, scraped via pod annotation
`prometheus.io/port: "8100"` (landed in PR-N B2 fix).

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTAKongRequestRateZScore` (**Tier 2**) | warning | T1190 | per-service request z-score > 3 sigma for 10m | `doc/05-observability-stack.md` |
| `ZTAKong5xxRateHigh` | critical | T1190 | per-service 5xx ratio > 5% for 5m | `doc/05-observability-stack.md` |
| `ZTAKongLatencyP95High` | warning | — | per-service p95 latency > 1000ms for 5m | `doc/05-observability-stack.md` |
| `ZTAKongJWTAuthFailureSpike` | warning | T1078 | per-consumer 401-response rate > 10/min for 5m | `doc/api-authentication-guide.md` |

### Group `zta-runtime` (PR-O + Phase 3)

Metric source: Tetragon DaemonSet `/metrics` on `:2112` (PR-N B2 fix).
TracingPolicies that drive the kprobe-related metrics land in **PR-P**
(merged 2026-05-23). Chart 1.7.0 metric label set is limited to
`exported_namespace`, `exported_pod`, `workload`, `binary`, `type` —
no `function` / `file` / `policy` labels (see doc/14-tetragon-runtime.md).

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTATetragonEventRateZScore` (**Tier 2**) | warning | T1059 | per-workload event z-score > 3 sigma for 10m | `doc/14-tetragon-runtime.md` |
| `ZTATetragonShellExec` (Phase 3 tuned) | critical | T1059 | per-workload shell-binary exec rate > 0.1/s for 2m | `doc/14-tetragon-runtime.md` |
| `ZTATetragonShellExecBurst` (Phase 3 new) | critical | T1059 | per-workload shell-binary exec rate > 1/s for 1m | `doc/14-tetragon-runtime.md` |
| `ZTATetragonSensitiveFileRead` | critical | T1556 | any PROCESS_KPROBE event in `job7189-apps` (sensitive-file / suspicious-exec policies) | `doc/14-tetragon-runtime.md` |
| `ZTATetragonKernelModuleLoad` | critical | T1611 | host-namespace PROCESS_KPROBE event from a non-kubelet/containerd binary | `doc/14-tetragon-runtime.md` |

### Group `zta-cdm-trust` (PR-O)

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTACosignAdmissionDenied` | critical | T1543 | per-ns rate of `policy_controller_admission_decisions_total{decision="deny"}` > 0 for 2m | `doc/28-sigstore-policy-controller.md` |
| `ZTASpireAttestFailureRate` | warning | T1078 | per-instance `spire_server_node_attestor_failure_total` rate > 0.2/s for 5m | `doc/27-spire-workload-attestation.md` |
| `ZTACertExpirySoon` | warning | — | `certmanager_certificate_expiration_timestamp_seconds - time() < 7 days` for 1h | `doc/15-encryption-mtls-spiffe.md` |

### Group `zta-baselines` (Phase 3, recording rules)

Recording rules that pre-compute rolling baselines (mean + stddev) for
the Tier-2 z-score alerts above. Eval'd every 30s. Series naming
convention `zta:<source_metric>:<grouping>:<window>` per Prometheus
best practice; `:avg1h` / `:stddev1h` are the rolling baselines.

| Record | What | Backs |
|---|---|---|
| `zta:hubble_drop:cross_tier:rate_5m`{,`:avg1h`,`:stddev1h`} | Cross-ns drop rate baseline | `ZTACiliumCrossTierDropZScore` |
| `zta:kong_http_requests:service:rate_5m`{,`:avg1h`,`:stddev1h`} | Per-service Kong request rate baseline | `ZTAKongRequestRateZScore` |
| `zta:tetragon_events:workload:rate_5m`{,`:avg1h`,`:stddev1h`} | Per-workload Tetragon event rate baseline | `ZTATetragonEventRateZScore` |

Cold-start: during the first 1h after deploy, `:avg1h` / `:stddev1h`
ramp up from empty. Z-score alerts use `clamp_min(stddev1h, 0.001)`
+ an absolute lower bound to avoid spurious fires during this window.

## 3. MITRE ATT&CK coverage summary

Of the 19 alerts (4 PR-L baseline + 13 PR-O Phase 2 + 2 Phase 3 new),
the MITRE technique distribution is:

| Technique | Description | Alerts |
|---|---|---|
| T1059 | Command and Scripting Interpreter | `ZTATetragonEventRateZScore`, `ZTATetragonShellExec`, `ZTATetragonShellExecBurst` |
| T1190 | Exploit Public-Facing Application | `ZTAKongRequestRateZScore`, `ZTAKong5xxRateHigh` |
| T1611 | Escape to Host | `ZTATetragonKernelModuleLoad` |
| T1078 | Valid Accounts | `ZTAKongJWTAuthFailureSpike`, `ZTASpireAttestFailureRate`, `ZTATrustScoreDropped` |
| T1041 | Exfiltration over C2 channel | `ZTAHubbleEgressToThreatCIDR` |
| T1071 | Application Layer Protocol | `ZTACiliumCrossTierDropZScore`, `ZTAHubbleDNSExfilSuspect` |
| T1556 | Modify Authentication Process | `ZTATetragonSensitiveFileRead` |
| T1543 | Create or Modify System Process | `ZTACosignAdmissionDenied` |

Three alerts (`ZTAKongLatencyP95High`, `ZTACertExpirySoon`,
`ZTALabelDriftHigh`) carry no MITRE technique on purpose — they are
reliability / hygiene signals rather than active-attack indicators.

## 4. Validation

Local syntax check:

```bash
# Promtool 2.53+ (lab uses bundled version from PR-N B1 fix)
promtool check rules <(yq '.data."zta-rules.yml"' infras/k8s-yaml/prometheus-rules.yaml)
# Expected: 'SUCCESS: 28 rules found' (19 alerting + 9 recording)
```

In-cluster check (Prometheus must have been restarted via the deploy
script for the ConfigMap to be re-read):

```bash
POD=$(kubectl -n monitoring get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
kubectl -n monitoring exec "$POD" -- \
  wget -qO- http://localhost:9090/api/v1/rules \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(g['name'] for g in d['data']['groups']))"
# Expected (one line per group):
#   zta-trust-score
#   zta-network
#   zta-l7
#   zta-runtime
#   zta-cdm-trust
```

## 5. Acceptance criteria

- [x] `promtool check rules` reports `SUCCESS: 28 rules found`.
- [x] After running `scripts/zta-deploy-observability-rules.sh`,
      Prometheus `/api/v1/rules` lists all 6 groups (including new
      `zta-baselines`).
- [x] Phase 2 verification: ZTATetragonShellExec + ZTATetragonSensitiveFileRead
      fire on real shell-exec / kprobe events in `job7189-apps`
      (verified 2026-05-24 after chart 1.7.0 upgrade, PR #2).
- [ ] Phase 3 verification: after running
      `scripts/zta-upgrade-cilium-hubble-metrics.sh`, `hubble_drop_total`
      carries the labels `source_namespace`, `destination_namespace`,
      `traffic_direction`. Z-score recording rules in `zta-baselines`
      have non-empty series after 5 minutes of evaluation.
- [ ] Threat-intel CCNP installed via
      `scripts/zta-deploy-threat-intel.sh` and `ZTAHubbleEgressToThreatCIDR`
      fires when a pod in `job7189-apps` egresses to a FireHOL CIDR.

## 6. What this PR does NOT do

- Does **not** wire Alertmanager — routing by `team:` label remains
  out of scope (zta-gap-decision §2: explicit PoC tradeoff).
- Does **not** ship a Tier-3 ML detector — future work (PR-T).
- Does **not** modify the PDP / Trivy / cert-manager / SPIRE
  deployments. Phase 3 is observability + Cilium values only.

## 7. Phase 3 changelog (this PR)

- **Item 1 — Hubble metrics enablement (PR-Q fix path).** Edit
  `k8s-management/cilium/cilium-values.yaml` to add
  `hubble.metrics.enabled` with `sourceContext`, `destinationContext`,
  `labelsContext` configured for the three Hubble alerts. Add a new
  Prometheus scrape job `cilium-hubble` (port 9965) in
  `infras/k8s-yaml/08-prometheus.yaml`. Rewrite
  `ZTAHubbleEgressToThreatCIDR` to filter on
  `reason="Policy denied"` + `destination=~".*reserved:world.*"`
  instead of the non-existent `reason="ThreatIntel"` label.
  Upgrade an existing cluster with
  `bash scripts/zta-upgrade-cilium-hubble-metrics.sh`.
- **Item 2 — Tier-2 z-score alerts.** Replace three fixed-multiplier
  baseline alerts (`*EventRateSpike`, `*RequestRateSpike`,
  `*CrossTierDropSpike`) with z-score variants backed by 9 recording
  rules in new group `zta-baselines`. Z-score = (current - 1h mean) /
  1h stddev, threshold > 3 sigma + absolute floor to avoid trivially
  low traffic firing.
- **Item 3 — Grafana dashboard expansion.** New dashboard
  `infras/k8s-yaml/grafana-dashboards/zta-runtime-network.json`
  (UID `zta-phase3-runtime`) with 12 panels covering active firing
  alerts, Tetragon event/shell/kprobe rates, Hubble drops by reason +
  cross-tier, Kong request / 5xx / p95 latency, Cosign admission,
  Tetragon agent health, and threat-intel blocklist status.
- **Item 4 — ShellExec noise tuning.** Raise `ZTATetragonShellExec`
  threshold from `> 0` (fired on every healthcheck) to `> 0.1/s`
  sustained for 2 minutes. Add `ZTATetragonShellExecBurst` for high-
  velocity attack loops (`> 1/s` for 1 minute).
