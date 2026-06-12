# 46 — Cilium L7: Same-Node Envoy Loopback Issue

**Trạng thái:** Confirmed & Fixed  
**Phát hiện:** 2026-06-12  
**Liên quan:** `30-l7-keycloak-oidc.yaml`, `ingress-nginx`, `keycloak`  
**Cluster:** `job7189` (Cilium 1.x, L7 Envoy TPROXY mode)

---

## Tóm tắt vấn đề

Khi áp dụng **Cilium L7 CiliumNetworkPolicy** cho một pod (endpoint), Cilium sẽ redirect toàn bộ traffic inbound vào pod đó qua **Envoy proxy chạy cùng node** (TPROXY / eBPF redirect). Nếu **pod nguồn (client) và pod đích (server) đều nằm trên cùng một node**, luồng redirect này tạo ra một vòng loopback nội bộ node mà kernel không xử lý được đúng cách → **TCP connect timeout**.

Triệu chứng:
- `ingress-nginx` (srv02) gọi `keycloak` (srv02) → `upstream timed out (110: Operation timed out)`
- `identity-service` (srv02) gọi `keycloak` (srv02) → timeout tương tự
- Curl exit code 28, HTTP 504 từ phía ngoài

---

## Cơ chế hoạt động của Cilium L7

```
Client Pod (srv02)
      │
      │ TCP SYN → keycloak:8080
      ▼
 [eBPF/TPROXY intercept tại NIC của node srv02]
      │
      ▼
 Cilium Envoy Proxy (srv02) — port 10000+
      │  (kiểm tra HTTP method, path)
      │
      ▼
 Keycloak Pod (srv02) — port 8080
```

Khi client và server **cùng node**, bước TPROXY intercept xảy ra ngay trên loopback interface của node. Kernel cần forward packet ra NIC rồi lại redirect vào Envoy → vòng lặp không thoát được trên một số kernel/Cilium version, dẫn đến TCP SYN bị drop hoặc timeout.

---

## Các trường hợp bị ảnh hưởng

| Source | Destination | Cùng node? | L7 enforced? | Kết quả |
|--------|-------------|------------|--------------|---------|
| `ingress-nginx` (srv02) | `keycloak` (srv02) | ✅ | ✅ (trước fix) | ❌ timeout |
| `identity-service` (srv02) | `keycloak` (srv02) | ✅ | ✅ (trước fix) | ❌ timeout |
| `oauth2-proxy` (srv03) | `keycloak` (srv02) | ❌ | ✅ | ✅ ok |
| `kong-gateway` (srv03/srv05) | `keycloak` (srv02) | ❌ | ✅ | ✅ ok |
| External client | `keycloak` qua ingress-nginx | - | - (ingress bị chặn) | ❌ 504 |

**Pattern:** Chỉ ảnh hưởng khi **source và destination cùng node** VÀ **destination có L7 policy**.

---

## Root Cause chi tiết

1. Cilium detect policy `l7-keycloak-oidc-allowlist` áp dụng cho `app=keycloak`.
2. Policy có `rules.http` → Cilium kích hoạt **L7 enforcement** = redirect via Envoy TPROXY.
3. `ingress-nginx` gửi TCP SYN tới `keycloak:8080` (ClusterIP → `10.244.1.249:8080`).
4. eBPF TPROXY trên `srv02` bắt gói, cố redirect sang `cilium-envoy` trên cùng `srv02`.
5. Kernel loopback path không hoàn chỉnh → packet bị drop → retry → timeout sau 5s × 3 lần = 15s → HTTP 504.

**Lỗi quan sát trong ingress-nginx log:**
```
upstream timed out (110: Operation timed out) while connecting to upstream,
  client: 100.74.189.43, server: auth.job7189.local,
  upstream: "http://10.244.1.249:8080/...",
```
Đây là **TCP connect timeout** (không phải HTTP timeout) → confirm tầng L4 không thông được.

---

## Giải pháp: Split L4/L7 Policy

**Nguyên tắc:** Chỉ áp dụng L7 enforcement cho các source **không cùng node** hoặc **thực sự cần HTTP-level inspection**. Các reverse proxy (nginx, oauth2-proxy) tự xử lý HTTP, không cần Cilium L7 kiểm tra thêm.

### Pattern "Split Policy" (đã áp dụng trong hệ thống)

