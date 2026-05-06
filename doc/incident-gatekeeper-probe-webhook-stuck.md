# Incident: Gatekeeper post-install probeWebhook hook hangs helm install

**Date:** 2026-05-05 (follow-up to `doc/incident-gatekeeper-crd-timeout.md`)
**Rebuild log:** `evidence/rebuild_20260505_142433/SUMMARY.md` (TIMEOUT 1501s)
**Severity:** High — host VM crashed (cluster ended with `Total pods: 0`)
**Status:** Fixed in `scripts/zta-deploy-gatekeeper.sh`
  (`postInstall.probeWebhook.enabled=false` + `--no-hooks` + RAM pre-flight)

---

## Symptom

After `doc/incident-gatekeeper-crd-timeout.md` was supposedly fixed
(commit `f7ab2ca` raised the per-step budget to 1500s and added a
`/readyz` pre-flight + 3× helm install retry), the next rebuild attempt
still failed:

```
| 26-gatekeeper | TIMEOUT | 1501s | 26-gatekeeper.log |

## Cluster snapshot at end
Total pods: 0
```

`Total pods: 0` is the smoking gun — by the time the orchestrator wrote
its summary, the kind-job7189 control plane had collapsed entirely.

## Root cause

The Gatekeeper helm chart (3.16.3) ships a **post-install Job** named
`gatekeeper-probe-webhook-post-install`. It runs `curlimages/curl`
against the webhook service:

```
curl --retry 99999 --retry-connrefused --retry-max-time 60 \
     --retry-delay 1 --max-time 2 --cacert /certs/ca.crt -v \
     https://gatekeeper-webhook-service.gatekeeper-system.svc/v1/admitlabel?timeout=2s
```

It is a Helm `post-install` hook, so `helm install` **waits** for it to
succeed before exiting.

In `evidence/rebuild_20260505_082648/26-gatekeeper.diag.txt` we observed:

- `gatekeeper-probe-webhook-post-install-f6bq5` stuck in
  `ContainerCreating` for ~112 s.
- `gatekeeper-controller-manager-b9894d9` ReplicaSet emitting:
  ```
  FailedCreate Error creating: Internal error occurred:
  resource quota evaluation timed out
  ```
- `policy-controller-webhook` (cosign-system) restarting (23 restarts).
- `spire-server-0` in `CrashLoopBackOff` (15 restarts).
- All other webhooks (`cilium-envoy`, `cert-manager-webhook`,
  `kube-controller-manager`, …) flapping with
  `context deadline exceeded` on probes.

The cluster was so saturated that the controller-manager pod could not
be scheduled inside the curl probe's 60 s budget, so the hook failed
(curl exit 7) — but only after `helm install` had been blocking for
several minutes per attempt while the host RAM cascade rolled forward.

The retry loop turned this from "slow failure" into "fatal failure":
each helm retry kicked off another `gatekeeper-probe-webhook-post-install`
Job, another fresh `gatekeeper-controller-manager` ReplicaSet, etc.
Combined with the existing 76 pods this pushed the 12 GiB lab VM past
its limits and OOM-killed the kubelets, etcd, and apiserver.

## Fix (in `scripts/zta-deploy-gatekeeper.sh`)

1. **Disable the chart hook** with
   `--set postInstall.probeWebhook.enabled=false`. Combined with
   `--no-hooks` on `helm install` itself, no hook can ever block the
   install. We replace the curl probe with our own check:
   `kubectl rollout status deploy/gatekeeper-controller-manager --timeout=300s`
   followed by a service-endpoints poll.

2. **Host RAM pre-flight (`MIN_FREE_MIB`, default 1500)**. The script
   now refuses to install if `/proc/meminfo` reports less than
   1500 MiB available. This is the single most reliable guard against
   the death-spiral, because the failure is fundamentally an
   overcommit problem. Override with `MIN_FREE_MIB=0` (NOT recommended)
   for explicit operator opt-in.

3. **Retry budget tightened from 3 → 2** to keep the helm phase under
   ~21 min in the worst case (2 × 10 min + 30 s backoff). The previous
   3-attempt loop on its own could burn 45 min, exceeding the original
   1500 s step budget by ~2×.

4. **Helm `--timeout 10m`** (was 15 m). With `--no-hooks` the chart
   only has to install the core Deployment + ServiceAccount + RBAC +
   webhook configurations — none of which need 15 minutes on a healthy
   cluster.

