# Maintenance Rules — Doc KB

## 1. Nguyen tac chung

- Moi file trong `knowledge-base/` phai ngan, de scan nhanh.
- Uu tien bullet points va bang; tranh lap lai nguyen van tu thesis chapters.
- `documents/latex/` la ban da nop: **khong sua, khong dong bo nguoc tu KB**.
- Trang thai cluster moi nhat chi co mot nguon chuan: `00-SYSTEM-SNAPSHOT.md`.
- Moi lan them file KB top-level phai cap nhat `README.md` index.
- Moi lan thay doi state cluster phai cap nhat `00-SYSTEM-SNAPSHOT.md` va script
  verify tuong ung neu can them lenh.

## 2. Muc tieu 1 file = 1 chu de

| File | Cau hoi tra loi |
|---|---|
| `00-SYSTEM-SNAPSHOT.md` | Cluster state moi nhat la gi, verify bang lenh nao? |
| `00-project-overview.md` | He thong nay gom nhung gi? |
| `02-architecture-layers.md` | 5 lop ZTA anh xa sang code nao? |
| `03-identity-layer.md` | Keycloak + Vault + JIT credential hoat dong ra sao? |
| `04-policy-enforcement.md` | Kong va Cilium enforce chinh sach the nao? |
| `05-observability-stack.md` | Monitoring/log/metrics gom nhung gi? |
| `06-resource-budget.md` | RAM/swap/resource budget ra sao? |
| `07-service-toggle.md` | Bat/tat UI noi bo the nao? |
| `08-deployment-pipeline.md` | Deploy chain lam gi, risk o dau? |
| `09-evidence-checklist.md` | Can chup/thu gi cho evidence? |
| `11-cisa-ztmm-assessment.md` | He thong dat cap nao theo CISA ZTMM? |
| `12-threat-model.md` | Attack path va bien phap phong thu la gi? |
| `13-maintenance-rules.md` | Quy uoc cap nhat KB la gi? |
| `14-tetragon-runtime.md` | Tetragon runtime enforce ra sao? |
| `15-encryption-mtls-spiffe.md` | mTLS, Cilium WireGuard, Tailscale va SPIFFE trang thai nao? |
| `16-pip-data-sources.md` | PIP/CDM data source nao dang co? |
| `17-observability-baseline.md` | Hubble baseline va DAAS prep the nao? |
| `18-daas-classification.md` | Namespace/data tier phan loai ra sao? |
| `19-label-schema.md` | Label schema ZTA gom nhung key nao? |
| `20-5w1h-policy-matrix.md` | 5W1H policy matrix map service ra sao? |
| `23-rebuild-from-scratch.md` | Rebuild tu dau bang cach nao? |
| `24-adaptive-security-loop.md` | Adaptive loop noi Gatekeeper/Tetragon/CNP ra sao? |
| `25-pdp-controller.md` | PDP cham diem va patch label ra sao? |
| `26-image-provenance.md` | Image provenance/Cosign/Gatekeeper gom gi? |
| `27-spire-workload-attestation.md` | SPIRE attestation setup ra sao? |
| `28-sigstore-policy-controller.md` | Sigstore policy-controller verify image the nao? |
| `29-spire-workload-integration.md` | Workload consume SVID ra sao? |
| `30-hubble-flow-sink.md` | Hubble flow ship ve Elasticsearch ra sao? |
| `36-opa-user-authz.md` | OPA user authz PDP design ra sao? |
| `37-oauth2-client-id-standardization.md` | OAuth2 client-id chuan hoa the nao? |
| `38-microseg-conformance-test.md` | Microseg conformance test gom gi? |
| `39-zta-alert-catalog.md` | Alert catalog gom rule nao? |
| `42-zero-trust-network-blueprint.md` | Network blueprint ZTA ra sao? |
| `45-upgrade-and-rollback-plan.md` | Upgrade/rollback plan ra sao? |
| `46-cilium-l7-same-node-loopback.md` | Cilium L7 same-node loopback gap la gi? |
| `47-next-tasks.md` | Viec tiep theo va status tracker la gi? |
| `48-version-audit-20260612.md` | Version audit 2026-06-12 ket luan gi? |
| `50-physical-topology-and-flows.md` | Topology vat ly va luong traffic ra sao? |
| `51-nist-compliance-mapping.md` | Mapping compliance NIST ra sao? |
| `52-limitations-and-known-gaps.md` | Han che that va gap con lai la gi? |
| `NIST180035.md` | Ghi chu NIST SP 1800-35 dung cho de tai |
| `NIST800207.md` | Ghi chu NIST SP 800-207 dung cho de tai |
| `chapter4_evidence_guide.md` | Dua bang chung vao Chuong 4 nhu the nao? |
| `network_architecture_map.md` | Ban do network architecture |

