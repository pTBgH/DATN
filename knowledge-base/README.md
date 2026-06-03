# DOC KB — Token-Optimized Knowledge Base

Kho tri thuc gon cho du an Zero Trust job7189.
Muc tieu: giam token khi lam viec voi AI — chi doc dung file can thiet.
Cap nhat: 2026-06-03 (42 chuong + 3 incident reports)

Thu muc `docs/` cu (operational incident reports) da duoc gop vao day
(`incident-*.md`) de chi co MOT knowledge base duy nhat — nguoi/AI khong
phai phan van giua `knowledge-base/` va `docs/`.

## Index

| # | File | Chu de |
|---|------|--------|
| 00 | `00-project-overview.md` | Tong quan: 7 services, namespaces, luong giao dich, key files |
| 01 | `01-gap-analysis-report-vs-code.md` | Do lech giua thesis va code (21 claims — 19 MATCH, 2 PARTIAL) |
| 02 | `02-architecture-layers.md` | Khung 5 lop ZTA → anh xa NIST → CNCF → code |
| 03 | `03-identity-layer.md` | Keycloak Dual-Realm + Vault Dual + JIT lifecycle |
| 04 | `04-policy-enforcement.md` | Kong JWT matrix + Cilium microseg layers + encryption |
| 05 | `05-observability-stack.md` | EFK + Prometheus + Grafana + Hubble + exporters |
| 06 | `06-resource-budget.md` | Memory budget toan he thong + swap strategy |
| 07 | `07-service-toggle.md` | Bat/tat UI noi bo (phpMyAdmin, Kibana, Grafana; Kafbat removed) |
| 08 | `08-deployment-pipeline.md` | 9 scripts deploy (01-09) + thu tu chay + rollback |
| 09 | `09-evidence-checklist.md` | Placeholder screenshots can dien cho chapter3 |
| 10 | `10-priority-roadmap.md` | P0/P1/P2 tasks + trinh tu thuc thi |
| 11 | `11-cisa-ztmm-assessment.md` | Tu danh gia CISA ZTMM 2.0 (5 tru cot) |
| 12 | `12-threat-model.md` | Attack paths + MITRE ATT&CK + truoc/sau ZTA |
| 13 | `13-maintenance-rules.md` | Quy uoc cap nhat KB + query map |
| 14 | `14-tetragon-runtime.md` | **MOI** — PEP Runtime: TracingPolicy, MITRE mapping, ke hoach deploy |
| 15 | `15-encryption-mtls-spiffe.md` | **MOI** — mTLS + WireGuard + SPIFFE + OPA/Rego + ABAC + CAEP |
| 16 | `16-pip-data-sources.md` | PIP tools: Keycloak, Vault, Cilium, Prometheus, EFK, Hubble |
| 17 | `17-observability-baseline.md` | (PR #7) — Step 2.3.1: Hubble flow baseline + DAAS prep |
| 18 | `18-daas-classification.md` | **MOI** (PR #8) — Step 2.3.2: DAAS per namespace + tier + microperimeter map |
| 19 | `19-label-schema.md` | **MOI** (PR #9) — 6 ZTA criteria labels + apply tool |
| 20 | `20-5w1h-policy-matrix.md` | **MOI** (PR #10) — 5W1H L7 enforcement (vault/keycloak/kong/prom) |
| 22 | `22-audit-findings-remediation.md` | **MOI** (PR #8) — F-1/F-2/F-4 audit findings remediation + rotation runbook |
| 23 | `23-rebuild-from-scratch.md` | Teardown + rebuild via `zta-rebuild.sh` (full-enforcement, --from/--until phase) |
| 24 | `24-adaptive-security-loop.md` | (PR #12) — Gatekeeper + Tetragon T1 ns + adaptive loop |
| 25 | `25-pdp-controller.md` | (PR #15) — PDP Controller continuous label compliance |
| 26 | `26-image-provenance.md` | (PR #16) — Cosign + Gatekeeper image-digest required |
| 27 | `27-spire-workload-attestation.md` | (PR #17) — SPIRE server/agent/CSI + 11 ClusterSPIFFEID |
| 28 | `28-sigstore-policy-controller.md` | (PR #19) — sigstore policy-controller real Cosign verify |
| 29 | `29-spire-workload-integration.md` | (PR #20) — Consume SVID via spiffe-helper + Workload API |
| 30 | `30-hubble-flow-sink.md` | (PR #21) — Hubble flow → Elasticsearch via filebeat shipper |
| 31 | `31-falco-deprecated.md` | (PR #22 — **DEPRECATED** 2026-05) — Falco runtime detection thay thế bằng Tetragon, giữ làm thesis evidence |
| 32 | `32-deploy-script-troubleshooting.md` | **MOI** (PR #24) — Deploy script recovery: --reset, --uninstall, RAM pre-flight, cluster cascade fix |
| 33 | `33-zta-gap-analysis.md` | ZTA Gap Analysis — Doc vs Code |
| 34 | `34-microseg-phase2c-plan.md` | Microsegmentation Phase 2C — mở rộng CNP sang infra namespaces |
| 35 | `35-fix-report-summary.md` | Tóm tắt thay đổi báo cáo (theo yêu cầu fix) |
| 35 | `35-microseg-flow-baseline.md` | Microsegmentation — Flow Baseline & Draft Refinement Report |
| 36 | `36-opa-user-authz.md` | OPA user-authz PDP |
| 37 | `37-phase5d-followup-todo.md` | Phase 5.D Follow-Up TODO — công việc còn lại |
| 38 | `38-microseg-conformance-test.md` | Microsegmentation L4 Conformance Test |
| 39 | `39-zta-alert-catalog.md` | ZTA Alert Catalog (Tier 1 + Tier 2) |
| 40 | `40-zta-system-snapshot-20260527.md` | **SNAPSHOT** trạng thái hệ thống thực tế (source-of-truth) |
| 41 | `41-cleanup-and-reconcile-plan.md` | Kế hoạch dọn dẹp repo + đối chiếu KB ↔ hệ thống thực tế |

> Lưu ý: chương `21` không tồn tại (đã gộp); số `35` có 2 file (fix-report-summary + microseg-flow-baseline). Tổng file numbered = **42**.

## Migration (Kind → Multi-VM kubeadm)

Chuyen tu Kind 1-host sang 4 VM Debian + kubeadm + Tailscale overlay
(motivation: 3 incident OOM cascade tren single-host 12 GiB).

Folder: `knowledge-base/migration/` (xem `knowledge-base/migration/README.md` cho index 13 file).

| # | File | Chu de |
|---|------|--------|
| 00 | `migration/README.md` | Index + nguyen tac thiet ke + open questions |
| 01 | `migration/01-context-and-rationale.md` | Vi sao bo Kind, trade-off Kind vs multi-VM |
| 02 | `migration/02-target-architecture.md` | Topology, vai tro tung VM, pod placement |
| 03 | `migration/03-vm-sizing.md` | RAM/CPU/disk tung VM, fit ngan sach 12.8+8 GB |
| 04 | `migration/04-network-tailscale-cilium.md` | Tailscale + VMware NAT + Cilium VXLAN |
| 05 | `migration/05-storage-and-registry.md` | local-path-provisioner + in-cluster registry |
| 06 | `migration/06-debian-base-prep.md` | Cai dat Debian 12 cho moi VM |
| 07 | `migration/07-kubeadm-bootstrap.md` | kubeadm init cp1 + join 3 worker |
| 08 | `migration/08-cilium-install.md` | Cilium 1.19 voi Tailscale-aware nodeIP |
| 09 | `migration/09-cluster-services-bringup.md` | Gateway API, cert-manager, ingress, metrics-server |
| 10 | `migration/10-zta-pipeline-adaptations.md` | Thay doi script ZTA cho external cluster |
| 11 | `migration/11-runbook-fresh-deploy.md` | Day-0 runbook end-to-end (~5h) |
| 12 | `migration/12-runbook-recovery.md` | Recovery cho 12 disaster scenarios |
| 13 | `migration/13-validation-checklist.md` | 7 nhom check verify thanh cong |

## Incident reports (operational fixes)

Mot file moi cho moi failure mode da gap khi rebuild. Format:
Symptom → Root cause → Fix → Operational guidance → Verification.

| File | Chu de | Related commit |
|------|--------|----------------|
| `incident-falco-tetragon-ram-overcommit.md` | Falco + Tetragon OOM cascade tren host 12 GiB | `313178f` |
| `incident-gatekeeper-crd-timeout.md` | Gatekeeper helm CRD install 504 (apiserver overload) | `f7ab2ca` |
| `incident-gatekeeper-probe-webhook-stuck.md` | Gatekeeper post-install probeWebhook hook treo helm install → host VM crash | (this PR) |

## Query Map (cho AI/Agent)

| Muon hoi ve... | Doc file... |
|----------------|-------------|
| He thong gom gi | `00` |
| Lech bao cao vs code | `01` |
| Kien truc ZTA | `02` |
| Keycloak, Vault, JWT | `03` |
| Network policy, Cilium | `04` |
| Monitoring, logs, metrics | `05` |
| RAM, swap, resources | `06` |
| Bat/tat phpMyAdmin, Kibana | `07` |
| Deploy scripts (01→09) | `08` |
| Screenshots can chup | `09` |
| Uu tien lam gi truoc | `10` |
| CISA maturity level | `11` |
| Tan cong va phong thu | `12` |
| Quy tac cap nhat | `13` |
| Tetragon, syscall, runtime | `14` |
| mTLS, WireGuard, SPIFFE, OPA, ABAC, CAEP | `15` |
| PIP, Data Sources, NIST Figure 2 | `16` |
| Hubble baseline, DAAS prep | `17` |
| DAAS classification, tier, microperimeter | `18` |
| Label schema 6 ZTA criteria | `19` |
| 5W1H policy matrix + L7 enforcement | `20` |
| Audit findings F-1/F-2/F-4 + Vault rotation | `22` |
| Rebuild from scratch (zta-rebuild.sh) | `23` |
| Adaptive Security Loop (Gatekeeper + Tetragon) | `24` |
| PDP Controller (continuous label compliance) | `25` |
| Image Provenance & Cosign supply-chain trust | `26` |
| SPIRE Workload Attestation (Devices Advanced) | `27` |
| sigstore policy-controller (real Cosign verify) | `28` |
| SPIRE Workload Integration (consume SVID) | `29` |
| Hubble flow sink (Elasticsearch audit trail) | `30` |
| Falco runtime detection (DEPRECATED — thay bằng Tetragon) | `31` |
| Deploy script troubleshooting (--reset, --uninstall, RAM pre-flight) | `32` |
| Step 26 helm install hangs / VM crashes | `incident-gatekeeper-*.md` |
| Tetragon OOM / host overcommit | `incident-falco-tetragon-ram-overcommit.md` |

## Archive

File audit cu (da gop vao `08-deployment-pipeline.md`):
- `archive/02-audit-01-setup-cluster.md`
- `archive/03-audit-02-deploy-infrastructure.md`
- `archive/04-audit-03-deploy-microservices.md`
