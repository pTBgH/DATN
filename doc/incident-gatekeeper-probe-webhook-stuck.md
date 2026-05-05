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

3. **Retry budget tightened from 3 → 2** so the total wall-clock fits
   inside the orchestrator's 1500 s step budget even in the worst case
   (2 × 10 min helm timeout + 30 s backoff = 1230 s ≪ 1500 s).

4. **Helm `--timeout 10m`** (was 15 m). With `--no-hooks` the chart
   only has to install the core Deployment + ServiceAccount + RBAC +
   webhook configurations — none of which need 15 minutes on a healthy
   cluster.

## Operational guidance

If the rebuild fails again at step 26 with the new script:

```bash
# 1) Confirm host RAM is the problem (most likely on the lab VM)
free -m | head -2
# If MemAvailable < 1500 MiB, free RAM by scaling down ELK / Grafana:
kubectl -n monitoring scale deploy/grafana --replicas=0
kubectl -n logging    scale deploy/kibana   --replicas=0
kubectl -n logging    scale sts/elasticsearch --replicas=1

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
