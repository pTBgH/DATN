# Priority Roadmap

## P0 — Bat buoc (bao cao khong lech code)

| # | Task | File lien quan | Trang thai |
|---|------|----------------|------------|
| 1 | Deploy Prometheus + Grafana vao script 02 | `02-deploy-infrastructure.sh` | ❌ |
| 2 | Hook microseg policies vao deploy chain | `02` hoac `03` script | ❌ |
| 3 | Sua false-positive image push | `03-deploy-microservices.sh` line 638 | ❌ |
| 4 | Sua namespace mismatch `kong`→`gateway` | `cilium-policies/03-allow-ingress-kong.yaml` | ❌ |
| 5 | Chinh claim Script 05 (AppRole vs root) | `05-seed-databases.sh` hoac `chapter3.tex` | ❌ |
| 6 | Giam resource limits cho RAM | `laravel-common-values.yaml`, ES, Prometheus | ✅ Planned |
| 7 | Tao toggle script UI noi bo | `scripts/toggle-internal-ui.sh` | ✅ Planned |

## P1 — Nen lam (bao cao chat hon)

| # | Task | Ghi chu |
|---|------|---------|
| 1 | Chot 1 bo policy canonical | `cilium-policies/*` vs `20-security-policies.yaml` |
| 2 | Deploy node-exporter + kube-state-metrics | Hoac cat scrape jobs trong Prometheus |
| 3 | Tao Grafana dashboards (Cilium drops, Vault leases) | Pre-built JSON |
| 4 | Thu thap evidence/screenshot cho chapter3 | Xem `09-evidence-checklist.md` |
| 5 | Chinh validation cuoi script theo critical services | Tranh fail boi non-critical pods |

## P2 — Nang cap (co the de sau)

| # | Task | Lien quan |
|---|------|-----------|
| 1 | OPA/Policy Engine integration | Chapter 1/2 |
| 2 | CAEP/ITDR token revocation giua phien | Chapter 1 muc 1.2.3 |
| 3 | Tetragon Runtime enforcement | Chapter 2 lop 3, Chapter 3 muc 3.6 |
| 4 | SPIFFE/SPIRE hoac Cilium mutual auth | Chapter 2 lop 1 |
| 5 | Kafka SASL/SSL | Chapter 4 thao luan |
| 6 | Alertmanager pipeline | Chapter 3 muc 3.6 |

## Trinh tu thuc thi goi y

- Sprint A (1-2 ngay): P0.1, P0.3, P0.4, P0.6, P0.7
- Sprint B (1-2 ngay): P0.2 + smoke test microseg
- Sprint C (1 ngay): P0.5 + evidence screenshots
- Sprint D (tuy chon): P1 va P2

## Definition of Done

- Chay tu 01→02→03 trong moi truong clean:
  - Monitoring full stack available
  - Security policy enforce + test attacker/allowed
  - Khong false-positive push image
- Chapter3 khong con claim sai voi code thuc te
