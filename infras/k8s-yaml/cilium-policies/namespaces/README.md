# Per-namespace Cilium policies — Step 2.3.2

Ref: `doc/18-daas-classification.md`.

## Layout

| File | Namespace | Tier | Workload chính |
|------|-----------|------|----------------|
| `10-data.yaml` | `data` | T1 | mysql, kafka |
| `11-vault.yaml` | `vault` | T1 | vault, vault-dev |
| `12-security.yaml` | `security` | T1 | keycloak, oauth2-proxy |
| `13-monitoring.yaml` | `monitoring` | T2 | prometheus, grafana, elasticsearch, kibana, filebeat |
| `14-gateway.yaml` | `gateway` | T2 | kong-gateway |
| `15-management.yaml` | `management` | T3 | phpmyadmin (kafbat removed) |
| `16-registry.yaml` | `registry` | T3 | docker-registry |

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
1. registry        (T3, ít người động vào)
2. management      (T3, admin UI — có thể mất truy cập, nhưng không sập app user)
3. monitoring      (T2, mất metrics/log nhưng app vẫn chạy)
4. gateway         (T2, sập gateway = sập user-facing — apply vào giờ ít traffic)
5. security        (T1, login bị ảnh hưởng nếu sai)
6. vault           (T1, app crash sau ~1h khi creds hết TTL)
7. data            (T1 — đã có default-deny từ trước, file này chỉ refactor)
```

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
