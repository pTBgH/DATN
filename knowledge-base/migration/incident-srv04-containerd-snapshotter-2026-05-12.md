# Incident: srv04 containerd dies → snapshotter metadata corrupt → cilium DS stuck

**Date:** 2026-05-12
**Affected VM:** `7189srv04` (worker, Ubuntu host, libvirt/KVM NAT `192.168.122.0/24`)
**Severity:** Medium — single node; no stateful workload pinned yet (vault/data/registry/spire namespaces empty at the time)
**Status:** Recovered by nuking `/var/lib/containerd` and re-pulling images. Documented here for future runbook reference.

---

## TL;DR

After a `7189srv04` reboot, containerd never came up cleanly. kubelet then crash-looped with `/run/containerd/containerd.sock: connect: no such file or directory`. Once containerd was restarted, the **overlayfs snapshotter** metadata was inconsistent with the on-disk snapshot directories, producing:

1. First failure: `failed to prepare extraction snapshot ... rename ... : file exists`
2. After wiping only `io.containerd.snapshotter.v1.overlayfs/`, a second failure appeared: `failed to create snapshot: missing parent "k8s.io/3/sha256:cfaaf08..." bucket: not found`

The second error is because the **global metadata DB** (`io.containerd.metadata.v1.bolt/meta.db`) still referenced snapshot chains for cached images whose underlying snapshot data had just been deleted. Only nuking `/var/lib/containerd` entirely brought the node back.

---

## Misdiagnosis: it looked like Tailscale was hung

User initially reported `sudo tailscale up` "treo không hồi kết". From the `journalctl -u tailscaled` excerpt the user pasted, Tailscale had actually reached **`Running`** state within ~2 seconds:

```
22:46:10 wgengine: Reconfig: user dialer
22:46:12 magicsock: home is now derp-20 (hkg)
22:46:12 Switching ipn state Starting -> Running (WantRunning=true, nm=true)
22:46:12 magicsock: derp-20 connected; connGen=1
22:46:16 wgengine: idle peer [zcSSF] now active, reconfiguring WireGuard
22:46:17 wgengine: idle peer [6CtiR] now active, reconfiguring WireGuard
22:47:10 wgengine: idle peer [py+22] now active, reconfiguring WireGuard
```

`tailscale status`, `tailscale ping 7189srv01`, and even `curl -k https://100.114.68.15:6443/livez` all succeeded. The "hang" was either:
- `sudo tailscale up` invoked without `--auth-key`, blocking on browser login URL prompt, OR
- `sudo tailscale up` re-invoked after Tailscale was already up (visible as `localapi: [PATCH] /localapi/v0/prefs`), with a few seconds of DNS reconfig retry due to `dhcpcd` trampling `/etc/resolv.conf`.

**Lesson:** when the symptom is "K8s node NotReady" and the user blames Tailscale, ALWAYS verify via `tailscale ip -4`, `tailscale ping <peer>`, and a `curl` to the apiserver before going down the VPN rabbit hole.

---

## Root cause chain

### Layer 1 — containerd not running

```
May 12 23:09:54 7189srv04 kubelet[5324]: E0512 23:09:54.755185
  failed to run Kubelet: validate service connection: validate CRI v1 runtime API for endpoint
  "unix:///run/containerd/containerd.sock":
  rpc error: code = Unavailable desc = connection error: desc =
  "transport: Error while dialing: dial unix /run/containerd/containerd.sock:
   connect: no such file or directory"
```

`containerd.service` either crashed at boot or was never started. `phases/host-prep.sh` does `systemctl enable --now containerd` at first install, but the unit can still fail to start on subsequent boots if:
- The `/var/lib/containerd` state was left in an inconsistent state by an unclean prior shutdown.
- The unit was manually `systemctl stop`-ed before reboot and `enable` did not survive a package upgrade.

`bash bootstrap.sh --server=04` (which re-runs idempotent `phases/host-prep.sh`) brought containerd back online.

### Layer 2 — overlayfs snapshotter rename conflict

After containerd was back, kubelet tried to pull `registry.k8s.io/pause:3.10.1` (containerd v2.x sandbox default) and `quay.io/cilium/cilium:v1.19.1@sha256:41f1f74...` (`crictl pull` actually succeeded — the image content was already in the local content store). However every snapshot extraction failed:

```
Failed to pull image "quay.io/cilium/cilium:v1.19.1@sha256:41f1f74a..." :
  failed to pull and unpack image ... :
  failed to prepare extraction snapshot "extract-3039186710-dImE
    sha256:cdc6e8bd8f77e1440c43e6b0a0667479c93067448ee14db00c84173c225cd5a6":
  failed to rename:
    rename /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/new-3039186710
           /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/73:
    file exists
```

The numbered snapshot directories (`snapshots/71`, `72`, `73`, ...) existed on disk from before the unclean shutdown, but the snapshotter's internal counter (in its own `metadata.db`) tried to assign new IDs starting from `73` again. Result: every extraction is a rename collision.

### Layer 3 — global metadata DB still references missing snapshot chains

We first tried to remove only the overlayfs snapshotter directory:

```bash
sudo mv /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs \
        /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs.broken.$(date +%s)
```

That **was not enough**. After delete + recreate of the cilium DS pod, the next failure mode was:

