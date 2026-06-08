# Luồng B: SPIRE OIDC → Vault `auth/jwt` (JWT-SVID) — Flow + Checklist
 
Mục tiêu: thay `auth/kubernetes` (đang vỡ vì `token_reviewer_jwt` hết hạn — "secret zero" tĩnh)
bằng `auth/jwt` ăn **JWT-SVID** do SPIRE phát hành, verify qua **SPIRE OIDC Discovery Provider**.
Trust dẫn xuất từ attestation → không còn secret-zero tĩnh để hết hạn.
 
Làm trên **identity-service** trước, verify chạy thật, rồi nhân ra 6 service còn lại.
 
NGUYÊN TẮC: **CHECK trước, FIX sau.** Không tin trạng thái hiện tại. Mỗi bước có lệnh chỉ-đọc để xác nhận.
 
---
 
## 1. Luồng đích (target end-to-end)
 
```
[SPIRE server] --issues--> JWT-SVID (aud="vault", sub="spiffe://zta.job7189/ns/job7189-apps/sa/identity-service")
      │  (qua spire-agent Workload API socket, CSI csi.spiffe.io)
      ▼
[Pod identity-service]
  ├─ sidecar: spiffe-helper        → fetch JWT-SVID (audience=vault), ghi /jwt/svid.jwt, tự rotate
  ├─ sidecar: vault-agent          → auto_auth method=jwt (path=/jwt/svid.jwt, role=identity-service)
  │                                  → login Vault, render /vault/secrets/.env.db (database/creds/identity-service)
  ├─ sidecar: env-loader           → gộp .env.common + .env.db → /app-secrets/.env  (GIỮ NGUYÊN)
  ├─ sidecar: env-watcher          → phát hiện .env đổi → reload app           (GIỮ NGUYÊN)
  └─ app (laravel)                 → đọc /app-secrets/.env                      (GIỮ NGUYÊN)
      ▼
[Vault auth/jwt]
  - config: oidc_discovery_url = https://<spire-oidc-discovery-provider>
  - role identity-service: bound_audiences=["vault"], user_claim="sub",
                           bound_subject="spiffe://zta.job7189/ns/job7189-apps/sa/identity-service",
                           policies=["identity-service"]   (policy đã tồn tại)
      ▼
[Vault database/creds/identity-service]  → cấp user/pass MySQL động (GIỮ NGUYÊN engine + role + policy)
```
 
Điểm mấu chốt: **chỉ thay khâu AUTH** (kubernetes → jwt/SVID). Toàn bộ database engine, role, policy,
env-loader/env-watcher/app GIỮ NGUYÊN. Giảm rủi ro tối đa.
 
---
 
## 2. Inventory thành phần + trạng thái (điền sau khi CHECK)
 
| # | Thành phần | Cần cho B | Trạng thái hiện tại | Ghi chú |
|---|---|---|---|---|
| C1 | spire-server / spire-agent / csi-driver chạy | ✔ | ✅ Running (server-0, 4 agents, 3 csi) | OK |
| C2 | spire-controller-manager + ClusterSPIFFEID | ✔ | ✅ 10 ClusterSPIFFEID, controller OK | OK |
| C3 | identity-service THỰC SỰ có SPIRE entry/SVID | ✔ | ✅ **CÓ** entry + JWT-SVID TTL | nghi label-drift SAI, đã xác nhận |
| C4 | SPIRE OIDC Discovery Provider | ✔ | ✅ **DEPLOYED** (helm rev3, svc :80, JWKS=200 4 keys) | DONE Pha 1a |
| C5 | SPIRE phát JWT-SVID (Workload API FetchJWTSVID) | ✔ | ✅ native, entry có JWT-SVID TTL | cần audience=vault |
| C6 | Vault `auth/jwt` enabled + config oidc | ✔ | ✅ **DONE** (jwks_url nội bộ + bound_issuer) | DONE Pha 1c |
| C7 | Vault role jwt `identity-service` | ✔ | ✅ **DONE** (aud=vault, sub=spiffe id, policy) | DONE Pha 1c |
| C8 | Vault policy `identity-service` | ✔ | ✅ **CÓ** (read db creds + secrets) | giữ nguyên |
| C9 | database/config/mysql + role identity-service | ✔ | ✅ **CÓ** (7 roles, verify_connection=false) | giữ nguyên |
| C10 | Network: Vault → SPIRE OIDC (Cilium CNP) | ✔ | ✅ **DONE** (allow-oidc-from-vault + allow-vault-egress-oidc) | DONE Pha 1b |
| C11 | Network: pod → spire-agent socket (CSI) | ✔ | ✅ hostPath, ko qua CNP | OK |
| C12 | Chart laravel-app: spiffe-helper + vault-agent(jwt) | ✔ | ❌ **CHƯA** (đang dùng injector k8s) | sửa chart |
 
