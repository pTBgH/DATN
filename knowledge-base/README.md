# DOC KB — Token-Optimized Knowledge Base

Kho tri thuc gon cho du an Zero Trust `job7189`.
Muc tieu: giam token khi lam viec voi AI — chi doc dung file can thiet.

Cap nhat: **2026-06-30**. Trang thai cluster moi nhat duoc gom vao
`00-SYSTEM-SNAPSHOT.md` (single source of truth, snapshot 2026-06-20).

## Index file thật trong `knowledge-base/`

| # | File | Chu de |
|---|---|---|
| 00 | `00-SYSTEM-SNAPSHOT.md` | **Single source of truth** cho cluster state 2026-06-20 + lenh verify |
| 00 | `00-project-overview.md` | Tong quan: services, namespaces, luong giao dich, key files |
| 02 | `02-architecture-layers.md` | Khung 5 lop ZTA -> NIST/CNCF/code |
| 03 | `03-identity-layer.md` | Keycloak Dual-Realm + Vault Dual + JIT lifecycle |
| 04 | `04-policy-enforcement.md` | Kong JWT matrix + Cilium microseg + encryption |
| 05 | `05-observability-stack.md` | EFK + Prometheus + Grafana + Hubble + exporters |
| 06 | `06-resource-budget.md` | Memory budget toan he thong + swap strategy |
| 07 | `07-service-toggle.md` | Bat/tat UI noi bo |
| 08 | `08-deployment-pipeline.md` | Script deploy + thu tu chay + rollback notes |
| 09 | `09-evidence-checklist.md` | Placeholder screenshots / evidence checklist |
| 11 | `11-cisa-ztmm-assessment.md` | Tu danh gia CISA ZTMM 2.0 |
| 12 | `12-threat-model.md` | Attack paths + MITRE ATT&CK + doi pho |
| 13 | `13-maintenance-rules.md` | Quy uoc cap nhat KB + query map |
| 14 | `14-tetragon-runtime.md` | Tetragon runtime enforcement |
| 15 | `15-encryption-mtls-spiffe.md` | mTLS + WireGuard/Tailscale + SPIFFE + CAEP gap |
| 16 | `16-pip-data-sources.md` | PIP tools: Keycloak, Vault, Cilium, Trivy, Hubble |
| 17 | `17-observability-baseline.md` | Hubble flow baseline + DAAS prep |
| 18 | `18-daas-classification.md` | DAAS per namespace + tier + microperimeter map |
| 19 | `19-label-schema.md` | 6 ZTA criteria labels |
| 20 | `20-5w1h-policy-matrix.md` | 5W1H L7 enforcement matrix |
| 23 | `23-rebuild-from-scratch.md` | Teardown + rebuild via `zta-rebuild.sh` |
| 24 | `24-adaptive-security-loop.md` | Gatekeeper + Tetragon + adaptive loop |
| 25 | `25-pdp-controller.md` | PDP Controller continuous label compliance |
| 26 | `26-image-provenance.md` | Cosign + Gatekeeper image digest/signature trust |
| 27 | `27-spire-workload-attestation.md` | SPIRE server/agent/CSI + ClusterSPIFFEID |
| 28 | `28-sigstore-policy-controller.md` | Sigstore policy-controller / Cosign verify |
| 29 | `29-spire-workload-integration.md` | Consume SVID via spiffe-helper + Workload API |
| 30 | `30-hubble-flow-sink.md` | Hubble flow -> Elasticsearch via filebeat shipper |
| 36 | `36-opa-user-authz.md` | OPA user-authz PDP design |
| 37 | `37-oauth2-client-id-standardization.md` | OAuth2 client-id standardization |
| 38 | `38-microseg-conformance-test.md` | Microsegmentation L4 conformance test |
| 39 | `39-zta-alert-catalog.md` | ZTA alert catalog |
| 42 | `42-zero-trust-network-blueprint.md` | Zero Trust network blueprint |
| 45 | `45-upgrade-and-rollback-plan.md` | Upgrade and rollback plan |
| 46 | `46-cilium-l7-same-node-loopback.md` | Cilium L7 same-node loopback note |
| 47 | `47-next-tasks.md` | Next tasks / status tracker |
| 48 | `48-version-audit-20260612.md` | Version audit 2026-06-12 |
| 50 | `50-physical-topology-and-flows.md` | Physical topology and traffic flows |
| 51 | `51-nist-compliance-mapping.md` | NIST compliance mapping |
| 52 | `52-limitations-and-known-gaps.md` | Limitations and known gaps, authoritative 2026-06-20 |
| NIST | `NIST180035.md` | Notes for NIST SP 1800-35 |
| NIST | `NIST800207.md` | Notes for NIST SP 800-207 |
| C4 | `chapter4_evidence_guide.md` | Huong dan lap bang chung vao Chuong 4 |
| Map | `network_architecture_map.md` | Network architecture map |

