# He thong ZTA — Trang thai hien tai (snapshot 2026-05-27)
 
> Doc nay chup nhanh **trang thai THUC TE** cua lab tai thoi diem
> 2026-05-27 sau khi verify threat-intel, kiem tra PDP adaptive loop
> va mot phan namespace default-deny. Khi co thay doi lon, cap
> nhat file nay (ghi datestamp).
>
> Verify reference: `evidence/verify-zta-20260527_212517.log`
> (68 PASS / 1 FAIL / 19 WARN, 88 tests, 109s).
>
> Da doi chieu them voi `kubectl` live cluster; cac gap/lech quan
> trong duoc phan anh ben duoi.
 
---
 
## 1. Topology
 
### Cluster
- 3+1 node Kubernetes 1.30 (kubeadm-built):
  - `srv01` control-plane (Tailscale `100.114.68.x`)
  - `srv02` worker
  - `srv03` worker
  - `srv05` worker
- 4 node → Cilium DaemonSet 4/4, SPIRE agent DS 4/4, node-exporter 4/4.
- Tailscale mesh tren tat ca 4 node → nodeIP la `100.64.0.0/10` (CGNAT).
- Khong su dung Kind nua (di chuyen tu Kind 12GB sang multi-VM 32GB).
 
### Network
- CNI: Cilium 1.19.4 (tunnel mode VXLAN, encryption disabled vi
  Tailscale da encrypt L3, xem `knowledge-base/15-encryption-mtls-spiffe.md`).
- CoreDNS v1.11.1 (2 replicas) + plugin `hosts` cho sinkhole +
  forward upstream hardcoded `1.1.1.1 8.8.8.8 1.0.0.1` (xem
  `knowledge-base/zta-gap-decision.md` Decision 3 — ly do CGNAT).
- Ingress: ingress-nginx (HTTP/HTTPS) + Kong (API gateway, JWT RS256).
 
### Namespace inventory
| Namespace | Workload | Pods | Default-deny CNP |
|-----------|----------|------|------------------|
| `job7189-apps` | 7 Laravel microservices | 14 (2 replica/svc) | ✅ default-deny-all |
| `gateway` | Kong | 1 | ✅ default-deny-gateway |
| `security` | Keycloak, oauth2-proxy, PDP, SPIRE | 4 | ✅ default-deny-security |
| `vault` | Vault prod/dev, agent-injector | 3 | ✅ default-deny-vault |
| `data` | MySQL, Kafka | 2 | ⚠️ **PENDING** (file: `20-security-policies.yaml`) |
| `monitoring` | EFK + Prom + Grafana + Hubble UI + KSM + node-exporter | 12 | ⚠️ **PENDING** (file: `cilium-policies/namespaces/13-monitoring.yaml`) |
| `management` | phpMyAdmin | 1 | ⚠️ **PENDING** (file: `cilium-policies/namespaces/15-management.yaml`) |
| `security-cdm` | threat-intel CronJob | (peak 1) | ⚠️ partial (allow-threat-intel-egress only; default-deny bundle not seen live) |
| `kube-system`, `ingress-nginx`, `cert-manager`, `cosign-system`, `gatekeeper-system`, `spire`, `local-path-storage`, `trivy-system` | infrastructure | various | system-managed (`trivy-system` 0/0, default-deny-trivy-system) |
 
---
 
## 2. ZTA components da trien khai
 
### Identity (Optimal)
- **Keycloak** Dual-Realm OIDC (port 8080 trong `security` ns).
- **Vault** K8s auth + database secrets engine + transit → JIT MySQL
  credentials TTL 1h, tmpfs mount, env-watcher auto-rotate.
- **SPIRE** server StatefulSet 1/1 + agent DaemonSet 4/4, 10
  ClusterSPIFFEID rules, 47 SVID issued. TrustDomain `zta.job7189`
  (live verify con WARN ve mismatch — pending helm fix).