---
 
## 3. Checklist VERIFY (chỉ-đọc — chạy trước, KHÔNG đổi gì)
 
### Stage A — SPIRE core
```bash
kubectl get pod -n spire -o wide
kubectl get clusterspiffeid
kubectl get crd | grep spiffe
```
 
### Stage B — identity-service có SVID entry không (NGHI VẤN CHÍNH)
```bash
# pod labels hiện tại
kubectl get pod -n job7189-apps -l app=identity-service -o jsonpath='{.items[0].metadata.labels}' ; echo
# entry trong spire-server (tìm identity-service)
SS=$(kubectl get pod -n spire -l app.kubernetes.io/name=spire-server -o name | head -1)
kubectl exec -n spire ${SS#pod/} -c spire-server -- \
  /opt/spire/bin/spire-server entry show -socketPath /tmp/spire-server/private/api.sock 2>&1 \
  | grep -i "identity-service" -A4 || echo ">> KHÔNG có entry identity-service"
```
 
### Stage C — OIDC Discovery Provider
```bash
kubectl get pod -n spire | grep -i oidc || echo ">> OIDC provider CHƯA deploy"
kubectl get svc -n spire | grep -i oidc || true
helm get values spire -n spire 2>/dev/null | grep -iA2 oidc || true
```
 
### Stage D — Vault auth methods + db engine (cần root token)
```bash
cd ~/projects/DATN/infras/k8s-yaml/vault-scripts
RT=$(python3 -c "import json;print(json.load(open('vault-prod-init.json'))['root_token'])")
V="kubectl exec -n vault vault-0 -c vault -- env VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN=$RT"
$V vault auth list
$V vault policy read identity-service
$V vault read database/config/mysql
$V vault list database/roles
```
 
### Stage E — Network reachability (Vault → đâu là OIDC)
```bash
kubectl get ciliumnetworkpolicy -A | grep -iE "vault|egress" || true
```
 
→ Gửi toàn bộ output. Mình sẽ tick trạng thái C1–C12 và chỉ ra chỗ hổng trước khi đụng vào.
 
---
 
## 4. Kế hoạch FIX (chỉ chạy sau khi verify xong từng phần)
 
1. **Scale gọn**: scale=0 toàn bộ 7 app service (dọn pod kẹt), chỉ làm identity-service.
2. **Fix SVID cho identity-service** (nếu C3 fail): sửa ClusterSPIFFEID selector khớp label thật,
   hoặc thêm label `cilium.zta/role` vào pod. Xác nhận entry xuất hiện.
3. **Bật OIDC Discovery Provider** (C4): helm upgrade `spiffe-oidc-discovery-provider.enabled=true`.
   Lấy URL + CA. Verify `/.well-known/openid-configuration` + JWKS.
4. **Mở CNP** (C10): cho phép Vault egress tới OIDC provider nếu cần.
5. **Cấu hình Vault auth/jwt** (C6/C7): enable jwt, write config oidc_discovery_url(+ca),
   write role identity-service (bound_audiences, user_claim=sub, bound_subject, policies).
6. **Test login thủ công**: fetch 1 JWT-SVID (aud=vault) → `vault write auth/jwt/login` → phải ra token.
7. **Sửa chart identity-service**: thêm spiffe-helper + vault-agent(jwt) sidecar, bỏ annotation injector
   kubernetes. Giữ env-loader/env-watcher/app.
8. **Scale=1 identity-service**, verify pod Ready + login Vault qua SVID + DB creds render + app sống.
9. **Test rotation**: revoke lease / hết TTL SVID → vault-agent tự re-login bằng SVID mới (không hết hạn tĩnh).
10. **Nhân ra 6 service** còn lại bằng cùng pattern.
 
---
 
## 5. Rollback
- Mỗi service vẫn còn manifest cũ (injector k8s). Nếu B fail trên identity-service, scale=0,
  revert chart, scale=1 lại bản cũ + áp fix nhanh token-reviewer-không-hết-hạn để sống tạm.
 
---
 
## 6. TRẠNG THÁI THỰC TẾ (cập nhật)
 
- ✅ **Pha 1a** OIDC provider: helm rev3, `spire-spiffe-oidc-discovery-provider:80`, loopback JWKS=200 (4 RSA key).
- ✅ **Pha 1b** CNP: `allow-oidc-from-vault` (spire ingress :8080) + `allow-vault-egress-oidc` (vault egress :80/:8080). vault-0 lấy JWKS exit=0.
- ✅ **Pha 1c** Vault `auth/jwt`: config `jwks_url=http://spire-spiffe-oidc-discovery-provider.spire.svc.cluster.local/keys`, `bound_issuer=https://oidc-discovery.zta.job7189`, `default_role=identity-service`. Role `identity-service`: aud=vault, sub=spiffe id, policy=identity-service, ttl 20m/30m.
- ✅ **Pha 1d** Manual login: `spire-server jwt mint -audience vault` → `vault write auth/jwt/login` → trả `client_token` policies `[default identity-service]`. **TOÀN BỘ AUTH PATH ĐÃ CHỨNG MINH.**
 
