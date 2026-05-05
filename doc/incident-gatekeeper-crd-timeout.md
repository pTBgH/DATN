# Incident: Gatekeeper CRD install timeout (step 26-gatekeeper)

**Date:** 2026-05-05
**Rebuild log:** `evidence/rebuild_20260505_092417/26-gatekeeper.log`
**Severity:** High — crashed the lab VM
**Status:** Fixed in `scripts/zta-deploy-gatekeeper.sh` (retry wrapper + apiserver pre-flight)

---

## Symptom

```
▶ 26-gatekeeper — Deploy OPA Gatekeeper + ZTA constraints
  cmd: bash scripts/zta-deploy-gatekeeper.sh
  timeout: 600s
  ✗ 26-gatekeeper FAILED (exit=1, 52s)
  ──── DIAGNOSTICS for failed step '26-gatekeeper' ────
    | [1/4] Installing OPA Gatekeeper 3.16.3 via helm...
    | namespace/gatekeeper-system created
    | Error: INSTALLATION FAILED: failed to install CRD
    |   crds/syncset-customresourcedefinition.yaml:
    |   Timeout: request did not complete within requested timeout -
    |   context deadline exceeded
```

The failure took down the VM — after helm exited, etcd/apiserver never
recovered because the load-average was already 190+ when the request
arrived.

## Root cause

Helm, during its first `helm install` phase, creates all CRDs shipped in
the chart's `crds/` directory. Each CRD is a separate `POST` request to
`kube-apiserver`. The `Timeout: request did not complete within requested
timeout - context deadline exceeded` message is **not** from helm — it is
from the Kubernetes apiserver returning a 504 because it failed to
process the request within its own `--request-timeout` (default 60 s).

Why the apiserver was slow:
- Host VM had 1-min load average ≈ 191 on a 4-CPU host
- 80 pods running (Vault + 7 micros + 7 Redis + SPIRE + Tetragon +
  ELK + Prometheus + Grafana + Hubble + Kong + cert-manager +
  policy-controller + Cilium DS × 4 + …)
- etcd on the same control-plane node was already saturated writing
  leases / pod-status updates

Increasing helm's `--timeout` does **not** fix this — that flag controls
the overall operation budget, not the per-request timeout. The apiserver
will keep returning 504 on every subsequent attempt that starts while
the cluster is overloaded.

## Fix (in `scripts/zta-deploy-gatekeeper.sh`)

1. **Pre-flight apiserver health check** before running helm install:
   `kubectl get --raw=/readyz --request-timeout=10s` with up to 6 retries
   (30 s backoff = 180 s max wait). If apiserver still not healthy,
   abort **before** creating the namespace — avoids orphan resources.

2. **Host load warning**: if `/proc/loadavg` 1-min is > 20, sleep 30 s
   as cooldown before installing. Loud warning so the operator can decide
   to cancel and free RAM first.

3. **Retry wrapper** around `helm install`: up to 3 attempts with 30 s
   backoff between. On each retry:
   - `helm uninstall` any partial release
   - Delete any CRDs matching `*.gatekeeper.sh` (helm does NOT clean up
     CRDs created by a failed install)
   - Re-check `/readyz` before the next attempt

4. **Explicit `--timeout 15m`** on helm install/upgrade, so the *overall*
   budget is generous enough that the retry logic actually gets a chance
   to run before the step-level 600 s timeout in `zta-rebuild.sh` kicks in.

## Operational guidance

If you see this error again, do **NOT** re-run `bash scripts/zta-rebuild.sh`
immediately. First check host health:

```bash
# Host load & RAM
uptime && free -m | head -2

# Apiserver responsiveness (should return <1s)
time kubectl get --raw=/readyz

# Recent OOMKill / CrashLoop
kubectl get pod -A --no-headers | awk '$5+0 > 3 || $4 == "CrashLoopBackOff"'
```

If load avg > 20 or apiserver is slow (>5 s on /readyz), wait.
Likely the previous step (e.g. 24-hubble-export) stacked enough ELK /
Filebeat workload to saturate the control plane. Give it 2–3 minutes
to quiesce, then resume:

```bash
bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes
```

If the failure recurs even with the retry wrapper, free RAM before
trying again:

```bash
# Reduce ELK retention / Prometheus scrape interval / delete old jobs
kubectl -n monitoring scale deploy/grafana --replicas=0   # temporarily
# … run step 26 …
kubectl -n monitoring scale deploy/grafana --replicas=1
```

## Related incidents

- `doc/incident-falco-tetragon-ram-overcommit.md` — earlier root cause of host
  overcommit that led to this secondary failure.
- `doc/incident-gatekeeper-probe-webhook-stuck.md` — follow-up failure
  (rebuild_20260505_142433): the chart's post-install probeWebhook hook
  hangs helm install when the apiserver is healthy but the cluster is
  too loaded to schedule the controller-manager pod.
- Commit `313178f` — Falco removal + Tetragon 256→384 Mi.

## Verification

After the fix, the script will:
- Not start helm install if /readyz is bad → no orphan resources.
- Retry on 504 automatically → succeeds as soon as apiserver quiesces.
- Surface a clean error message ("helm install failed 2 times —
  apiserver overload") if the cluster genuinely can't hold Gatekeeper.
