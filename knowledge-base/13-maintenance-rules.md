# Maintenance Rules — Doc KB

## 1. Nguyen tac chung
- Moi file trong `knowledge-base/` phai ngan, de scan nhanh
- Uu tien bullet points va bang, tranh viet dai
- Khong lap lai nguyen van tu thesis chapters
- Chi giu: gap, risk, action, evidence path, trang thai

## 2. Muc tieu 1 file = 1 chu de

| File | Cau hoi tra loi |
|------|-----------------|
| `00-project-overview.md` | He thong nay gom nhung gi? |
| `01-gap-analysis-report-vs-code.md` | Lech giua bao cao va code o dau? |
| `02-architecture-layers.md` | 5 lop ZTA anh xa sang code nao? |
| `03-identity-layer.md` | Keycloak + Vault hoat dong ra sao? |
| `04-policy-enforcement.md` | Kong va Cilium enforce chinh sach the nao? |
| `05-observability-stack.md` | Monitoring gom nhung gi, thieu gi? |
| `06-resource-budget.md` | RAM phan bo ra sao, swap the nao? |
| `07-service-toggle.md` | Bat/tat UI noi bo the nao? |
| `08-deployment-pipeline.md` | 5 scripts deploy lam gi, gap/risk o dau? |
| `09-evidence-checklist.md` | Can chup/thu gi de dong chapter3? |
| `10-priority-roadmap.md` | Lam gi truoc, lam gi sau? |
| `11-cisa-ztmm-assessment.md` | He thong dat cap do nao theo CISA? |
| `12-threat-model.md` | Cac attack path va doi pho? |
| `13-maintenance-rules.md` | Quy uoc cap nhat KB? |

## 3. Quy uoc cap nhat

- Moi lan sua scripts (01/02/03): cap nhat `08-deployment-pipeline.md`
- Moi lan sua chapter3 claim: cap nhat `01-gap-analysis-report-vs-code.md`
- Moi lan sua resource limits: cap nhat `06-resource-budget.md`
- Moi lan deploy/fix: cap nhat `10-priority-roadmap.md` trang thai

## 4. Danh dau

- `✅` hoac `MATCH`: Bao cao va code khop
- `⚠️` hoac `PARTIAL`: Co nhung chua day du
- `❌` hoac `GAP`: Bao cao claim nhung code chua co
- `RISK`: Co trong code nhung de gay sai

## 5. Query map cho AI

| Muon hoi ve... | Doc file... |
|----------------|-------------|
| Tong quan he thong | `00-project-overview.md` |
| Kien truc ZTA | `02-architecture-layers.md` |
| Keycloak/Vault | `03-identity-layer.md` |
| Network policy | `04-policy-enforcement.md` |
| Monitoring | `05-observability-stack.md` |
| RAM/swap | `06-resource-budget.md` |
| Bat/tat service | `07-service-toggle.md` |
| Deploy scripts | `08-deployment-pipeline.md` |
| Screenshots | `09-evidence-checklist.md` |
| Uu tien | `10-priority-roadmap.md` |
| CISA maturity | `11-cisa-ztmm-assessment.md` |
| Tan cong/phong thu | `12-threat-model.md` |

## 6. Tranh drift

- Truoc khi finalize chapter3, check 5 claim de lech nhat:
  1. Observability full stack (Prometheus/Grafana trong deploy chain?)
  2. Microseg policy auto-enforce (hook vao script?)
  3. AppRole seed flow (root token vs AppRole?)
  4. Push image success criteria (false-positive?)
  5. Screenshot evidence completeness