## 3. Quy uoc cap nhat

- Sua script deploy/security -> cap nhat `08-deployment-pipeline.md` va file chuyen de lien quan.
- Sua claim architecture -> cap nhat `02-architecture-layers.md`.
- Sua claim enforcement/network -> cap nhat `04-policy-enforcement.md`, `15-encryption-mtls-spiffe.md`, hoac `25-pdp-controller.md`.
- Sua resource limits -> cap nhat `06-resource-budget.md`.
- Sua CISA/gap/limitation -> cap nhat `11-cisa-ztmm-assessment.md` va `52-limitations-and-known-gaps.md`.
- Them file KB top-level -> cap nhat `README.md` index ngay trong cung commit.
- Doi state cluster -> cap nhat `00-SYSTEM-SNAPSHOT.md`; neu co check moi, them vao `scripts/verify-system-snapshot-20260620.sh` hoac tao script dated moi.

## 4. Danh dau

- `MATCH`/`DA BAT`/`DA DEPLOY`: da verify tren cluster hoac co bang chung ro.
- `PARTIAL`: co thanh phan nhung chua day du hoac chua end-to-end.
- `GAP`: claim/thiet ke co nhung cluster chua co.
- `TODO`: can lenh verify khi cluster/host bat lai; khong duoc bia ket qua.
- `HISTORY`: thong tin lich su, khong phai state hien tai.

## 5. Query map cho AI

| Muon hoi ve... | Doc file... |
|---|---|
| Cluster state moi nhat | `00-SYSTEM-SNAPSHOT.md` |
| Tong quan he thong | `00-project-overview.md` |
| Kien truc ZTA | `02-architecture-layers.md` |
| Keycloak/Vault | `03-identity-layer.md` |
| Network policy/Cilium | `04-policy-enforcement.md` |
| mTLS/WireGuard/SPIFFE | `15-encryption-mtls-spiffe.md` |
| Runtime/Tetragon | `14-tetragon-runtime.md` |
| PDP adaptive loop | `25-pdp-controller.md` |
| Trivy/PIP/CDM | `16-pip-data-sources.md` |
| Monitoring | `05-observability-stack.md`, `30-hubble-flow-sink.md` |
| RAM/swap | `06-resource-budget.md` |
| Deploy scripts | `08-deployment-pipeline.md` |
| Evidence chapter 4 | `chapter4_evidence_guide.md` |
| CISA maturity | `11-cisa-ztmm-assessment.md` |
| Tan cong/phong thu | `12-threat-model.md` |
| Known gaps | `52-limitations-and-known-gaps.md` |

## 6. Tranh drift

- Doc `00-SYSTEM-SNAPSHOT.md` truoc khi sua bat ky file nao co noi ve cluster state.
- Khong tao snapshot moi rải rác. Neu can bang chung dated, them vao snapshot chuan
  hoac ghi ro la `HISTORY`.
- Cac state can canh gac: Tetragon action, Cilium `mesh-auth-enabled`, Cilium
  `enable-wireguard`, threat-intel CIDR count, PDP namespace/env, Trivy namespace,
  Cosign mode, Gatekeeper `enforcementAction`, registry host-level/in-cluster.