## Ghi chu numbering

- File top-level `.md` trong `knowledge-base/`: **45** file.
- File numbered/prefixed bang so: **40** file, tuong ung **39** so duy nhat
  (vi co hai file `00-*`).
- So bi thieu trong day numbered hien tai: `01`, `10`, `21`, `22`, `31`, `32`,
  `33`, `34`, `35`, `40`, `41`, `43`, `44`, `49`.
- Trong cac so thieu, can de y rieng `21`, `44`, `49` vi chung nam giua cac
  cum tai lieu dang duoc dung.
- So `35` tung co 2 file trong index cu, nhung hien **khong co file `35-*`**
  trong thu muc top-level.
- Cac so `37`, `42`, `45`-`52` dang duoc su dung va da liet ke o tren.

## Migration (Kind -> Multi-VM kubeadm)

Folder: `knowledge-base/migration/` co index rieng trong
`knowledge-base/migration/README.md`. Cac file migration la runbook/lich su
chuyen doi, khong phai source of truth cho cluster state moi nhat neu mâu thuẫn
voi `00-SYSTEM-SNAPSHOT.md`.

## Query Map

| Muon hoi ve... | Doc file... |
|---|---|
| Trang thai cluster moi nhat | `00-SYSTEM-SNAPSHOT.md` |
| Tong quan he thong | `00-project-overview.md` |
| Kien truc ZTA | `02-architecture-layers.md` |
| Keycloak, Vault, JWT | `03-identity-layer.md` |
| Network policy, Cilium | `04-policy-enforcement.md` |
| Monitoring/log/metrics | `05-observability-stack.md` |
| RAM, swap, resource | `06-resource-budget.md` |
| Deploy scripts | `08-deployment-pipeline.md` |
| Evidence / chapter 4 | `chapter4_evidence_guide.md` |
| CISA maturity level | `11-cisa-ztmm-assessment.md` |
| Threat model | `12-threat-model.md` |
| Tetragon runtime | `14-tetragon-runtime.md` |
| mTLS, WireGuard, SPIFFE | `15-encryption-mtls-spiffe.md` |
| PIP/CDM/Trivy | `16-pip-data-sources.md` |
| Label schema | `19-label-schema.md` |
| PDP adaptive loop | `25-pdp-controller.md` |
| Cosign / supply chain | `26-image-provenance.md`, `28-sigstore-policy-controller.md` |
| SPIRE/SPIFFE workload identity | `27-spire-workload-attestation.md`, `29-spire-workload-integration.md` |
| Hubble flow sink | `30-hubble-flow-sink.md` |
| Compliance / limitations | `51-nist-compliance-mapping.md`, `52-limitations-and-known-gaps.md` |

## Archive

Subfolders `api/`, `architecture/`, `frontend/`, `migration/` co index/rules rieng
hoac la tai lieu chuyen de. README nay chi liet ke file `.md` top-level de tranh
index bi lech voi thu muc that.
