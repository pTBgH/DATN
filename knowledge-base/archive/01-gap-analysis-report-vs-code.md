# Gap Analysis: Thesis Report vs Source Code

Cap nhat: 2026-04-24 (sau khi chay scripts 01-09)

## Nguon doi chieu

- Thesis: `documents/latex/chapters/chapter1.tex`, `chapter2.tex`, `chapter3.tex`, `chapter4.tex`
- Code: Scripts 01-09, `infras/`, `k8s-management/`, `src/`

## Bang doi chieu tong hop

| # | Claim trong bao cao | Thuc trang code | Danh gia |
|---|---------------------|-----------------|----------|
| 1 | Kind 1CP+3W, disableDefaultCNI | `infras/kind/kind-config.yaml` | ✅ MATCH |
| 2 | Cilium baseline: l7-proxy=true, wireguard=false, mesh-auth=false | `01-setup-cluster.sh` Step 5c | ✅ MATCH |
| 3 | Root of Trust: Keycloak + Vault + SA | Du 3 thanh phan | ✅ MATCH |
| 4 | Keycloak Dual-Realm (7189_internal + job7189) | `realm-infra.json` + `realm-job7189.json` | ✅ MATCH |
| 5 | Vault Dual (dev Transit + prod TLS) | `11-vault.yaml` | ✅ MATCH |
| 6 | Vault JIT credentials TTL 1h | `99-fast-rebuild-vault.sh` | ✅ MATCH |
| 7 | Vault Agent Injector + env-loader + env-watcher | Helm chart templates (3 containers/pod) | ✅ MATCH |
| 8 | Kong JWT route-level enforcement | `kong.yml` (static RSA key) | ✅ MATCH — test 401 PASS |
| 9 | Microseg Default Deny + Allow-Explicit | 6 policies, hook script 02 Step 9c | ✅ FIXED |
| 10 | Namespace allow ingress tu Kong (gateway) | `03-allow-ingress-kong.yaml` — da dung namespace `gateway` | ✅ FIXED |
| 11 | Observability EFK + Prometheus + Grafana + Hubble | Script 02 Step 9a+9b, 07 exporters | ✅ FIXED |
| 12 | Prometheus scrape 5 nguon | node-exporter + kube-state-metrics da deploy | ✅ FIXED |
| 13 | Script 05 seed dung AppRole + vault-manager | Dang dung root token | ⚠️ PARTIAL |
| 14 | Tetragon Runtime enforcement | Bao cao ghi "du kien/chua trien khai" | ✅ MATCH (declared) |
| 15 | Alertmanager pipeline | Bao cao ghi "chua trien khai" | ✅ MATCH (declared) |
| 16 | mTLS sidecarless (Cilium mesh-auth) | Script 08 Phase 1 — DA BAT | ✅ FIXED |
| 17 | WireGuard transparent encryption | Script 08 Phase 2 — DA BAT | ✅ FIXED |
| 18 | CAEP/ITDR | Bao cao ghi "chua trien khai" | ✅ MATCH (declared) |
| 19 | OPA/Rego policy engine (chapter 1-2) | Logic tuong duong qua Kong + Cilium | ⚠️ PARTIAL |
| 20 | SPIFFE/SPIRE workload attestation | Cilium mesh-auth = SPIFFE sidecarless | ✅ FIXED |
| 21 | Chapter 4 kich ban thu nghiem | Script 09 — 25 tests PASS | ✅ FIXED |

## Thong ke

- ✅ MATCH/FIXED: 19
- ⚠️ PARTIAL: 2
- ❌ GAP: 0

## Khoang trong con lai (khong lech voi thesis)

1. **Script 05**: Claim AppRole nhung thuc te dung root token (thesis chua khang dinh AppRole)
2. **OPA server**: Chua deploy rieng — logic tuong duong via Kong/Cilium
3. **Tetragon**: Declared "du kien" — khong phai GAP, co thiet ke san (knowledge-base/14)
4. **CAEP**: Declared "chua trien khai" — khong phai GAP
5. **Alertmanager**: Declared "chua trien khai" — khong phai GAP

## Xem them

- Tung lop: `02-architecture-layers.md`
- Policy: `04-policy-enforcement.md`
- Observability: `05-observability-stack.md`
- Tetragon: `14-tetragon-runtime.md`
- mTLS/SPIFFE: `15-encryption-mtls-spiffe.md`
- Evidence: `09-evidence-checklist.md`