```
Failed to create pod sandbox: rpc error: code = NotFound desc =
  failed to start sandbox "...": failed to create containerd container:
  failed to create snapshot:
    missing parent "k8s.io/3/sha256:cfaaf0813a4d9e6addd475f126417ee9ebca9c1306006e708713df4246811e32" bucket: not found
```

Two interlocking sources of inconsistency:

1. The **global** metadata DB lives at `/var/lib/containerd/io.containerd.metadata.v1.bolt/meta.db` and tracks image manifests, leases, and **snapshot-chain references**. It still pointed at the snapshot key `k8s.io/3/sha256:cfaaf08...` (a parent layer of `pause:3.10.1`).
2. The overlayfs snapshotter's own metadata at `/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/metadata.db` was just regenerated empty.

The two are now misaligned: global metadata says "use snapshot `k8s.io/3/sha256:cfaaf08...`" → overlayfs snapshotter says "bucket not found".

`crictl images` still listed the images (content store was kept) but they were effectively unusable.

### Recovery — nuke the whole `/var/lib/containerd`

This worked the first try:

```bash
sudo systemctl stop kubelet
sudo systemctl stop containerd

sudo mv /var/lib/containerd /var/lib/containerd.broken.$(date +%s)
sudo mkdir -p /var/lib/containerd
sudo chmod 711 /var/lib/containerd

# Defensive CNI/netns cleanup so the next pod sandbox starts on a clean slate
sudo rm -rf /var/lib/cni /var/run/cni 2>/dev/null || true
sudo ip link show | awk -F': ' '/cilium_|lxc/{print $2}' | xargs -r -n1 sudo ip link delete 2>/dev/null || true

sudo systemctl start containerd
sleep 5
sudo systemctl start kubelet
```

Then from the control plane:

```bash
kubectl -n kube-system delete pod cilium-phmd5
```

Pull pause + cilium images on demand (~2-3 min over DERP "hkg" relay), DS pod reached `1/1 Running`.

Why this fixed it: containerd v2.2.3 reinitialized **all four** state pillars consistently from scratch:
- `io.containerd.content.v1.content/` (image content store)
- `io.containerd.metadata.v1.bolt/meta.db` (global metadata)
- `io.containerd.snapshotter.v1.overlayfs/` (snapshotter state)
- `io.containerd.runtime.v2.task/` (in-flight containers)

---

## Why this is safe (in our setup)

At the time of the incident, `7189srv04` held **no stateful workload** — `vault`, `data`, `registry`, `spire` namespaces were empty. The only thing running on srv04 was the Cilium DS pod (broken). Nuking `/var/lib/containerd` cost ~280 MB of re-pulled images and nothing else.

If srv04 had been hosting vault-dev, vault-prod, MySQL, Kafka, or the docker-registry, this **would not** have been safe. PVCs are local-path on srv04; pod state is in containerd's task store. A nuke would force restarts, which for vault-dev means **transit key loss → vault-prod loses auto-unseal**.

Going forward (once we move past `PROGRESS.md` Phase 3 and start pinning workload to srv04), recovery must be done by:
- Cordoning + draining srv04, OR
- Restoring the VMware/libvirt snapshot of srv04, OR
- Backing up `/var/lib/containerd/io.containerd.content.v1.content` + `io.containerd.metadata.v1.bolt` before touching the snapshotter.

---

## Resolution checklist (post-incident)

- [x] `kubectl get nodes` — all 4 nodes Ready
- [x] `kubectl -n kube-system get pod -l k8s-app=cilium -o wide` — 4 cilium pods `1/1 Running`
- [x] `kubectl describe node 7189srv04 | grep -A6 Conditions:` — Ready=True, others False (the `Unknown` LastTransitionTime artifact clears within ~60 s of new kubelet heartbeat)
- [x] No leftover `Pending` / `CrashLoop` / `ContainerCreating` pods
- [ ] `containerd.service` listed as `enabled` on srv04 — verified after reboot test
- [ ] VMware/libvirt snapshot `7189srv04-baseline` taken before any stateful workload is scheduled (see `12-runbook-recovery.md` §1)

---

## Updates pushed in the same PR

- `knowledge-base/migration/12-runbook-recovery.md`: new §13 "Containerd snapshotter corrupt after unclean shutdown" with the exact recovery procedure.
- `knowledge-base/migration/PROGRESS.md`: new install-progress tracker so the next session knows exactly which phase srv04 was at when this happened.

---

## Open follow-ups

1. **Why did `containerd.service` not auto-start at reboot?** `host-prep.sh` does `systemctl enable --now containerd`, but the failure mode here suggests something masks/disables the unit between boots. Candidates: (a) `apt-get` upgrade of `containerd.io` package mid-life, (b) manual `systemctl stop containerd` left over from prior debugging, (c) systemd dependency loop with `tailscaled.service` on a slow-starting Tailscale network. Worth adding a `Restart=on-failure` override and a boot-time health check.

2. **Add a snapshotter integrity check to `bootstrap.sh`.** Something like `ctr -n k8s.io snapshots ls | head` and `containerd config dump | grep -i snapshotter`. If we see the rename-conflict error in journalctl, run the recovery procedure automatically (with a confirmation prompt).

3. **`dhcpcd` trampling `/etc/resolv.conf` on srv04.** Not the cause of this incident but the warning log polluted diagnostics. Either switch srv04 to `systemd-resolved`, or add `nohook resolv.conf` to `/etc/dhcpcd.conf` so Tailscale's DNS config sticks.
