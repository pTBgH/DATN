# Transition: srv04 (NAT) → srv05 (bridge)

Replace the data-tier worker `7189srv04` (Ubuntu host, libvirt **NAT**
network `192.168.122.0/24`) with `7189srv05` (Ubuntu 24.04 LTS, libvirt
**bridge** network). Reason: srv04 sits behind a double NAT (libvirt
default NAT + ISP CGNAT) so Tailscale cannot establish direct
peer-to-peer connections (`MappingVariesByDestIP: true`) — all kubelet
and cilium traffic falls back to the DERP-hkg relay, which under load
saturates and breaks TCP. See
`doc/migration/incident-srv04-tailscale-derp-2026-05-13.md`.

This document is a runbook. Scripts referenced live under
`doc/migration/scripts/`. Nothing in the existing migration pipeline
changes — the wrapper scripts call back into `bootstrap.sh`.

---

## 0. Pre-requisites

- Ubuntu host (the one currently running srv04) has a bridge configured.
  If you don't have one yet, the cleanest options are:
  - **Netplan bridge**: configure a `br0` over your physical NIC so VMs
    get IPs from your home router via DHCP.
  - **libvirt routed bridge**: `virsh net-define` a network of `<forward mode='bridge'/>`
    pointing at `br0`.
- Tailscale auth key (pre-auth, tag `tag:zta-cluster`). Get from
  https://login.tailscale.com/admin/settings/keys.
