# Incident: srv04 Tailscale DERP relay saturation (2026-05-13)

**Round:** 2 of 2 incidents on srv04 — this one was the deciding factor
to retire the VM and replace it with `srv05` on a bridge network.

| Field | Value |
|---|---|
| Severity | Cluster-degraded (3/4 nodes Ready, srv04 NotReady) |
| Duration | ~25 hours from first symptom to mitigation decision |
| Root cause | Double-NAT (libvirt default NAT inside ISP CGNAT) ⇒ Tailscale `MappingVariesByDestIP=true` ⇒ no direct UDP P2P ⇒ all traffic via DERP-hkg relay ⇒ relay saturated under kubelet+cilium load ⇒ TCP TLS handshake timeouts ⇒ kubelet can't post status |
| Trigger | Cumulative load reached saturation threshold around the time of recovery from round-1 containerd incident. Specifically, after `nuke /var/lib/containerd` srv04 had to re-pull cilium image (~258 MB) over the DERP relay. |
| Outcome | Decision to replace srv04 (libvirt NAT) with srv05 (libvirt bridge). Documented in `transition-srv04-to-srv05.md`. |

---

## Symptom timeline

### 13/05 00:07:42 (last good)
`kubectl describe node 7189srv04` shows `LastHeartbeatTime=00:07:42`.
After this timestamp kubelet on srv04 never successfully posts node
status again.

### 13/05 00:09:03
Node controller marks `MemoryPressure / DiskPressure / PIDPressure =
Unknown`. Cilium DS pod `cilium-hccwk` appears Running 1/1 in apiserver
view, but that's stale cached status — kubelet can't update it.

### 13/05 ~00:19 (user observes)
```
NAME        STATUS     ROLES           AGE   VERSION
7189srv04   NotReady   <none>          25h   v1.30.0
```

### Initial misdiagnosis (round 2 of misdiagnosis…)
On srv04 we found `containerd.service` and `kubelet.service` both
active, sockets present, no OOM in dmesg. Disk and RAM healthy. Tested
`sudo tailscale ping 7189srv01` — got pongs at 728 ms / 873 ms / 1.294 s
/ 1.227 s with 2/8 packet loss (yesterday it was 48 ms). So Tailscale
was technically "up" but degraded.

### Discovering the TCP-vs-ICMP split

The "smoking gun" was the disagreement between `tailscale ping` (works)
and `curl https://100.114.68.15:6443/livez` (TLS handshake timeout). The
kubelet logs were pure CRI/apiserver errors:

```
dial tcp 100.114.68.15:6443: i/o timeout
net/http: TLS handshake timeout
```

Plus tailscaled itself was complaining:

```
open-conn-track: timeout opening (TCP 100.99.153.51:44084 => 100.114.68.15:6443)
  to node [6CtiR]; online=yes, lastRecv=8s
```

i.e. Tailscale knows the peer is online (DERP-relayed pings work) but
TCP connection attempts cannot complete the 3-way handshake + TLS hello
within the timeout. **ICMP packets (~100 bytes) pass; TCP TLS hello
(~1.5 KiB) doesn't.**

### Root cause confirmation via `tailscale netcheck`

```
* MappingVariesByDestIP: true        ← symmetric NAT
* Nearest DERP: Hong Kong
* DERP latency hkg: 31.9 ms
```

`MappingVariesByDestIP: true` means the NAT layer in front of srv04 uses
different `<external-ip,external-port>` mappings depending on the
destination — which makes UDP hole-punching impossible. Tailscale falls
back to relaying every packet through the DERP-hkg server.

`tailscale status` showed `tx 9376816216 rx 1170108940` to srv01, i.e.
~9.3 GiB outbound vs ~1.1 GiB inbound. That's an 8:1 ratio — almost
certainly kubelet retry storms and cilium watch streams pumping data
into DERP without getting ACKs back, because the return path is also
relay-bound.

### Why srv04 specifically

The other 3 VMs (srv01-03) are on a Windows host with VMware NAT.
Different NAT product, different external mapping behavior — they got
`MappingVariesByDestIP: false` and Tailscale punched through fine.
srv04 is on an Ubuntu host with `libvirt`'s default NAT (`virbr0`
network `192.168.122.0/24`), which together with the home ISP's CGNAT
forms a double-NAT chain that produces symmetric mapping.

