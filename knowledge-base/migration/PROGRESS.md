# Migration progress — Kind → 4-VM kubeadm

Live install tracker. Mỗi lần đi qua một step, edit file này, commit + push.
Mục đích: nếu Devin session mới (hoặc bản thân bạn 3 tuần sau) muốn biết
"cluster đang ở phase nào, gì đã chạy, gì chưa", chỉ cần đọc file này thay
vì `kubectl get pod -A` rồi đoán.

Cross-reference:
- Plan tổng thể: `knowledge-base/migration/README.md`
- Runbook fresh deploy theo phase: `knowledge-base/migration/11-runbook-fresh-deploy.md`
- Pipeline ZTA chi tiết: `scripts/zta-rebuild.sh --list`
- Recovery khi hỏng: `knowledge-base/migration/12-runbook-recovery.md`
- Sự cố đã gặp:
  - `knowledge-base/migration/incident-srv04-containerd-snapshotter-2026-05-12.md` (round 1 — containerd state)
  - `knowledge-base/migration/incident-srv04-tailscale-derp-2026-05-13.md` (round 2 — Tailscale DERP saturation)
- Kế hoạch chuyển sang srv05: `knowledge-base/migration/transition-srv04-to-srv05.md`

---

## Cluster facts

| Thuộc tính | Giá trị |
|---|---|
| Cluster name | `job7189` |
| Pod CIDR | `10.244.0.0/16` (Cilium VXLAN) |
| Service CIDR | `10.96.0.0/12` |
| Tailscale CGNAT | `100.64.0.0/10` |
| CRI | containerd v2.2.3 (`/run/containerd/containerd.sock`) |
| CNI | Cilium 1.19, VXLAN, **WireGuard OFF** (Tailscale đã encrypt) |
| kube version | v1.30.0 (kubeadm/kubelet/kubectl) |

| Node | Tailscale IP | Role | Host | RAM | Vai trò |
|---|---|---|---|---|---|
| `7189srv01` | `100.114.68.15` | control-plane | Windows VMware | 2 GiB | apiserver, etcd, scheduler, cm |
| `7189srv02` | `100.108.231.127` | worker | Windows VMware | 4.5 GiB | Stateless + ELK/Prometheus (emptyDir) |
| `7189srv03` | `100.112.57.2` | worker | Windows VMware | 5 GiB | Stateless + ELK/Prometheus (emptyDir) |
| `7189srv05` | `100.109.79.58` | worker (data tier) | Ubuntu 24.04.4 LTS libvirt/KVM **bridge** | 4 GiB | Direct P2P working (UPnP, RTT 4 ms). kubelet v1.30.14. LAN self-IP `192.168.1.4`. |

> `7189srv04` đã được decommission sáng 13/05 — xem `transition-srv04-to-srv05.md` và `incident-srv04-tailscale-derp-2026-05-13.md`.

---

## Phase status

> Mark each step with one of: `[x] done`, `[~] in-progress`, `[ ] todo`, `[!] blocked`.
> Add a `note:` line whenever a step had a non-trivial issue.

### Phase 0 — VM provisioning + base OS + Tailscale  (Plan: 60 min)

- [x] 4 VM final: `7189srv01..03` (Debian 13, VMware on Windows host) + `7189srv05` (Ubuntu 24.04, libvirt **bridge** on Ubuntu host). srv04 retired.
- [x] Debian 13 trixie + kernel 6.12.86 cho srv01-03; Ubuntu 24.04.4 + kernel 6.8.0 cho srv05
- [x] `swappiness=10` (set qua sysctl trong `host-prep.sh`)
- [x] Tailscale 1.96.4 installed + authenticated trên cả 4 VM
- [x] Tailscale ACL: 4 hostnames đều `tagged-devices`, tất cả `active`
- [x] Tailscale **direct P2P** (4 ms qua UPnP) sau khi chuyển srv04→srv05 với bridge networking

> Note (12/05): srv04 (Ubuntu host) bị `dhcpcd` trampling `/etc/resolv.conf` định kỳ.
> Tailscale tự khôi phục (log `dns: resolve.conf was trampled, setting existing config again`).
> Không cần action, nhưng có thể dứt điểm bằng `nohook resolv.conf` trong `/etc/dhcpcd.conf`.

### Phase 1 — Bootstrap K8s  (Plan: 30 min)

- [x] `bootstrap.sh --server=01` → kubeadm init thành công, etcd Ready
- [x] `bootstrap.sh --server=02` → joined
- [x] `bootstrap.sh --server=03` → joined
- [x] `bootstrap.sh --server=04` → joined ngày 11/05 (sau đó incident, swap sang srv05 ngày 13/05)
- [x] `onboard-srv05.sh` → srv05 joined và Ready (13/05, kubelet v1.30.14)
- [x] `decommission-srv04.sh` → srv04 removed khỏi cluster (13/05)
- [x] `kubectl get nodes` → 4/4 Ready
- [x] Per-node `containerd.service` active + enabled

