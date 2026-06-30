# Deployment Pipeline — Full Script Chain

> **Cảnh báo drift:** pipeline notes có lịch sử 2026-06-03. Trạng thái cluster
> chuẩn 2026-06-20 xem `00-SYSTEM-SNAPSHOT.md`.

## Pipeline Overview

```
01-setup-cluster.sh
  → Mac dinh VM mode: kubeadm 4-node multi-VM (srv01 CP + srv02/03/05 worker)
    qua knowledge-base/migration/scripts/bootstrap.sh; --kind = Kind local-dev
  → + Cilium + cert-manager + Ingress + Hubble check

02-deploy-infrastructure.sh
  → Vault + MySQL + Keycloak + Kafka + Kong + EFK + Prometheus + Grafana + Microseg policies

03-deploy-microservices.sh
  → Registry + Build images + Helmfile 7 services + Verify microseg
  └── 04-build-and-push-images.sh (sub-script)

05-seed-databases.sh
  → Load 7 database schemas from DB/ folder

# (06-build-frontends.sh đã được gỡ — frontend tách riêng, xem knowledge-base/cleanup-workspace-plan.md)

07-deploy-monitoring-exporters.sh
  → node-exporter (DaemonSet) + kube-state-metrics (fill Prometheus gaps)

08-harden-security.sh
  → Phase 1: mTLS (Cilium mesh-auth) → Phase 2: WireGuard encryption
  ⚠️ CHAY SAU KHI MOI THU ON DINH

09-verify-zta.sh
  → 7 test suites + thu thap evidence cho chapter3/chapter4

10-deploy-tetragon.sh
  → PEP Runtime: Tetragon DaemonSet + TracingPolicy (block shell/curl/wget)
  ⚠️ CAN ~512Mi RAM. Chay toggle-internal-ui.sh down truoc neu can.

11-provision-dashboards.sh
  → Grafana ZTA dashboard + Prometheus alert rules (5 rules) + PIP health check
```

## Thu tu chay

```bash
# Trien khai co ban
bash 01-setup-cluster.sh
bash 02-deploy-infrastructure.sh
bash 03-deploy-microservices.sh
bash 05-seed-databases.sh

# Frontend (fe_candidate / fe_recruiter) đã tách khỏi pipeline ZTA;
# code dev cục bộ ở thư mục root `frontend/`. Xem knowledge-base/cleanup-workspace-plan.md.

# Monitoring bo sung
bash 07-deploy-monitoring-exporters.sh

# Bao mat nang cao (CHI KHI DA ON DINH)
bash 08-harden-security.sh                          # mTLS + WireGuard
# hoac:
ZTA_HARDEN_WIREGUARD=0 bash 08-harden-security.sh   # Chi mTLS, khong WireGuard

# Kiem tra + thu thap evidence
bash 09-verify-zta.sh

# PEP Runtime (tuy chon, can ~512Mi RAM)
bash 10-deploy-tetragon.sh

# Dashboard + Alerts + PIP health
bash 11-provision-dashboards.sh
```

## Chi tiet tung script

### 01-setup-cluster.sh
- Mac dinh **VM mode**: cum kubeadm 4-node multi-VM (srv01 control-plane + srv02/srv03/srv05 worker) qua `knowledge-base/migration/scripts/bootstrap.sh`. Co the dung `--kind` cho Kind 1CP+3W local-dev. Tat default CNI.
- Cai Gateway API CRDs + Cilium (eBPF) + Hubble
- Cai cert-manager + Nginx Ingress
- **Step 5c**: Patch Cilium stability baseline (wireguard=false; mesh-auth chuẩn hiện tại=true)
- **Step 5d**: Post-check Hubble Relay + UI

### 02-deploy-infrastructure.sh
- Sinh credentials → K8s Secrets
- Deploy: cert-manager issuer → Vault → MySQL → Keycloak → Kafka → Kong → oauth2-proxy → Ingress
- **Step 9a**: Deploy EFK (Elasticsearch + Filebeat + Kibana)
- **Step 9b**: Deploy Prometheus + Grafana
- **Step 9c**: Apply Cilium microseg policies (5 rules, flag `ZTA_ENABLE_POLICIES`)
- **Step 10**: Smart validation (tolerate Completed pods)

### 03-deploy-microservices.sh
- Setup local registry + build 7 Laravel images
- Validate Vault dynamic DB readiness
- Helmfile apply 7 services (frontend đã tách khỏi helmfile từ PR-C)
- **Step 1d**: Verify microseg policies sau deploy

### 05-seed-databases.sh
- Doc MySQL root password tu Vault KV
- Seed 7 databases tu DB/*.sql

### 07-deploy-monitoring-exporters.sh (MOI)
- Deploy node-exporter DaemonSet (~32Mi/node)
- Deploy kube-state-metrics (~32Mi)
- Verify monitoring stack

### 08-harden-security.sh (MOI)
- **Phase 1**: Enable Cilium mesh-auth (mTLS sidecarless)
  - Patch cilium-config → rolling restart → health check
- **Phase 2**: Enable WireGuard encryption (tuy chon)
  - Patch → restart → health check
- Co rollback instructions neu gap van de
- Flag: `ZTA_HARDEN_WIREGUARD=0` de chi bat mTLS

### 09-verify-zta.sh (MOI)
- 7 test suites:
  1. Pod Health (all namespaces)
  2. Vault Dynamic Credentials + tmpfs
  3. Kong JWT Enforcement (401/200 test)
  4. Cilium Microsegmentation + Hubble flows
  5. Encryption Status (mTLS + WireGuard)
  6. Observability Stack completeness
  7. Namespace Tier Isolation
- Luu evidence vao `evidence/` folder
- In CISA ZTMM 2.0 quick assessment

### 10-deploy-tetragon.sh (MOI)
- Check RAM truoc khi deploy
- Install Tetragon via Helm (DaemonSet, 128Mi/node)
- Apply TracingPolicies:
  - `block-suspicious-exec.yaml`: SIGKILL /bin/sh, curl, wget, nc trong job7189-apps
  - `monitor-sensitive-files.yaml`: Log truy cap /etc/passwd, /proc/self/environ
- Verify: TracingPolicy count + DaemonSet ready
- Rollback: `helm uninstall tetragon -n kube-system`

### 11-provision-dashboards.sh (MOI)
- Deploy Prometheus alert rules (5 ZTA alerts):
  1. CiliumHighPolicyDropRate (network scan)
  2. PodRestartStorm (attack indicator)
  3. VaultHighLeaseCount (credential abuse)
  4. NodeMemoryPressure
  5. KongHighAuthFailureRate (brute force)
- Deploy Grafana ZTA Security Dashboard (6 panels)
- PIP health check: verify 11+ PIP tools dang chay

## Rollback Commands

```bash
# Tat mTLS + WireGuard
kubectl -n kube-system patch configmap cilium-config --type merge \
  -p '{"data":{"mesh-auth-enabled":"true","enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart ds/cilium

# Tat Tetragon
helm uninstall tetragon -n kube-system

# Tat microseg policies
bash infras/k8s-yaml/cilium-policies/destroy-zta-microsegmentation.sh

# Tat UI noi bo
./scripts/toggle-internal-ui.sh off
```
