# Version Audit — 2026-06-12

Snapshot các version đang chạy trên cluster, so sánh với latest stable và đánh giá mức độ cần upgrade.

> **Context RAM:** Tất cả nodes đang 79–83% RAM. Mọi upgrade cần cân nhắc RAM impact.
> **srv05** (`172.16.82.128`): Tailscale CGNAT, **không có internet** — tránh schedule workload cần download ghcr.io lên đây.

---

## Bảng version hiện tại

| Component | Đang chạy | Latest stable (tham khảo) | Cần update? | Ghi chú |
|-----------|-----------|--------------------------|-------------|---------|
| **Cilium** | `v1.19.4` | v1.17.x (1.19 là edge) | ⚠️ Confirm | 1.19 là release mới nhất, có thể là dev branch |
| **Tetragon** | `v1.7.0` | v1.4+ | ✅ OK | Đã upgrade từ v1.2.0, kernel 6.8 support verified |
| **Keycloak** | `custom:v1.0` | Quay.io v26.x | ⚠️ Check | Custom image — cần check base Keycloak version |
| **Kong** | `3.6` | 3.9.x | 🔸 Optional | 3.6 còn LTS, không urgent |
| **Vault** | `1.17` | 1.19.x | 🔸 Optional | 1.17 đang active support |
| **Vault K8s** | `1.7.2` | 1.7.x | ✅ OK | Latest trong branch |
| **OPA (standalone)** | `1.10.1` | 1.x | ✅ OK | |
| **Gatekeeper** | `v3.16.3` | v3.18.x | 🔸 Optional | 3.16 LTS, không urgent |
| **oauth2-proxy** | `v7.6.0` | v7.8.x | 🔸 Optional | 2 minor versions behind |
| **SPIRE server/agent** | `1.14.5` | 1.12.x | ✅ OK | 1.14 là latest |
| **SPIRE controller-manager** | `0.6.4` | 0.6.x | ✅ OK | |
| **SPIFFE CSI driver** | `0.2.7` | 0.2.x | ✅ OK | |
| **Trivy Operator** | `0.20.0` | 0.24.x | ❌ Cần update | 4 minor version behind, scan job RAM issue known |
| **Trivy** (scan job image) | `0.50.1` | 0.64.x | ❌ Cần update | DB format thay đổi, old version có thể fail download |
| **ingress-nginx** | `1.10.0` | 1.12.x | 🔸 Optional | |

---

## Phân tích theo priority

### ❌ Cần update (ảnh hưởng chức năng)

#### Trivy Operator `0.20.0` → `0.24.x`
- **Lý do sập:** Scan job `0.50.1` cố download policy bundle từ `ghcr.io` (OCI format mới) nhưng version cũ dùng API không tương thích → `Init:0/1` fail + DNS timeout
- **RAM concern:** Mỗi scan job vẫn cần ~500 MiB burst. Không thể fix chỉ bằng upgrade version, phải giải quyết song song.
- **Kế hoạch:**
  ```bash
  # 1. Scale down các non-critical workload trước khi scan
  # 2. Pin trivy-operator sang node có internet (srv01/srv02/srv03)
  # 3. Upgrade chart version
  helm upgrade trivy-operator aquasecurity/trivy-operator \
    --namespace security-cdm \
    -f infras/k8s-yaml/trivy-operator/01-values.yaml \
    --version 0.24.0
  ```

---

### ⚠️ Cần xác nhận

#### Cilium `v1.19.4`
- Version `1.19.x` hiện là **development/edge channel**, không phải stable release (stable là `1.17.x`)
- Tuy nhiên cluster đang chạy ổn định. Upgrade Cilium là rủi ro cao nhất trong tất cả.
- **Không upgrade** trừ khi có lỗi cụ thể. Document lại là đang dùng edge.

#### Keycloak `custom:v1.0`
- Cần check Dockerfile base image để biết underlying Keycloak version
- Custom image (`100.74.189.43:5443/job7189/keycloak-custom:v1.0`) — không thể biết version từ tag

---

### 🔸 Optional (không urgent)

| Component | Lý do có thể bỏ qua |
|-----------|---------------------|
| Kong 3.6 | LTS, tất cả routes hoạt động |
| Vault 1.17 | Active support đến 2025-Q4 |
| Gatekeeper v3.16 | Admission webhook đang enforce đúng |
| oauth2-proxy v7.6 | Đang hoạt động với Keycloak OIDC |
| ingress-nginx 1.10 | Stable, vừa fix L4 policy issue |

---

## Kế hoạch xử lý Trivy (ưu tiên nhất)

Vấn đề Trivy là **multi-factor**:

1. **RAM không đủ** — nodes 80%+, scan job cần 500 MiB burst
2. **Node srv05 không có internet** — scan job có thể schedule lên srv05
3. **Version cũ** — `0.20.0` + trivy `0.50.1` không tương thích với DB download format mới

### Giải pháp tầng ngắn hạn (không cần upgrade)

**Option A — NodeAffinity để tránh srv05:**
```yaml
# Thêm vào 01-values.yaml
operator:
  nodeSelector:
    node-role.kubernetes.io/worker: ""  # hoặc label cụ thể
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: NotIn
            values:
            - 7189srv05
```

**Option B — Pre-pull Trivy DB vào registry nội bộ:**
```bash
# Trên máy có internet, pull và push vào registry nội bộ
docker pull ghcr.io/aquasecurity/trivy-db:2
docker tag ghcr.io/aquasecurity/trivy-db:2 100.74.189.43:5443/aquasecurity/trivy-db:2
docker push 100.74.189.43:5443/aquasecurity/trivy-db:2
# Sau đó cấu hình trivy dùng registry nội bộ
```

**Option C — Bỏ qua Trivy scan, mock PDP input (cho PoC):**
- PDP chỉ cần `VulnerabilityReport` CRs để tính score
- Có thể tạo mock CR thủ công để test vòng lặp PDP hoạt động
- Phù hợp cho luận văn vì chứng minh kiến trúc, không phải production scan

### Giải pháp tầng dài hạn

- Upgrade Trivy Operator lên `0.24.x` sau khi có RAM buffer (scale xuống workload không dùng)
- Thêm `nodeAffinity` cố định trong helm values để tránh srv05
- Hoặc bổ sung node có internet + RAM lớn hơn cho scanning workload

---

## RAM Budget hiện tại (snapshot 2026-06-12)

| Node | IP | Internet | RAM% | Headroom | Phù hợp scan? |
|------|----|----------|------|----------|--------------|
| srv01 | 100.114.68.15 | ✅ | 82% | ~580 MiB | ⚠️ Tight |
| srv02 | 100.108.231.127 | ✅ | 80% | ~640 MiB | ⚠️ Tight |
| srv03 | 100.112.57.2 | ✅ | 79% | ~670 MiB | ⚠️ Tight |
| srv05 | 172.16.82.128 | ❌ | 83% | ~510 MiB | ❌ No internet |

> **Kết luận:** Không node nào có đủ headroom an toàn (cần ~700 MiB+ để scan job không trigger OOM). Cần free RAM trước — tắt workload nào đó, hoặc dùng Option B/C ở trên.
