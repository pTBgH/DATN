# Per-namespace Cilium policies — Step 2.3.2

Ref: `knowledge-base/18-daas-classification.md`.

## Layout

| File | Namespace | Tier | Workload chính |
|------|-----------|------|----------------|
| `10-data.yaml` | `data` | T1 | mysql, kafka |
| `11-vault.yaml` | `vault` | T1 | vault, vault-dev |
| `12-security.yaml` | `security` | T1 | keycloak, oauth2-proxy, opa |
| `13-monitoring.yaml` | `monitoring` | T2 | prometheus, grafana, elasticsearch, kibana, filebeat |
| `14-gateway.yaml` | `gateway` | T2 | kong-gateway |
| `15-management.yaml` | `management` | T3 | phpmyadmin (kafbat removed) |
| `16-registry.yaml` | `registry` | T3 | docker-registry |
| `17-cert-manager.yaml` | `cert-manager` | T2 | cert-manager, webhook, cainjector — **draft (Phase 2C)** |
| `18-cosign-system.yaml` | `cosign-system` | T2 | sigstore policy-controller webhook — **draft (Phase 2C)** |
| `19-gatekeeper-system.yaml` | `gatekeeper-system` | T2 | gatekeeper controller-manager + audit — **draft (Phase 2C)** |
| `20-ingress-nginx.yaml` | `ingress-nginx` | T2 | ingress-nginx-controller (north-south) — **draft (Phase 2C)** |
| `21-spire.yaml` | `spire` | T1 | spire-server, spire-agent, controller-manager — **draft (Phase 2C)** |
| `22-local-path-storage.yaml` | `local-path-storage` | T3 | local-path-provisioner — **draft (Phase 2C)** |
| `23-kube-system.yaml` | `kube-system` | T0 | CoreDNS allow-only (NO ns-wide default-deny) — **draft (Phase 2C)** |
| `24-security-cdm.yaml` | `security-cdm` | T1 | trivy-operator + scan jobs + threat-intel CronJob (CDM tier sau consolidation) — **draft (Phase 2C)** |

Mỗi file gồm:

1. `default-deny-<ns>` — deny all ingress + egress trong namespace.
2. Một loạt `allow-*` policy mở chính xác các luồng **được liệt kê trong baseline** + DAAS map.
3. (Optional) policy đặc biệt như scrape egress cho prometheus.

## Cách apply (KHÔNG tự động)

```bash
# Dry-run (mặc định) — xem sẽ apply gì
bash apply-zta-namespace-policies.sh --namespace=registry

# Apply thực sự
bash apply-zta-namespace-policies.sh --namespace=registry --apply

# Rollback (xóa CNP của ns đó)
bash apply-zta-namespace-policies.sh --namespace=registry --rollback

# Apply tất cả (theo thứ tự ít rủi ro → rủi ro cao)
bash apply-zta-namespace-policies.sh --all --apply
```

**Thứ tự apply khuyến nghị** (rủi ro tăng dần):

```
 1. local-path-storage  (T3, provisioner — new PVC pending nếu sai, không ảnh hưởng app live)
 2. security-cdm        (T1, trivy scan job có thể fail, không ảnh hưởng app live)
 3. registry            (T3, ít người động vào)
 4. management          (T3, admin UI — có thể mất truy cập, nhưng không sập app user)
 5. spire               (T1, SVID issuance — nếu sai mTLS handshake fail toàn mesh)
 6. cert-manager        (T2, blockchain cert renewal — không sập app trừ Issuer mới)
 7. cosign-system       (T2, webhook fail = block admission khi failurePolicy=Fail)
 8. gatekeeper-system   (T2, webhook fail = block admission khi failurePolicy=Fail)
 9. monitoring          (T2, mất metrics/log nhưng app vẫn chạy)
10. ingress-nginx       (T2, north-south — apply vào giờ ít traffic)
11. gateway             (T2, sập gateway = sập user-facing — apply vào giờ ít traffic)
12. security            (T1, login bị ảnh hưởng nếu sai)
13. vault               (T1, app crash sau ~1h khi creds hết TTL)
14. data                (T1 — đã có default-deny từ trước, file này chỉ refactor)
15. kube-system         (T0 — file 23 KHÔNG có ns-wide default-deny; chỉ allow rule
                         cho CoreDNS. Default-deny kube-system phải qua quy trình
                         tách riêng sau khi Hubble verify ≥ 24h zero DROPPED legit.)
```

> ⚠️ **Phase 2C draft files (17-23) phải được verify với Hubble flow capture
> (`scripts/legacy/microseg-waves/zta-microseg-step1-flow-capture.sh`) trước khi apply trên live cluster.**
> Mỗi YAML có khối comment "DRAFT — Phase 2C" ở top + danh sách traffic pattern
> giả định. Bổ sung allow rule cho bất kỳ flow DROPPED hợp pháp nào trong
> `~/zta-microseg/<TS>/09-dropped-flows.csv`.

> Nếu namespace không tồn tại trên cluster (vd `registry` chưa deploy), script
> sẽ **graceful SKIP** với thông báo, KHÔNG fail. Muốn dùng registry, deploy
> nguồn ns trước:
> ```bash
> kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml
> ```

Sau mỗi namespace, **chạy lại** `scripts/zta-observability-baseline.sh` và so
sánh DROPPED count để biết policy có quá chặt không.

## Quy tắc DNS

Mọi default-deny trong file này KHÔNG block DNS. Mỗi file đính kèm policy
`allow-dns-egress-<ns>` để pod resolve được service. Sử dụng
`toEndpoints` matchLabels k8s-app=kube-dns thay vì CIDR cứng.
