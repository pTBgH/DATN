# ZTA Alert Catalog (PR-O — Phase 2 Security Analytics, Tier 1)

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

1. **Tier 1 (this PR) — threshold-based Prometheus rules.** Cheap,
   deterministic, easy to reason about. Misses long-tail anomalies.
2. **Tier 2 (PR-S) — statistical UEBA.** Z-score / Holt-Winters over
   rolling baselines for the high-volume metrics that this document's
   `*Spike` rules approximate with a fixed `> 3x baseline` shape.
3. **Tier 3 (PR-T) — ML detector.** Tetragon kprobe event stream
   piped through an Isolation-Forest model.

The Tier-1 rules here intentionally use static thresholds and short
baselines (`5m` rate vs `1h offset 5m` baseline). They are the floor
of the detection ladder, not the ceiling.

## 2. Alert catalog

Total: 18 rules across 5 groups (4 PR-L baseline + 14 new in PR-O).

### Group `zta-trust-score` (PR-L)

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTATrustScoreDropped` | warning | T1078 | `pdp_trust_score < 60` for 2m | `doc/25-pdp-controller.md` |
| `ZTACVECriticalImage` | critical | T1190 | `pdp_cve_critical_total > 0` for 1m | `doc/zta-gap-decision.md` |
| `ZTALabelDriftHigh` | warning | — | label drift rate > 5/min for 5m | `doc/19-label-schema.md` |

### Group `zta-network` (PR-L + PR-O)

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTACiliumDropsHigh` (PR-L) | warning | — | per-reason drop rate > 10/s for 5m | `doc/05-observability-stack.md` |
| `ZTACiliumCrossTierDropSpike` (PR-O) | warning | T1071 | per-(src,dst)-ns drop rate > 3× 1h baseline for 10m | `doc/34-microseg-phase2c-plan.md` |
| `ZTAHubbleDNSExfilSuspect` (PR-O) | warning | T1071 | per-pod rate of DNS queries with subdomain length ≥ 60 > 0.2/s for 10m | `doc/30-hubble-flow-sink.md` |
| `ZTAHubbleEgressToThreatCIDR` (PR-O) | critical | T1041 | any drop tagged `reason="ThreatIntel"` for 1m | `doc/24-adaptive-security-loop.md` |

### Group `zta-l7` (PR-O)

Metric source: Kong gateway prometheus plugin, scraped via pod annotation
`prometheus.io/port: "8100"` (landed in PR-N B2 fix).

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTAKongRequestRateSpike` | warning | T1190 | per-service request rate > 3× 1h baseline for 10m | `doc/05-observability-stack.md` |
| `ZTAKong5xxRateHigh` | critical | T1190 | per-service 5xx ratio > 5% for 5m | `doc/05-observability-stack.md` |
| `ZTAKongLatencyP95High` | warning | — | per-service p95 latency > 1000ms for 5m | `doc/05-observability-stack.md` |
| `ZTAKongJWTAuthFailureSpike` | warning | T1078 | per-consumer 401-response rate > 10/min for 5m | `doc/api-authentication-guide.md` |

### Group `zta-runtime` (PR-O)

Metric source: Tetragon DaemonSet `/metrics` on `:2112` (PR-N B2 fix).
The kprobe-driven rules in this group (`ZTATetragonShellExec`,
`ZTATetragonSensitiveFileRead`, `ZTATetragonKernelModuleLoad`) require
matching TracingPolicies; those policies ship in **PR-P**. Until PR-P
lands, those three rules stay quiet because their target metric series
does not exist.

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTATetragonEventRateSpike` | warning | T1059 | per-pod event rate > 5× 1h baseline for 10m | `doc/14-tetragon-runtime.md` |
| `ZTATetragonShellExec` | critical | T1059 | shell binary exec event ≥ 1 for 1m | `doc/14-tetragon-runtime.md` |
| `ZTATetragonSensitiveFileRead` | critical | T1556 | read of `/etc/shadow`, `/etc/kubernetes/admin.conf`, or `/var/run/secrets/.*sa.*` | `doc/14-tetragon-runtime.md` |
| `ZTATetragonKernelModuleLoad` | critical | T1611 | `init_module` / `finit_module` syscall event | `doc/14-tetragon-runtime.md` |

