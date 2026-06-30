# Resource Budget & Swap Strategy

> **Cảnh báo drift:** file này có số liệu vận hành cũ. Trạng thái cluster chuẩn
> 2026-06-20 xem `00-SYSTEM-SNAPSHOT.md`.

## May chu
- Ha tang: **kubeadm 4-node multi-VM** (`srv01` CP + `srv02`/`srv03`/`srv05` worker) — da bo Kind (snapshot 40: "di chuyen tu Kind 12GB sang multi-VM 32GB").
- RAM: ~32GB total tren cum (theo snapshot 40); allocatable moi node ~3.1Gi (tong ~12.4Gi)
- Swap: 4GB (`/swap.img`)
- Swappiness: 60 (default) → **nen giam xuong 10**
- Tailscale mesh \u2192 nodeIP la `100.64.0.0/10` CGNAT range. **Luu y:** `srv05` (data-tier, Ubuntu 24.04) dung IP LAN `172.16.x` (libvirt bridge noi host `baosrc`) thay vi CGNAT — 3/4 node tren CGNAT

## Memory Budget Tong Hop

### Infrastructure (co dinh)

| Component | Pods | Request | Limit | Ghi chu |
|-----------|------|---------|-------|---------|
| kubeadm control-plane (srv01) | 1 | ~700Mi | ~1.5Gi | etcd+apiserver+scheduler |
| Cilium agent | 4 (DS) | 128Mi×4=512Mi | 256Mi×4=1Gi | |
| CoreDNS | 2 | 70Mi×2=140Mi | 170Mi×2=340Mi | |
| ingress-nginx | 1 | 90Mi | 256Mi | |
| cert-manager | 3 | 64Mi×3=192Mi | 128Mi×3=384Mi | |
| **Subtotal** | | **~1.6Gi** | **~3.5Gi** | |

### Security + Data

| Component | Pods | Request | Limit | Ghi chu |
|-----------|------|---------|-------|---------|
| Keycloak | 1 | 512Mi | 1Gi | JVM heavy |
| MySQL | 1 | 256Mi | 512Mi | InnoDB buffer |
| Kafka | 1 | 256Mi | 512Mi | JVM |
| Vault-dev | 1 | 128Mi | 256Mi | Transit only |
| Vault-prod | 1 | 256Mi | 512Mi | |
| Vault agent-injector | 1 | 64Mi | 128Mi | |
| Kong | 1 | 128Mi | 256Mi | DB-less |
| oauth2-proxy | 1 | 32Mi | 64Mi | |
| **Subtotal** | | **~1.6Gi** | **~3.2Gi** | |

### Application (7 Laravel × 4 containers)

| Component | Count | Request | Limit | Ghi chu |
|-----------|-------|---------|-------|---------|
| app (PHP-FPM) | 7 | 128Mi×7=896Mi | 384Mi×7=2.7Gi | **DA GIAM** |
| vault-agent sidecar | 7 | 16Mi×7=112Mi | 48Mi×7=336Mi | **DA GIAM** |
| env-loader sidecar | 7 | 16Mi×7=112Mi | 48Mi×7=336Mi | **DA GIAM** |
| env-watcher sidecar | 7 | 16Mi×7=112Mi | 48Mi×7=336Mi | **DA GIAM** |
| Redis (shared) | 1 | 64Mi | 192Mi | |
| **Subtotal** | | **~1.3Gi** | **~3.9Gi** | |

### Observability

| Component | Pods | Request | Limit | Ghi chu |
|-----------|------|---------|-------|---------|
| Elasticsearch | 1 | 384Mi | 768Mi | **DA GIAM** |
| Filebeat | 3 (DS) | 100Mi×3=300Mi | 200Mi×3=600Mi | |
| Kibana | 1 | 256Mi | 512Mi | **Co the tat** |
| Prometheus | 1 | 256Mi | 512Mi | **DA GIAM** |
| Grafana | 1 | 256Mi | 512Mi | **Co the tat** |
| **Subtotal** | | **~1.5Gi** | **~2.9Gi** | |

### Management (non-essential, co the tat)