---
 
## 7. THIẾT KẾ PHA 2 — sửa chart laravel-app (identity-service trước)
 
Nguyên tắc: **GIỮ vault-agent-injector + toàn bộ template `.env.*`**, chỉ đổi khâu AUTH sang jwt và
thêm `spiffe-helper` cấp JWT-SVID. Đây là thay đổi nhỏ nhất, rủi ro thấp nhất.
 
### 7.1 Thêm vào pod (chart `templates/deployment.yaml`)
 
**Volumes mới:**
- `spiffe-workload-api` — CSI `csi.spiffe.io` (readOnly) → socket spire-agent.
- `spire-jwt` — `emptyDir` (memory) → chứa `jwt_svid.token`.
- `spiffe-helper-config` — configMap `helper.conf` (jwt audience=vault).
 
**Init container `spiffe-helper-init`** (chạy ĐẦU TIÊN, trước vault-agent-init):
- image `ghcr.io/spiffe/spiffe-helper@sha256:...` (phải pin digest cho gatekeeper).
- args: `-config /etc/spiffe-helper/helper.conf -daemon-mode=false` → fetch 1 lần, ghi `/spire-jwt/jwt_svid.token` rồi thoát.
- mount: spiffe-workload-api (ro), spiffe-helper-config (ro), spire-jwt.
 
**Sidecar `spiffe-helper`** (daemon, refresh JWT liên tục cho vault-agent re-auth):
- cùng image, args: `-config /etc/spiffe-helper/helper.conf` (daemon mode mặc định).
- mount như trên.
 
### 7.2 Đổi annotation injector (trong `template.metadata.annotations`)
 
```yaml
vault.hashicorp.com/agent-init-first: "false"          # ĐỔI true->false: để spiffe-helper-init chạy trước
vault.hashicorp.com/auth-path: "auth/jwt"              # THÊM
vault.hashicorp.com/auth-type: "jwt"                   # THÊM (mặc định kubernetes)
vault.hashicorp.com/auth-config-role: "{{ .Release.Name }}"        # THÊM
vault.hashicorp.com/auth-config-path: "/spire-jwt/jwt_svid.token"  # THÊM: file JWT
vault.hashicorp.com/auth-config-remove_jwt_after_reading: "false"  # THÊM: KHÔNG xoá file sau khi đọc (cần re-auth)
vault.hashicorp.com/agent-copy-volume-mounts: "spiffe-helper"      # THÊM: copy mount /spire-jwt vào vault-agent
# BỎ: vault.hashicorp.com/role  (đó là cho auth kubernetes)
```
 
### 7.3 helper.conf (configMap mới, theo demo workload + jwt)
 
```
agent_address = "/spiffe-workload-api/spire-agent.sock"
cert_dir = "/spire-jwt"
jwt_svids = [ { jwt_audience = "vault", jwt_svid_file_name = "jwt_svid.token" } ]
jwt_bundle_file_name = "jwt_bundle.json"
```
 
### 7.4 GIỮ NGUYÊN
- Tất cả `agent-inject-template-common/db/db-lease/extra` (render `.env.*`).
- `wait-for-vault-secrets`, `fix-perms`, `env-loader`, `env-watcher`, `app`, readinessProbe.
- Vault policy/role db engine.
 
### 7.5 Điểm rủi ro cần check trước khi build
- **k8s version** ≥1.29? (nếu muốn spiffe-helper là native sidecar init; nếu không thì dùng init one-shot + sidecar daemon như trên — không cần native sidecar).
- **vault-agent-injector** có chạy + version hỗ trợ `auth-type`/`auth-config-*` (vault-k8s ≥0.5).
- **gatekeeper** bắt buộc image digest → cần digest của `spiffe-helper`.
- **CSI `csi.spiffe.io`** dùng được trong ns `job7189-apps` (demo chạy ở `security`).
- `remove_jwt_after_reading=false` BẮT BUỘC, nếu không file bị xoá → vault-agent sidecar re-auth fail.
 
### 7.6 Verify Pha 2
1. `kubectl scale deploy/identity-service --replicas=1`.
2. `kubectl logs <pod> -c vault-agent-init` → thấy `authentication successful` (jwt), không 403.
3. `kubectl exec <pod> -c spiffe-helper -- cat /spire-jwt/jwt_svid.token` → có JWT.
4. `/vault/secrets/.env.db` render → `/app-secrets/.env` có → app Ready.
5. **Rotation**: chờ qua TTL token/SVID → vault-agent tự re-auth bằng JWT mới, app vẫn sống.
```