```yaml
spec:
  endpointSelector:
    matchLabels:
      app: keycloak

  ingress:
  # --- L7: Chỉ áp dụng cho external API GW (Kong) - thường khác node ---
  - fromEndpoints:
    - matchLabels:
        k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name: gateway
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/realms/job7189/.*"

  # --- L4-only: ingress-nginx (reverse proxy, cùng node với keycloak) ---
  - fromEndpoints:
    - matchLabels:
        k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name: ingress-nginx
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      # KHÔNG có rules.http → L4-only, không qua Envoy

  # --- L4-only: Internal apps & oauth2-proxy ---
  - fromEndpoints:
    - matchLabels:
        k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name: job7189-apps
        zta.job7189/role: api
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

**Rule quan trọng:** Trong một `CiliumNetworkPolicy`, từng `ingress[]` rule được xử lý **độc lập**. Rule **không có** `rules.http` = L4-only, **không** trigger Envoy redirect, dù policy khác trên cùng endpoint có L7.

---

## Dấu hiệu nhận biết vấn đề này

| Dấu hiệu | Giải thích |
|-----------|------------|
| `curl` exit code 28 (timeout) | TCP connect không thành công |
| HTTP 504 từ ingress-nginx | upstream timeout sau ~15s |
| Log: "Operation timed out while **connecting**" | TCP-level, không phải HTTP timeout |
| Chỉ xảy ra với một số service nhất định | Service đó cùng node với target |
| `curl` từ pod **khác node** thì OK | Xác nhận same-node loopback issue |
| `cilium monitor --type drop` thấy drop | Có thể thấy TPROXY-related drops |

---

## Checklist khi thiết kế L7 Policy

- [ ] **Xác định node placement** của source và destination trước khi enable L7
- [ ] Nếu source và destination **có thể cùng node** (hoặc không kiểm soát được) → dùng L4-only
- [ ] Reverse proxy (nginx, HAProxy, oauth2-proxy) **không cần** Cilium L7, chúng tự xử lý HTTP
- [ ] L7 nên áp dụng cho **external entry points** (API Gateway như Kong) nơi cần inspect HTTP thực sự
- [ ] Sau khi apply policy mới, luôn test từ **cùng node** và **khác node** để phân biệt
- [ ] Check log: nếu lỗi là "connecting to upstream" timeout → nghi ngờ L7 loopback ngay

---

## Files liên quan

| File | Mô tả |
|------|-------|
| [`infras/k8s-yaml/cilium-policies/30-l7-keycloak-oidc.yaml`](../infras/k8s-yaml/cilium-policies/30-l7-keycloak-oidc.yaml) | Policy đã fix — ingress-nginx dùng L4-only, Kong giữ L7 |
| [`infras/k8s-yaml/cilium-policies/30-l7-keycloak-jwks.yaml`](../infras/k8s-yaml/cilium-policies/30-l7-keycloak-jwks.yaml) | JWKS policy (Kong L7) |
| [`infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml`](../infras/k8s-yaml/cilium-policies/namespaces/12-security.yaml) | Namespace policy cho security ns |
| [`infras/k8s-yaml/cilium-policies/namespaces/20-ingress-nginx.yaml`](../infras/k8s-yaml/cilium-policies/namespaces/20-ingress-nginx.yaml) | Egress policy cho ingress-nginx |

---

## Timeline sự cố

| Thời điểm | Sự kiện |
|-----------|---------|
| Pre-fix | `ingress-nginx` trong L7 rule cùng với Kong → TPROXY loopback timeout |
| 2026-06-12 03:29 | Tách ingress-nginx sang L4-only rule, giữ Kong trong L7 |
| 2026-06-12 03:30 | Apply policy; ingress-nginx → Keycloak: **200 / 0.18s** |
| 2026-06-12 03:30 | External NodePort test: **200 / 0.30s** (trước là 504 / 15s) |

---

## Tham khảo

- [Cilium docs — L7 Policy](https://docs.cilium.io/en/stable/security/policy/language/#layer-7-examples)
- [Cilium docs — Transparent Proxy (TPROXY)](https://docs.cilium.io/en/stable/network/l7-proxy/)
- Xem thêm: [`04-policy-enforcement.md`](./04-policy-enforcement.md) — tổng quan policy layers
- Xem thêm: [`20-5w1h-policy-matrix.md`](./20-5w1h-policy-matrix.md) — ma trận policy Keycloak rows 7-8