### Group `zta-cdm-trust` (PR-O)

| Alert | Severity | MITRE | Triggers on | Runbook |
|---|---|---|---|---|
| `ZTACosignAdmissionDenied` | critical | T1543 | per-ns rate of `policy_controller_admission_decisions_total{decision="deny"}` > 0 for 2m | `doc/28-sigstore-policy-controller.md` |
| `ZTASpireAttestFailureRate` | warning | T1078 | per-instance `spire_server_node_attestor_failure_total` rate > 0.2/s for 5m | `doc/27-spire-workload-attestation.md` |
| `ZTACertExpirySoon` | warning | — | `certmanager_certificate_expiration_timestamp_seconds - time() < 7 days` for 1h | `doc/15-encryption-mtls-spiffe.md` |

## 3. MITRE ATT&CK coverage summary

Of the 14 alerts introduced in PR-O, the MITRE technique distribution is:

| Technique | Description | Alerts |
|---|---|---|
| T1059 | Command and Scripting Interpreter | `ZTATetragonEventRateSpike`, `ZTATetragonShellExec` |
| T1190 | Exploit Public-Facing Application | `ZTAKongRequestRateSpike`, `ZTAKong5xxRateHigh` |
| T1611 | Escape to Host | `ZTATetragonKernelModuleLoad` |
| T1078 | Valid Accounts | `ZTAKongJWTAuthFailureSpike`, `ZTASpireAttestFailureRate` |
| T1041 | Exfiltration over C2 channel | `ZTAHubbleEgressToThreatCIDR` |
| T1071 | Application Layer Protocol | `ZTACiliumCrossTierDropSpike`, `ZTAHubbleDNSExfilSuspect` |
| T1556 | Modify Authentication Process | `ZTATetragonSensitiveFileRead` |
| T1543 | Create or Modify System Process | `ZTACosignAdmissionDenied` |

Two alerts (`ZTAKongLatencyP95High`, `ZTACertExpirySoon`) carry no
MITRE technique on purpose — they are reliability / hygiene signals
rather than active-attack indicators.

## 4. Validation

Local syntax check:

```bash
# Promtool 2.53+ (lab uses bundled version from PR-N B1 fix)
promtool check rules <(yq '.data."zta-rules.yml"' infras/k8s-yaml/prometheus-rules.yaml)
# Expected: 'SUCCESS: 18 rules found'
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

## 5. Acceptance criteria for closing PR-O

- [ ] `promtool check rules` reports `SUCCESS: 18 rules found`.
- [ ] After re-running `scripts/zta-deploy-observability-rules.sh`,
      Prometheus `/api/v1/rules` lists all 5 groups.
- [ ] At least the PR-L groups (`zta-trust-score`, `zta-network`) have
      live samples for their alert expressions — verify with
      `wget -qO- http://localhost:9090/api/v1/query?query=pdp_trust_score`.
- [ ] At least one Kong rule has live samples (verifies the PR-N B2
      fix is in effect on the running cluster):
      `wget -qO- http://localhost:9090/api/v1/query?query=kong_http_requests_total`.

## 6. What this PR does NOT do

- Does **not** install Tetragon TracingPolicies — those land in **PR-P**.
  Without them, the three kprobe-driven `ZTATetragon*` rules stay
  quiet (no series for the matching `event_type=...` labels).
- Does **not** wire Alertmanager — routing by `team:` label is **PR-R**.
- Does **not** add a Grafana dashboard for the new alerts — dashboard
  expansion is **PR-O-followup** once the rules have a few days of
  baseline data.
- Does **not** ship the threat-intel CCNP that feeds
  `ZTAHubbleEgressToThreatCIDR` — that CCNP lands in **PR-Q**. Until
  then the alert is a no-op (no series matches `reason="ThreatIntel"`).
- Does **not** modify the PDP / Trivy / cert-manager / SPIRE
  deployments. PR-O is rules-only on top of metrics that PR-L, PR-N
  and earlier PRs already make scrapeable.