5. **Step budget bumped 1500 → 2700 s** in `scripts/zta-rebuild.sh`
   (`STEP_TIMEOUTS[26-gatekeeper]`). Even with the tighter retry, the
   degenerate worst case — both helm installs hitting their 10 min
   timeout, both rollout-status calls draining their full budget, and
   all 6 ConstraintTemplate CRD waits maxing at 120 s each — sums to
   ~2610 s. 2700 s gives a small slack on top so the orchestrator
   doesn't kill a script that is genuinely making progress. See the
   commented arithmetic in `scripts/zta-rebuild.sh:[26-gatekeeper]`.
   **Subsequently bumped 2700 → 3600 s** when phase-2 below was fixed
   (CPU-throttle CRD wait + load-poll); see Phase 2 section.

---

## Phase 2: Follow-on failure — CPU-throttled controller, CRD never Established

**Date:** 2026-05-05 (later same day)
**Rebuild log:** `evidence/rebuild_20260505_152348/26-gatekeeper.log`
**Severity:** Medium — orchestrator caught it; cluster preserved by
  module-rollback. The fixes from Phase 1 (above) were all working
  correctly; this is a new failure mode that surfaced *after* helm
  install + webhook readiness succeeded.

### Symptom

Phase 1 fixes did their job: the `gatekeeper-probe-webhook-post-install`
hook is gone, helm install exits in <30 s, and rollout-status passes
for both `gatekeeper-controller-manager` and `gatekeeper-audit`.
Step 26 now fails further along, in `[3/4] Applying ConstraintTemplates`:

```
[3/4] Applying ConstraintTemplates (sequentially, with CRD wait)...
    + 01-constraint-template-required-zta-labels.yaml
constrainttemplate.templates.gatekeeper.sh/ztarequiredlabels created
      waiting for crd/ztarequiredlabels.constraints.gatekeeper.sh to be Established (up to 120s)...
    ✗ CRD ztarequiredlabels.constraints.gatekeeper.sh never reached Established
```

### Root cause

Gatekeeper's controller-manager is responsible for taking each
`ConstraintTemplate` object, compiling its embedded Rego policy, and
POSTing a dynamically-generated CRD (e.g.
`ztarequiredlabels.constraints.gatekeeper.sh`) for the apiserver to
register. The 120 s `kubectl wait --for=condition=Established` budget
was tuned for a healthy controller — but on a CPU-saturated host this
isn't enough.

Evidence from `26-gatekeeper.log` and the events tail:

- Pre-flight saw `host 1-min load average is 66` and only slept 30 s.
  After the cooldown the load was almost certainly still ≥ 50.
- `kube-apiserver-job7189-control-plane`: `Readiness probe failed: HTTP probe failed with statuscode: 500`.
- `gatekeeper-controller-manager-…`: container started at t≈52 s but
  `Readiness probe failed: connect: connection refused` on
  `:9090/readyz` 30 s later — i.e. the readiness server hadn't bound
  yet, even though the container was running.
- `gatekeeper-audit-…`: same `connection refused` pattern on liveness
  AND readiness.
- `vault-0`: `Readiness probe failed: command timed out` (10 s).

The Deployment becoming `Available` (which is what `kubectl rollout
status` waits for) is **not** the same as the controller-manager
having finished leader-election + opening its webhook server +
warming its template-reconciler caches. On a CPU-throttled host all
of those steps happen in slow-motion. The first `ConstraintTemplate`
apply lands while the controller is still warming up, and the
reconciler doesn't manage to compile + POST the CRD inside 120 s.

### Phase-2 fix (in `scripts/zta-deploy-gatekeeper.sh`)

1. **Smarter load handling.** The previous "warn + sleep 30 s" was
   useless when load > 50. Replaced with:
   - `LOAD_HARD_FAIL` (default 100): refuse to start if load >100.
   - `LOAD_WAIT_THRESHOLD` (default 20) / `LOAD_OK_THRESHOLD`
     (default 30) / `LOAD_WAIT_MAX_S` (default 300 s): poll
     `/proc/loadavg` every 30 s and only proceed once load drops
     below `LOAD_OK_THRESHOLD`. Capped at 300 s so the step still
     terminates if the host stays hot.
2. **Controller-manager Ready-stable settle (max 180 s).** After
   `rollout status` succeeds, poll the controller-manager pod's
   `Ready` condition and require **30 consecutive seconds** of
   `Ready=True` before applying any ConstraintTemplate. This catches
   the readiness-flap pattern that the rollout check can race past.