- **PDP Controller** `zta-pdp` ns=security, reconcile 60s, 9
  Prometheus metric series. Label target: `cilium.zta/score-bucket`
  (live cluster verify still shows no score-bucket labels and no
  `cnp-block-low-trust-to-vault` yet). Env `PDP_CVE_INPUT=false`.
 
### Devices (Advanced)
- **Sigstore policy-controller webhook** 1/1 Running, 3
  ClusterImagePolicy (`passthrough`, `apps-signed`, `keyless`).
- **Cosign** real PEM public key in `security/zta-cosign-public-key`
  (178 bytes); workload `candidate-service` signed by
  `zta-platform-team`.
- **Gatekeeper** image-trust ConstraintTemplates 3/3 +
  `image-digest-required` (126 audit violations, not enforce) +
  `block-latest-tag` (6 violations).
- **VulnerabilityReport CR**: 45 CR co san trong cluster (95
  critical + 752 high CVE) tu lan scan truoc. Trivy Operator khong
  duoc tinh trong snapshot nay vi RAM han che.
 
### Networks (Advanced+)
- **Cilium microsegmentation**: 11 CNP trong `job7189-apps`, default-deny ap dung 4/7 ns.
- **L7 CNP**: 5 policies VALID=True (Keycloak OIDC, JWKS, Kong admin
  readonly, Prom scrape node-exporter, kube-state-metrics).
- **Encryption**: Cilium mesh-auth DISABLED (`mesh-auth-enabled: "false"`); Tailscale L3 mesh remains the transport baseline.
- **Threat-intel egress filter** (NEW 2026-05-27):
  - CCNP `cnp-threat-intel-egress-deny` block FireHOL Level1 (2000
    CIDRs) via `CiliumCIDRGroup threat-intel-firehol` +
    `except: ["100.64.0.0/10"]` (CGNAT, Tailscale).
  - CoreDNS sinkhole `coredns-sinkhole` CM (507 URLhaus FQDN → A
    `0.0.0.0`), CronJob `threat-intel-refresh` hourly refresh +
    Filebeat → ES `threat-intel-feed-*` index (748 docs after first
    runs).
- **Hubble** UI/CLI + Hubble Relay (port 4245). Hubble flow → ES
  sink: design validated, **KHONG deploy** (risk cascade khi restart
  cilium DS, them ~400-800 Mi RAM). L7 flow samples hien van 0 sau
  warm-up.
- **Adaptive enforcement**: PDP → target label `cilium.zta/score-bucket`;
  live cluster verify still shows no score-bucket labels and no
  `cnp-block-low-trust-to-vault` yet.
 
### Applications (Advanced)
- **Kong API gateway** RS256 JWT per-route, Prometheus scrape (1
  target).
- **Tetragon** `block-suspicious-exec` deployed 3/3 nodes,
  Prometheus scrape 3 targets.
- **OPA Gatekeeper** 1 pod (2/2 Ready), 3/3 ZTA ConstraintTemplates,
  `zta-labels-required` 6 violations to remediate.
 
### Data (Advanced)
- **Vault dynamic credentials** TTL 1h, auto-revoke. 7 active leases.
- **Secrets tren tmpfs** (RAM-only, emptyDir medium: Memory).
- **Auto rotation** Vault Agent renew + env-watcher reload.
 
### Observability
- **EFK**: Elasticsearch 7.17.18 (single-node) + Filebeat DS 3 pods
  + Kibana. ES indices: `filebeat-7.17.18-*` (default),
  `threat-intel-feed-*` (audit, 748 docs).
- **Prometheus + Grafana**: 1 ZTA dashboard CM + 5 PrometheusRule
  groups + 19 alerts.
- **Hubble**: relay + UI + CLI samples; L7 flow samples hien van 0
  sau warm-up.
 
---
 
## 3. Khac biet so voi design ban dau
 
