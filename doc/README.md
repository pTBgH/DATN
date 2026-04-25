# DOC KB — Token-Optimized Knowledge Base

Kho tri thuc gon cho du an Zero Trust job7189.
Muc tieu: giam token khi lam viec voi AI — chi doc dung file can thiet.
Cap nhat: 2026-04-24 (16 files)

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
| 07 | `07-service-toggle.md` | Bat/tat UI noi bo (phpMyAdmin, Kafbat, Kibana, Grafana) |
| 08 | `08-deployment-pipeline.md` | 9 scripts deploy (01-09) + thu tu chay + rollback |
| 09 | `09-evidence-checklist.md` | Placeholder screenshots can dien cho chapter3 |
| 10 | `10-priority-roadmap.md` | P0/P1/P2 tasks + trinh tu thuc thi |
| 11 | `11-cisa-ztmm-assessment.md` | Tu danh gia CISA ZTMM 2.0 (5 tru cot) |
| 12 | `12-threat-model.md` | Attack paths + MITRE ATT&CK + truoc/sau ZTA |
| 13 | `13-maintenance-rules.md` | Quy uoc cap nhat KB + query map |
| 14 | `14-tetragon-runtime.md` | **MOI** — PEP Runtime: TracingPolicy, MITRE mapping, ke hoach deploy |
| 15 | `15-encryption-mtls-spiffe.md` | **MOI** — mTLS + WireGuard + SPIFFE + OPA/Rego + ABAC + CAEP |
| 16 | `16-pip-data-sources.md` | **MOI** — PIP tools: Keycloak, Vault, Cilium, Prometheus, EFK, Hubble |

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

## Archive

File audit cu (da gop vao `08-deployment-pipeline.md`):
- `archive/02-audit-01-setup-cluster.md`
- `archive/03-audit-02-deploy-infrastructure.md`
- `archive/04-audit-03-deploy-microservices.md`