3. **Per-template CRD-wait split.**
   - First template: `CRD_WAIT_FIRST` (default `300s`). Cold-start
     for the controller-manager reconciler — caches, leader-
     election, webhook server, first Rego compile.
   - Subsequent templates: `CRD_WAIT_REST` (default `120s`). The
     controller stays warm, so each subsequent CRD usually
     Establishes in seconds.
4. **`gatekeeper-audit` rollout-status timeout 240 → 120 s.** The
   audit Deployment is **not** on the CRD-generation critical path
   (it runs the periodic audit loop, not the template reconciler),
   so we don't burn step budget waiting for it. Still `|| true`, so
   a slow audit pod doesn't fail the whole step.
5. **Step budget bumped 2700 → 3600 s** (`STEP_TIMEOUTS[26-gatekeeper]`).
   New worst-case math (see comment on the assignment) sums to
   ~3305 s; 3600 s leaves headroom.

### Operational guidance for Phase 2

If step 26 still fails at the CRD wait, run:

```bash
# 1) What's the host load? Anything above ~30 will starve the
#    controller-manager reconciler.
uptime
# Override the script's pre-flight if you've already manually
# verified the cluster is healthy:
LOAD_OK_THRESHOLD=50 bash scripts/zta-rebuild.sh \
  --from=26-gatekeeper --skip-cluster --yes

# 2) Inspect the ConstraintTemplate object — Rego compile errors
#    show up here, not in the CRD wait error.
kubectl describe constrainttemplate ztarequiredlabels

# 3) Tail controller-manager logs. Look for "compile error",
#    "leader election lost", or repeated "Reconciler error".
kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager --tail=200

# 4) If only the FIRST CRD is timing out, give it more time:
CRD_WAIT_FIRST=600s bash scripts/zta-deploy-gatekeeper.sh
```

### Phase-2 verification

The fix is verified when:

- `[0c] pre-flight load wait` either logs `load dropped to N` or
  `proceeding immediately` (i.e. the script doesn't just warn-sleep-30s).
- `[2/4] controller-manager stable Ready for 30s` appears before
  `[3/4]` starts.
- The first `ztarequiredlabels` CRD reaches `Established` within
  the new 300 s budget on a host with load < 30.
- The orchestrator step record is `OK`, not `TIMEOUT`/`FAILED`.

## Operational guidance

If the rebuild fails again at step 26 with the new script:

```bash
# 1) Confirm host RAM is the problem (most likely on the lab VM)
free -m | head -2
# If MemAvailable < 1500 MiB, the [0a/4] pre-flight inside
# scripts/zta-deploy-gatekeeper.sh now auto-runs free-ram-for-gatekeeper.sh
# (toggle Kibana/Grafana/Kafbat/phpMyAdmin off + drop_caches).
# Run it manually if you need to free RAM before the next pipeline retry:
bash scripts/free-ram-for-gatekeeper.sh
# Re-enable the UIs after step 27:  bash scripts/toggle-internal-ui.sh on

# 2) Confirm apiserver is healthy
time kubectl get --raw=/readyz   # < 1 s expected

# 3) Confirm controller-manager pod is being created
kubectl -n gatekeeper-system get pod
kubectl -n gatekeeper-system get events --sort-by=.lastTimestamp | tail -20

# 4) Re-run only step 26
bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes
```

If `kubectl rollout status` keeps failing despite RAM being free,
check the upstream incident:
- `policy-controller-webhook` healthy? (its admission timeout would
  block pod creation in `gatekeeper-system`)
- `cilium-envoy` healthy? (CNI probe failures starve pod networking)
- `spire-server-0` healthy? (spire mTLS cascade)

## Verification

The fix is verified when, on a freshly-rebuilt cluster:

- `helm install gatekeeper` exits in **under 2 minutes** (no curl probe
  Job to wait for).
- `kubectl -n gatekeeper-system get jobs` shows **no**
  `gatekeeper-probe-webhook-post-install` job (chart hook disabled).
- `kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager`
  returns success within the 300 s budget.
- `kubectl -n gatekeeper-system get endpoints gatekeeper-webhook-service`
  shows ≥1 backing pod IP.
- The orchestrator step record is `OK`, not `TIMEOUT`.

## Related incidents

- `doc/incident-gatekeeper-crd-timeout.md` — original 504-on-CRD failure.
- `doc/incident-falco-tetragon-ram-overcommit.md` — root cause of the
  host overcommit that makes step 26 brittle in the first place.