| Component | Pods | Request | Limit | Toggle? |
|-----------|------|---------|-------|---------|
| phpMyAdmin | 1 | 64Mi | 128Mi | ✅ |
| ~~Kafbat~~ | ~~1~~ | ~~64Mi~~ | ~~128Mi~~ | (removed — see infras/k8s-yaml/03-kafka.yaml Phần 2) |
| **Subtotal** | | **64Mi** | **128Mi** | |

### ZTA Add-ons (cap nhat 2026-05-27)
 
| Component | Pods | Request | Limit | Trang thai |
|-----------|------|---------|-------|-----------|
| SPIRE server | 1 (STS) | 64Mi | 128Mi | \u2705 deployed |
| SPIRE agent | 4 (DS) | 32Mi\u00d74=128Mi | 64Mi\u00d74=256Mi | \u2705 deployed |
| Gatekeeper | 1+2 | 96Mi\u00d73=288Mi | 256Mi\u00d73=768Mi | \u2705 deployed |
| Tetragon | 4 (DS) | 64Mi\u00d74=256Mi | 128Mi\u00d74=512Mi | \u2705 deployed |
| Cosign policy-controller | 1 | 64Mi | 128Mi | \u2705 deployed |
| PDP Controller | 1 | 128Mi | 256Mi | \u2705 deployed in `security`; `PDP_CVE_INPUT` unset -> default `true` |
| Threat-intel CronJob | (peak 1 pod) | 64Mi peak | 128Mi peak | \u2705 deployed (1h cadence) |
| Trivy Operator | 1 | 150Mi | 300Mi | ✅ deployed (ns `security-cdm`; mem limit đã nâng để scan toàn cụm) |
| ~~Trivy node-collector~~ | ~~4 (DS)~~ | ~~50Mi\u00d74=200Mi~~ | ~~100Mi\u00d74=400Mi~~ | \u274c DEFERRED |
| ~~Hubble \u2192 ES sink filebeat~~ | ~~4 (DS)~~ | ~~96Mi\u00d74=384Mi~~ | ~~192Mi\u00d74=768Mi~~ | \u26a0\ufe0f design-only, KHONG deploy |
| **Subtotal (deployed)** | | **~928Mi** | **~2.0Gi** | |
| **Subtotal (potential when re-enable)** | | **+550Mi** | **+1.5Gi** | n\u1ebfu deploy Trivy + Hubble sink |
 

### TONG

| | Request | Limit |
|---|---------|-------|
| Infrastructure | 1.6Gi | 3.5Gi |
| Security+Data | 1.6Gi | 3.2Gi |
| Application | 1.3Gi | 3.9Gi |
| Observability | 1.5Gi | 2.9Gi |
| Management | 0.1Gi | 0.3Gi |
| **TONG** | **~6.1Gi** | **~13.8Gi** |

> Request fit trong ngan sach cum (4 VM ~32GB tong, allocatable ~12.4Gi). Limits vuot qua nhung K8s overcommit cho phep.
> Neu tat Kibana + Grafana + phpMyAdmin: tiet kiem ~1.27Gi limit. (Kafbat removed.)

---

## Swap Strategy

### Hien tai
- Swappiness: 60 → qua cao cho K8s
- Swap 4GB co san

### De xuat
1. **Giam swappiness xuong 10**:
   ```bash
   sudo sysctl vm.swappiness=10
   echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swap.conf
   ```
2. **kubelet failSwapOn**: cac node kubeadm cau hinh `failSwapOn: false` de cho phep swap
3. **QoS Priority**: K8s tu dong swap BestEffort pods truoc Guaranteed
   - phpMyAdmin nen de BestEffort (khong set resources) → uu tien swap

### QoS Classes

| QoS | Dieu kien | Uu tien swap | Services nen de |
|-----|-----------|--------------|-----------------|
| Guaranteed | requests == limits | Cuoi cung | Vault, MySQL, Keycloak |
| Burstable | requests < limits | Giua | Laravel services, EFK |
| BestEffort | Khong set resources | Dau tien | phpMyAdmin |

---

## Toggle Non-Essential Services

Xem `knowledge-base/07-service-toggle.md` de biet cach bat/tat nhanh cac UI noi bo.

RAM tiet kiem khi tat:
- Kibana: ~512Mi
- Grafana: ~512Mi
- phpMyAdmin: ~128Mi
- ~~Kafbat: ~128Mi~~ (removed)
- **Tong: ~1.15Gi**