| Topic | Design (`zta-gap-decision.md` v1) | Thuc te (2026-05-27) | Ly do |
|-------|-----------------------------------|---------------------|-------|
| Threat-intel CIDR storage | 1 ConfigMap `threat-intel-blocklist` | `CiliumCIDRGroup threat-intel-firehol` | CCNP cannot store 2000 inline CIDRs an toan |
| Threat-intel FQDN storage | `CiliumNetworkPolicy.toFQDNs.matchPattern` | `ConfigMap coredns-sinkhole` + CoreDNS hosts plugin | toFQDNs chi allow-list, khong deny-list |
| PDP score-bucket label | `cilium.zta/score-bucket` (doc) | live cluster still missing score-bucket labels and `cnp-block-low-trust-to-vault` | rollout pending |
| security-cdm policy bundle | default-deny + DNS + monitoring-ingress | only `allow-threat-intel-egress` observed live | bundle still partial |
| CoreDNS forward upstream | `forward . /etc/resolv.conf` | `forward . 1.1.1.1 8.8.8.8 1.0.0.1` | resolv.conf tro Tailscale MagicDNS `100.100.100.100` (CGNAT), bi CCNP block; hardcode public DNS de tach loop |
| CCNP egressDeny | `toCIDRSet: [FireHOL CIDRs]` | `cidrGroupRef + except: ["100.64.0.0/10"]` | tranh block Tailscale mesh node-to-node |
 
---
 
## 4. Gap con lai (ke hoach uu tien)
 
### Ngay (low risk, high value)
1. **PDP adaptive loop rollout (2026-05-27 in progress)**: apply
   `cilium-policies/namespaces/17-cnp-block-low-trust-to-vault.yaml`
   + restart PDP voi env `PDP_CVE_INPUT=false`.
2. **Default-deny 3 namespace con lai (2026-05-27 in progress)**:
   apply `15-management.yaml`, `13-monitoring.yaml`, `10-data.yaml`
    (+ `20-security-policies.yaml` cho data ns default-deny). `security-cdm` bundle hien chi co `allow-threat-intel-egress`; neu muon harden day du thi bo sung sau.
 
### Trung han
3. Hubble → ES flow sink (script `zta-deploy-hubble-export.sh`),
   chap nhan +400-800 Mi RAM.
4. Remediate 6 label violations (`scripts/zta-apply-workload-labels.sh
   --apply`).
5. Apply L7 vault-api allowlist (`scripts/zta-apply-l7-policies.sh
   --apply`).
6. SPIRE trustDomain fix (`infras/k8s-yaml/spire/values.yaml` +
   helm upgrade).
 
### Production gap (out-of-scope thesis)
7. CAEP/ITDR cho Identity Optimal.
8. MDM/EDR cho Devices Optimal.
9. Kube-bench cho compliance audit.
10. Alertmanager + SOAR playbook.
11. Data classification + DLP.
 
---
 
## 5. Tham chieu
 
- Decision log: [`zta-gap-decision.md`](./zta-gap-decision.md) (cap nhat 2026-05-27)
- CISA ZTMM 2.0 assessment: [`11-cisa-ztmm-assessment.md`](./11-cisa-ztmm-assessment.md) (cap nhat 2026-05-27)
- Encryption: [`15-encryption-mtls-spiffe.md`](./15-encryption-mtls-spiffe.md) (cap nhat 2026-05-27)
- Resource budget: [`06-resource-budget.md`](./06-resource-budget.md) (cap nhat 2026-05-27)
- Migration: [`migration/04-network-tailscale-cilium.md`](./migration/04-network-tailscale-cilium.md)
- Threat-intel CronJob: [`30-hubble-flow-sink.md`](./30-hubble-flow-sink.md) (related), `infras/k8s-yaml/threat-intel/`
- Verify script + evidence: `09-verify-zta.sh`, `evidence/verify-zta-20260527_212517.log`