It worked initially because at small load the DERP relay throughput was
sufficient. As cumulative state grew (kubelet watch leases, cilium
identity exchanges, image pulls), the relay's per-flow throughput cap
saturated. The system is *not* monotonically reliable — it degrades
silently as more traffic builds up.

---

## Why we didn't fix in place

Several mitigations were considered:

| Option | Why rejected |
|---|---|
| `tailscale down && tailscale up` to refresh connection state | Brings RTT down briefly (1.3 s → 56 ms) but doesn't restore TCP. Within ~2 min of kubelet/cilium resuming traffic, relay saturates again. |
| Lower `tailscale0` MTU to 1200 to avoid fragmentation | Possible but doesn't address the bandwidth issue — only fragmentation. Still bottlenecked on DERP. |
| Port-forward UDP 41641 on Ubuntu host (and home router) | Real fix — enables direct P2P, bypasses DERP. But requires touching the home router and assumes ISP CGNAT will accept the port forward (it might not). Also, host's libvirt NAT still adds latency. |
| Subnet router on Ubuntu host advertising `192.168.122.0/24` | Doesn't help K8s — node IP is the Tailscale IP `100.99.153.51`, not the libvirt IP, so K8s traffic still routes via the Tailscale path. |
| Replace srv04 with srv05 on a bridge network | **Chosen.** Removes the inner NAT layer entirely. srv05 gets a LAN IP via DHCP, ISP CGNAT still there but no longer a double-NAT — `MappingVariesByDestIP` should become `false`. Disposes of an unstable VM rather than building band-aids on top. |

---

## Mitigation scripts

PR adds:

- `doc/migration/scripts/onboard-srv05.sh` — wrapper around `bootstrap.sh
  --server=05`. Refuses to run if local IP is in `192.168.122.0/24` (the
  whole point — don't re-create the same problem on srv05).
- `doc/migration/scripts/decommission-srv04.sh` — cordon + drain +
  delete the dead node. Safe to run from srv01.
- `doc/migration/transition-srv04-to-srv05.md` — step-by-step runbook.
- Patch in `phases/host-prep.sh`: pick Docker apt repo from `${ID}` so
  Ubuntu hosts use `linux/ubuntu/dists/noble` instead of the previously
  hardcoded `linux/debian/dists/<codename>`.

---

## Lessons learned

1. **`MappingVariesByDestIP` in `tailscale netcheck` is load-bearing.**
   When it's `true`, Tailscale cannot direct-P2P and every packet is
   relayed. Adopt a pre-deploy check: any VM joining the cluster must
   have `MappingVariesByDestIP: false` before we trust it for kubelet
   workload. (Future TODO: bake this into `host-prep.sh`.)

2. **ICMP-vs-TCP asymmetry is diagnostic gold.** When `tailscale ping`
   works but `curl :6443` times out, the path is alive but the data
   pipe is throttled — almost always relay-bound. Don't waste hours on
   kubelet/containerd state recovery before checking this.

3. **Don't keep growing infrastructure on a known-fragile node.** Round
   1 (containerd snapshotter) was fixable in-place. Round 2 made it
   clear the network substrate was unsuitable. Should have replaced
   srv04 after round 1 instead of hardening it.

4. **DERP relays are not your private backbone.** They're a fallback,
   not a primary path. Treat any node that depends on DERP as
   "Quarantine" — fine for control traffic, never for stateful
   workload.

---

## Follow-up items

- [ ] Bake `tailscale netcheck | grep MappingVariesByDestIP` into
      `host-prep.sh` pre-flight; warn loudly if `true`.
- [ ] Once srv05 is Ready, update nodeAffinity targets in
      `infras/k8s-yaml/12-docker-registry.yaml`, `infras/k8s-yaml/11-vault.yaml`,
      `infras/k8s-yaml/01-mysql-phpmyadmin.yaml`, etc. from `7189srv04`
      to `7189srv05`.
- [ ] Document in `02-tailscale-design.md` that the data-tier VM MUST
      have a single NAT (bridge or direct LAN), not a double NAT.