> Note (12/05): srv04 mất `containerd.service` sau khi unclean shutdown. Recovery
> bằng `nuke /var/lib/containerd`. Chi tiết:
> `knowledge-base/migration/incident-srv04-containerd-snapshotter-2026-05-12.md`.

### Phase 2 — Cilium + cluster-services  (Plan: 30 min)

- [x] Cilium 1.19 installed (Helm, VXLAN, WireGuard=false)
- [x] 4× cilium DS pod `1/1 Running` (cilium-86562, -8s8n5, -bprn2, -hccwk)
- [x] cilium-operator 1× Running
- [x] Gateway API CRDs v1.1.0 applied
- [x] cert-manager v1.14.7 (3 pods Running)
- [x] ingress-nginx 4.10.0 (NodePort 30001/30003)
- [x] metrics-server (1 pod Running)
- [x] local-path-provisioner v0.0.30 + alias `standard` storageClass mặc định
- [x] coredns 2× Running

### Phase 3 — In-cluster registry + push images  (Plan: 45 min)  [UNBLOCKED]

**Status**: srv05 stable với direct P2P (UPnP). nodeAffinity đã patch vào 5 workload data-tier (registry, vault-dev, vault-prod, mysql, kafka) trên PR #27. Sẵn sàng `kubectl apply`.