- The cluster is up and `kubectl get nodes` shows 3 Ready + srv04
  NotReady (or any state — srv04 doesn't have to be reachable).

---

## 1. Provision srv05 with bridge networking

On the Ubuntu host:

```bash
# Example virt-install — adjust paths + bridge name to your setup
sudo virt-install \
  --name 7189srv05 \
  --vcpus 2 --memory 4096 \
  --disk size=30,pool=default \
  --network bridge=br0,model=virtio \
  --os-variant ubuntu24.04 \
  --location 'http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/' \
  --extra-args 'console=ttyS0,115200n8 serial' \
  --graphics none \
  --noautoconsole
```

After install, verify from inside srv05:

```bash
ip -4 addr show
# Expected: an IP from your LAN (e.g. 192.168.1.x).
# Refuse to proceed if you see 192.168.122.x — that's still libvirt NAT.
```

---

## 2. Update inventory (config.env)

On srv05 (assuming repo is cloned at `~/projects/DATN`):

```bash
cd ~/projects/DATN/doc/migration/scripts
# If you haven't yet:
cp config.env.example config.env

# Edit and append 7189srv05 to workers, set as new DATA_NODE
$EDITOR config.env
# WORKER_HOSTNAMES="7189srv02 7189srv03 7189srv04 7189srv05"
# DATA_NODE="7189srv05"
# TS_AUTHKEY="tskey-..."
```

You do NOT need to remove `7189srv04` from `WORKER_HOSTNAMES` yet — keep
it until decommission step. This lets `bootstrap.sh --server=04 --list`
still work for diagnostics.

---

## 3. Generate join command on the control plane

On srv01:

```bash
sudo kubeadm token create --print-join-command
# Copy the entire line — it includes the bootstrap token + ca-cert-hash.
```

Drop the command somewhere srv05 can read it. Easiest:

```bash
# On srv05, after copy-paste:
sudo mkdir -p /etc/kubernetes
echo 'kubeadm join 100.114.68.15:6443 --token ... --discovery-token-ca-cert-hash sha256:...' | sudo tee /etc/kubernetes/zta-join.cmd
```

OR keep it in an env var when invoking the script (see next step).

---

## 4. Onboard srv05

On srv05:

```bash
sudo -E \
  ZTA_NEW_HOSTNAME=7189srv05 \
  ZTA_JOIN_CMD='kubeadm join 100.114.68.15:6443 --token ... --discovery-token-ca-cert-hash sha256:...' \
  TS_AUTHKEY='tskey-...' \
  bash doc/migration/scripts/onboard-srv05.sh
```

What this does:
1. Asserts you are on Ubuntu 24.04.
2. **Refuses to run if your local IP is in `192.168.122.0/24`** — this is
   the whole point of the transition; we don't want to repeat srv04's
   pain. Override with `ZTA_ALLOW_LIBVIRT_NAT=1` if you really must.
3. Asserts `7189srv05` is in `WORKER_HOSTNAMES`.
4. Sets `HOSTNAME_OVERRIDE=7189srv05` so `host-prep` will rename the VM.
5. Calls `bootstrap.sh --server=05 --yes`, which:
   - Runs `host-prep` (apt, Tailscale install + auth, containerd, kube
     binaries) — same as srv02/03/04 went through.
   - Runs `worker-join` with `--node-ip=<srv05 tailscale IP>`.

Expected duration: 10–15 min on first run (apt downloads + kube binary
downloads + image pulls for kubelet/cilium).

---

## 5. Wait for srv05 Ready

On srv01:

```bash
watch -n 5 'kubectl get nodes -o wide'
# Expected after ~60-90s of CNI install:
#   7189srv05   Ready   <none>   <new age>   v1.30.0   <tailscale IP>
```

If it stays NotReady > 5 min, check Cilium DS pod on the new node:

```bash
kubectl -n kube-system get pod -l k8s-app=cilium -o wide | grep 7189srv05
kubectl -n kube-system logs <cilium-pod-on-srv05> -c cilium-agent --tail=80
```

---

## 6. Decommission srv04

On srv01:

```bash
cd ~/projects/DATN
sudo -E bash doc/migration/scripts/decommission-srv04.sh --yes
```

This:
1. Cordons `7189srv04` so the scheduler stops placing new pods.
2. Drains (`--ignore-daemonsets --delete-emptydir-data --force`) so
   surviving pods are evicted; the only ones still on srv04 should be
   daemonsets (`cilium-agent`, `node-exporter` after Phase 4).
3. `kubectl delete node 7189srv04`.

Verify:

```bash
kubectl get nodes
# 4 nodes: srv01 (CP), srv02, srv03, srv05. srv04 should be gone.

kubectl get pod -A -o wide | grep 7189srv04 || echo '(none)'
# Expected: no pods.
```

---

## 7. Clean up srv04 (optional)

If srv04 is still bootable and you want to power it off cleanly:

```bash
# On srv04
sudo systemctl stop kubelet
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d /var/lib/cni /var/lib/containerd
sudo systemctl disable kubelet
# Then halt / poweroff / virsh destroy
```

If srv04 is unreachable (which is part of the problem we're solving):
skip this and just `virsh destroy 7189srv04 && virsh undefine 7189srv04`
on the Ubuntu host.

---

## 8. Update inventory + PROGRESS.md

On srv01 (or any clone with kubectl + git):

```bash
$EDITOR doc/migration/scripts/config.env
# WORKER_HOSTNAMES="7189srv02 7189srv03 7189srv05"  # remove srv04
# DATA_NODE="7189srv05"

$EDITOR doc/migration/PROGRESS.md
# Add a "Recent events" entry noting the swap. Bump cluster facts table.

git add doc/migration/scripts/config.env doc/migration/PROGRESS.md
git commit -m "ops: complete srv04 -> srv05 transition"
```

(You'll likely commit `config.env` only if you're keeping it in-repo —
it's `.gitignore`d by default, in which case skip that line.)

---

## 9. Resume Phase 3

With srv05 healthy and stateful nodeAffinity targets updated to
`7189srv05`, you can finally start Phase 3 (in-cluster registry on the
data tier) per `doc/migration/PROGRESS.md`:

```bash
# On srv01
kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml
# ... etc
```

---

## Troubleshooting

| Symptom | Most likely cause | Fix |
|---|---|---|
| `onboard-srv05.sh` refuses with "IP ... in libvirt default NAT range" | VM still on default libvirt network | Reconfigure VM to bridge (Section 1), or `ZTA_ALLOW_LIBVIRT_NAT=1` to override (NOT recommended) |
| `bootstrap.sh` errors during step 5 with "no Release file" from `download.docker.com` | host-prep using `linux/debian` repo on Ubuntu | Already fixed by this PR — `host-prep.sh` now picks distro from `${ID}` |
| `kubeadm join` errors with "FileAvailable--etc-kubernetes-pki-ca-crt" | A previous join left stale state | `sudo kubeadm reset --force && sudo rm -rf /etc/cni/net.d /var/lib/cni` then re-run onboard |
| srv05 Tailscale ping to srv01 shows `via DERP(hkg)` not `via direct` | NAT-punching still failing even with bridge | Likely ISP-side CGNAT. Configure router to forward UDP 41641 to srv05's LAN IP. Verify with `sudo tailscale netcheck`: `PortMapping: UPnP / NAT-PMP` line should appear |
| Decommission script errors "replacement is NOT Ready" | srv05 not finished joining yet | Wait, or `ZTA_FORCE=1 bash decommission-srv04.sh` if you accept blind eviction |
