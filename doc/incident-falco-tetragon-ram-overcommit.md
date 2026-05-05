# Incident: Falco + Tetragon + 12 GiB host → OOM cascade

**Date:** 2026-05-05
**Rebuild logs:** `evidence/rebuild_20260505_063612/`, `..._080001/`, `..._080551/`, `..._082648/`
**Severity:** High — cascading control-plane OOMKills
**Status:** Fixed in commit `313178f` (Falco removed, Tetragon 256 → 384 Mi, Gatekeeper sequential CRD apply)

---

## Symptoms observed

During step **25-falco** and subsequent **26-gatekeeper**:

- `metrics-server` exit code **137** (OOMKilled), 15 restarts
- `tetragon` DS exit **137**, 12–14 restarts per node
  Tetragon logs: `DeltaFIFO Pop Process … slow event handlers blocking the queue`
  Tetragon liveness gRPC 60 s timeout
- `cilium-operator` CrashLoop × 10
- `policy-controller-webhook` exit 2 × 15
- `cert-manager-webhook` probe timeouts
- `kube-controller-manager` / `kube-scheduler` leader-election flapping (6 restarts each)
- `etcdserver: request timed out` during Gatekeeper pre-install hook
- Host swap usage grew 0.7 → 1.3 GiB
- `v1beta1.metrics.k8s.io` APIService went stale → namespace deletion blocked

## Arithmetic of the overcommit

Snapshot during the failure:

| Scope                              | Memory   |
|------------------------------------|----------|
| Host RAM                           | 12 288 Mi |
| Sum of **pod memory limits**       | 17 012 Mi (**1.38× overcommit**) |
| worker3 alone                      | 7 688 Mi limits (62 % of host on one node) |
| worker3 requests (what scheduler saw) | 2 792 Mi (23 %) |

Linux schedules by *requests* but processes grow toward *limits*.
Adding Falco DS (≈ 256 Mi × 4 nodes + 128 Mi sidekick ≈ 1 GiB working set)
was enough to push actual RSS past available host RAM. Kernel started
swapping → Tetragon userspace event handler stalled → liveness failed →
cascading restarts of anything with a short probe.

## Why Falco + Tetragon is a bad pair on this host

- **Both** are DaemonSets attaching eBPF probes.
- **Both** maintain per-pod userspace ring buffers + BPF maps.
- BPF map slots and kernel ring-buffer pages are bounded kernel resources;
  two high-event-rate agents on the same node cause eviction thrashing.
- On this 12 GiB VM the combined working set (~2 GiB) was the difference
  between fit and not-fit.

Upstream Cilium + Tetragon docs note this explicitly:
[Tetragon already covers the MITRE ATT&CK paths](https://tetragon.io/docs/use-cases/)
that Falco's core ZTA rules target (T1068 priv-esc, T1552 secret access,
T1078 identity hijack). Falco's remaining differentiator on this lab is
the k8s audit rules, which `cilium hubble`-flow logs + Tetragon process
events already approximate.

## Fix (committed in `313178f`)

1. **Removed 25-falco** from the `STEPS` array in `scripts/zta-rebuild.sh`.
   Script `scripts/zta-deploy-falco.sh` and `infras/k8s-yaml/falco/values.yaml`
   kept on disk as future-work artifacts (multi-node lab).
2. **Tetragon memory limit 256 → 384 Mi** in `10-deploy-tetragon.sh`
   (`TETRAGON_MEM_LIM` default). Eliminates OOMKill on busy clusters.
3. **Gatekeeper apply templates sequentially** with `kubectl wait
   --for=condition=Established` on each CRD before applying the next
   Constraint. Avoids a race where the controller-manager under load
   drops CRD generation for later templates.
4. **Gatekeeper controller-manager + audit 256 → 384 Mi** + explicit
   CPU requests (100 m) / limits (500 m).

## Guardrails added

- `scripts/zta-rebuild.sh` — `do_module_rollback` for steps 26/27
  surgically removes the failed helm release without touching the rest
  of the cluster. Retry path: `--from=<step> --skip-cluster --yes`.
- `ZTA_MODULE_ROLLBACK=0` escape hatch to leave failed release in place
  for manual inspection before retry.

## Verification after fix

- Tetragon DS ran 30+ minutes with **0 restarts** after the mem bump.
- Steps 01-24 completed cleanly in `rebuild_20260505_114551` (4567 s total).
- Step 26 now gated by apiserver `/readyz` health + helm retry
  (see `doc/incident-gatekeeper-crd-timeout.md` and
  `doc/incident-gatekeeper-probe-webhook-stuck.md`).

## Next-attempt checklist

Before re-running the pipeline with the fixes:

```bash
# 1. Host load must be < 10 for step 26 to have a chance
uptime
# 2. Host available RAM must be > 1.5 GiB
free -m | head -2
# 3. Apiserver must respond to /readyz in < 1 s
time kubectl get --raw=/readyz
```

If any of the above is bad, wait; do NOT run the pipeline.