- [x] Patch nodeAffinity → `7189srv05` cho 5 workload data-tier (PR #27, merged)
- [ ] Apply `infras/k8s-yaml/12-docker-registry.yaml`
   (Registry pin vào srv05 — 50 GiB PVC local-path)
- [ ] Verify `kubectl -n registry get pod -o wide` → đúng trên `7189srv05`
- [ ] Verify `curl -s http://7189srv05.<tailnet>.ts.net:30005/v2/_catalog`
- [ ] Build + push 7 Laravel:
   ```bash
   bash 04-build-and-push-images.sh "7189srv05.<tailnet>.ts.net:30005"
   ```
- [ ] Verify catalog chứa cả 7 image: `auth-service`, `job-service`,
   `application-service`, `notification-service`, `payment-service`,
   `analytics-service`, `gateway-service` (đối chiếu với
   `knowledge-base/01-introduction.md`)
- [ ] `bash 02-deploy-infrastructure.sh` — apply và wait vault/mysql/kafka/keycloak/kong/ELK/Prom/Grafana (vault-dev, vault-prod, mysql, kafka sẽ tự land trên srv05 nhờ affinity ở PR #27)
- [ ] `bash 03-deploy-microservices.sh` — deploy 7 Laravel
- [ ] Sanity: `kubectl get pod -A -o wide | egrep 'mysql|vault|kafka|docker-registry'` → tất cả phải trên `7189srv05`

### Phase 4 — ZTA base stack  (Plan: 60-90 min)

- [ ] Pre-flight: `kubectl top nodes` mỗi node free RAM > 1 GiB
- [ ] `bash scripts/zta-rebuild.sh --external-cluster --skip-cluster --yes`
   Chạy các step:
- [ ] `02-infra` — Vault (dev + prod), Keycloak, MySQL, Kafka, Kong, ELK,
   Prometheus, Grafana
- [ ] `03-microservices` — 7 Laravel deployed
- [ ] `05-seed` — MySQL seed
- [ ] `07-monitoring` — node-exporter + kube-state-metrics

> Reminder pinning: vault-dev/vault-prod/MySQL/Kafka/SPIRE/docker-registry phải
> có `nodeAffinity: kubernetes.io/hostname=7189srv05`. ES + Prometheus
> ngược lại phải pin đi srv02/03 với emptyDir (xem `migration/README` §
> "Stateful workloads pin vào 7189srv05").

### Phase 5 — Full ZTA enforcement  (Plan: 30 min)

- [ ] `08-harden` (chú ý: `ZTA_HARDEN_WIREGUARD=0` — Tailscale đã encrypt)
- [ ] `10-tetragon` (eBPF runtime, 384 Mi limit per node — xem
   `knowledge-base/incident-falco-tetragon-ram-overcommit.md` cho rationale)
- [ ] `20-spire`
- [ ] `21-cosign-keygen`
- [ ] `22-cosign-sign` (sign 7 microservice deployments offline)
- [ ] `23-policy-controller` (sigstore image admission)
- [ ] `24-hubble-export` (Hubble → Elasticsearch)
- [ ] `26-gatekeeper` (OPA + ZTA constraints, sequential CRD apply — xem
   `knowledge-base/incident-gatekeeper-crd-timeout.md`)
- [ ] `27-pdp` (PDP Controller adaptive loop)
- [ ] `28-trivy` (Trivy Operator)
- [ ] `29-threat-intel` (FireHOL + URLhaus)
- [ ] `30-observability` (Grafana dashboard + Prometheus alerts)

### Phase 6 — Verify + evidence  (Plan: 15 min)

- [ ] `bash 09-verify-zta.sh`
- [ ] Result: 35-50 PASS, 0-2 FAIL accepted (Vault sealed initial OK)
- [ ] Evidence files saved in `evidence/<timestamp>/`
- [ ] Snapshot VMware/libvirt cho cả 4 VM với tag `zta-baseline-<date>`

### Phase 7 — Demo / live test  (manual, ad-hoc)

- [ ] JWT enforcement: `curl -i https://7189srv02.<tailnet>.ts.net:30001/api/v1/jobs` → 401
- [ ] Bearer token: cùng URL với `Authorization` header → 200
- [ ] Hubble drop: pod `untrusted` `wget mysql.data:3306` → timeout, observe `DROPPED`

---

## Blockers / risks tracker

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | srv05 4 GiB RAM không đủ cho vault+mysql+kafka+registry+spire | Medium | High | Đặt RAM limits sát thực tế; ELK/Prom move sang srv02/03 với emptyDir |
| 2 | Router UPnP bị tắt → srv05 rerelay qua DERP → tái diễn incident round 2 | Low | High | Giữ UPnP on. Nếu cần tắt vì security, setup port-forward UDP 41641 thủ công (runbook §13) |
| 2b | Tailscale relay (DERP-hkg) RTT ~48ms nếu rerelay → kafka producer/consumer lag | Low | Medium | UPnP đang giữ direct P2P 4 ms. Monitor với `tailscale ping` nếu RTT > 50 ms = rerelay |
| 3 | containerd snapshotter corrupt tái diễn | Low | Medium | Đã document recovery §12. TODO: backup snapshot policy trước khi nuke |
| 4 | Single CP (srv01) — apiserver down = mất cluster | High | High | Nhận risk cho lab; HA-CP nằm ngoài scope |
| 5 | Windows host crash (VMware) → mất srv01/02/03 simultaneous | Low | Critical | Tailscale auto-rejoin, kubeadm cert persist; chỉ mất downtime |

---

## Recent events

> Add a new line at the top when something happens.

- **2026-05-13 03:00** — PR #27 merged: `nodeAffinity → 7189srv05` patched vào `12-docker-registry.yaml`, `11-vault.yaml` (vault-dev + vault-prod), `01-mysql-phpmyadmin.yaml`, `03-kafka.yaml`. Phase 3 apply sequence sẵn sàng (xem checklist trên).
- **2026-05-13 02:21** — **srv05 stable, srv04 decommissioned**. `tailscale ping 7189srv01` từ srv05 = `via 192.168.1.x:port in 4ms` (direct P2P, UPnP mở qua router). `kubectl get nodes` chỉ còn 4 node: srv01/02/03/05 (Ready). srv05 kubelet `v1.30.14` (Ubuntu apt repo mới hơn srv01-03 `v1.30.0`, tương thích trong skew policy). Phase 3 UNBLOCKED.
- **2026-05-13 01:40** — `onboard-srv05.sh` chạy thành công trên srv05 (Ubuntu 24.04, libvirt bridge IP `192.168.1.4`). kubeadm join OK. srv05 Ready trong cluster.
- **2026-05-13 00:30** — srv04 incident **round 2**: kubelet+containerd active
  nhưng TCP đến apiserver timeout. Root cause: Tailscale `MappingVariesByDestIP=true`
  → direct UDP P2P fail → mọi traffic qua DERP-hkg → relay saturate (tx 9.3 GiB tích lũy)
  → TCP TLS handshake (1.5 KiB Client Hello) bị drop. `tailscale down && up` hạ RTT
  1300 ms → 56 ms, nhưng TCP vẫn fail. Quyết định: replace srv04 bằng srv05 (Ubuntu
  24.04 LTS, libvirt bridge network) thay vì cố fix DERP. Scripts:
  `onboard-srv05.sh`, `decommission-srv04.sh`. Runbook: `transition-srv04-to-srv05.md`.
- **2026-05-12 23:35** — srv04 recovered. Nuked `/var/lib/containerd`,
  cilium DS pod `cilium-hccwk` Running 1/1. Incident report posted at
  `knowledge-base/migration/incident-srv04-containerd-snapshotter-2026-05-12.md`.
  Runbook updated with §12. Phase 3 (registry) ready to start.
- **2026-05-12 22:42** — srv04 kubelet bắt đầu crash-loop với
  `containerd.sock: no such file`. Tailscale OK, cluster vẫn còn 3 node Ready.
- **2026-05-11 23:38** — srv04 first-time join successful (Cilium DS up,
  age 24h at incident time).
- **2026-05-11 21:00** — Bootstrap srv01 control plane (`bootstrap.sh --server=01`).
