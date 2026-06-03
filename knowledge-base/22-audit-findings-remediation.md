# Audit Findings Remediation — Phase 4 (PR #8)

> Mục đích: ghi nhận cách xử lý các finding F-1, F-2, F-4 từ Phase 2 audit
> (`/home/ubuntu/job7189-zta-audit-report.md`) trong PR #8. Các finding khác
> (F-3 etc.) sẽ được xử lý ở các PR sau khi đến đúng bước thesis.

## F-1 — vault-dev hard-coded root token (FIXED)

### Vấn đề
File `infras/k8s-yaml/11-vault.yaml` (dòng 49 và 57 trước fix) hard-code
chuỗi `vault-dev-root-token` làm **dev root token** và truyền qua biến môi
trường `VAULT_TOKEN`. Các script `99-fast-rebuild-vault.sh` (dòng 80) và
`restart_unseal.sh` (dòng 13) cũng tham chiếu chuỗi này.

Hệ quả:
- Token giống hệt nhau trên mọi cluster cài từ repo (kể cả fork public).
- Vi phạm nguyên tắc least privilege của PIP 3 (Vault).
- Bất kỳ ai có network reach tới `vault-dev:8300` đều có quyền root.

### Cách fix
1. **Deployment** (`infras/k8s-yaml/11-vault.yaml`): bỏ CLI arg
   `-dev-root-token-id=...`, thay bằng env vars
   `VAULT_DEV_ROOT_TOKEN_ID` và `VAULT_TOKEN` đọc từ Secret
   `vault-dev-token` qua `secretKeyRef`. Vault server `-dev` đọc env
   `VAULT_DEV_ROOT_TOKEN_ID` natively.
2. **Deploy script** (`02-deploy-infrastructure.sh`): trước khi
   `kubectl apply -f 11-vault.yaml`, tạo Secret nếu chưa tồn tại:
   ```bash
   kubectl create secret generic vault-dev-token --namespace=vault \
     --from-literal=token=$(openssl rand -hex 16)
   ```
   Idempotent — re-run KHÔNG ghi đè token cũ.
3. **Script bootstrap** (`99-fast-rebuild-vault.sh`,
   `restart_unseal.sh`): đọc token từ Secret bằng
   `kubectl get secret vault-dev-token -n vault -o jsonpath='{.data.token}' | base64 -d`.

### Verify

```bash
# 1) Secret tồn tại
kubectl get secret vault-dev-token -n vault

# 2) Deployment dùng secretKeyRef thay vì literal
kubectl get deploy vault-dev -n vault -o yaml \
  | grep -A2 VAULT_TOKEN
# Mong đợi: thấy "secretKeyRef" thay vì "value: vault-dev-root-token"

# 3) Token KHÔNG còn trong repo
git grep "vault-dev-root-token" || echo "OK — không còn reference"
```

### Rotation (rollback nếu cần)

Token có thể đổi mỗi khi cluster rebuild bằng cách xoá Secret trước:
```bash
kubectl delete secret vault-dev-token -n vault
kubectl rollout restart deployment vault-dev -n vault
# Chạy lại 99-fast-rebuild-vault.sh để re-init Transit
```

---

## F-2 — vault-prod-init.json persists on disk (HARDENED)

### Vấn đề
Script `99-fast-rebuild-vault.sh` ghi output `vault operator init` vào file
`vault-prod-init.json` (chứa `root_token` + `recovery_keys`) tại thư mục
chạy script. File:
- KHÔNG bị `git add` nhờ `.gitignore` cục bộ trong `vault-scripts/`.
- Nhưng nếu user copy file ra nơi khác (ví dụ `~/`, `/tmp`, repo khác) thì
  có thể bị commit nhầm.
- Ngoài ra file persist sau khi khởi tạo xong → leak nếu host bị xâm nhập.

### Cách fix
1. **`.gitignore` ở root repo** (mới): thêm các pattern catch-all
   ```
   **/vault-prod-init.json
   **/vault-init-*.json
   **/.vault-token
   **/vault-tls-*.pem
   ```
   Đảm bảo dù file bị copy đi chỗ khác trong repo cũng không thể commit nhầm.
2. **Rotation runbook** (mục dưới) — định kỳ rotate root token + recovery keys.

### Runbook — Vault prod root token rotation (định kỳ Q hoặc khi nghi rò rỉ)

**Tần suất khuyến nghị**: 90 ngày, hoặc ngay khi `vault-prod-init.json` được
quan sát ngoài node infrastructure.

**Bước**:

1. **Tạo root token mới qua quorum recovery key** (chế độ awskms / autounseal
   khác có thể dùng `vault operator generate-root` trực tiếp):
   ```bash
   # Trên một pod có vault CLI + recovery_keys (chỉ admin)
   vault operator generate-root -init -dr-token \
     2>&1 | tee /tmp/genroot-step1.txt
   # → in ra "OTP", "Nonce"
   ```

2. **Quorum unseal** (mỗi recovery key holder cung cấp 1 mảnh):
   ```bash
   vault operator generate-root -dr-token <key1> -nonce=<nonce>
   # ... lặp đến đủ N/M
   ```
   Output cuối cùng: `Encoded Token` (base64, XOR với OTP để ra token).

3. **Decode**:
   ```bash
   vault operator generate-root -decode=<encoded> -otp=<otp>
   # → in ra root token mới
   ```

4. **Revoke token cũ**:
   ```bash
   VAULT_TOKEN="<new-root>" vault token revoke <old-root>
   ```

5. **Cập nhật secret quản trị** (nếu lưu ở đâu khác):
   ```bash
   kubectl create secret generic vault-prod-root --namespace=vault \
     --from-literal=token="<new-root>" --dry-run=client -o yaml \
     | kubectl apply -f -
   ```

6. **Xoá file plaintext sau khi xong**:
   ```bash
   shred -u infras/k8s-yaml/vault-scripts/vault-prod-init.json
   ```

7. **Audit log**: ghi sự kiện vào Wazuh / ELK với `event.action=vault.root_rotated`.

### Emergency — recovery khi mất root token

Nếu mất root token nhưng còn ≥ N/M recovery keys:
- Dùng `vault operator generate-root` như runbook trên.

Nếu mất cả root token VÀ một số recovery key (số còn lại < N/M):
- Vault không thể recover → buộc rebuild từ đầu (mất data store):
  ```bash
  bash infras/k8s-yaml/vault-scripts/99-fast-rebuild-vault.sh
  ```

---

## F-4 — MySQL root password sharing (VERIFIED — no app uses root)

### Vấn đề ban đầu
Audit Phase 2 nghi ngờ MySQL root password được share cross-namespace
(data + management) hoặc bị app sử dụng làm runtime credential, vi phạm
least privilege.

### Cách verify
Đọc Laravel config + Vault rotation jobs.

#### 1. Laravel `database.php` (mọi service)
File: `src/<service>_service/laravel_back/config/database.php`

```php
'mysql' => [
    'driver' => 'mysql',
    'host'    => env('DB_HOST', '127.0.0.1'),
    'port'    => env('DB_PORT', '3306'),
    'database'=> env('DB_DATABASE', 'laravel'),
    'username'=> env('DB_USERNAME', 'root'),    // ← FALLBACK ONLY
    'password'=> env('DB_PASSWORD', ''),
    ...
],
```

`env('DB_USERNAME', 'root')` chỉ là **default boilerplate Laravel sinh ra
khi `composer create-project`**. Giá trị 'root' chỉ được dùng KHI biến môi
trường `DB_USERNAME` không được set. Trong runtime cluster, biến này luôn
được set (xem mục 2 dưới đây).

#### 2. HotReloadServiceProvider (runtime override)
File: `src/identity_service/laravel_back/app/Providers/HotReloadServiceProvider.php`

```php
if (isset($creds['DB_USERNAME'])) {
    config(['database.connections.mysql.username' => $creds['DB_USERNAME']]);
}
if (isset($creds['DB_PASSWORD'])) {
    config(['database.connections.mysql.password' => $creds['DB_PASSWORD']]);
}
DB::purge('mysql');
DB::reconnect('mysql');
```

Provider này đọc file Vault Agent inject vào pod (`/vault/secrets/db.env`)
**mỗi request**, override config Laravel → MySQL connection luôn dùng
**dynamic creds Vault**, không bao giờ là root.

#### 3. Vault dynamic creds
File: `infras/k8s-yaml/vault-scripts/99-fast-rebuild-vault.sh` dòng 186:
```hcl
path "database/creds/${SVC}" { capabilities = ["read"] }
```

Mỗi service có một role Vault `database/creds/<service>` cấp credential
ngắn hạn (TTL mặc định 1h, MAX 24h) thông qua MySQL Database Engine.

File: `vault-rotation-job.yaml` rotate creds bằng:
```bash
vault read database/creds/identity-service > /tmp/creds.json
vault lease revoke -prefix database/creds/identity-service
```

#### 4. Phpmyadmin (management) — exception
Phpmyadmin **dùng root** để có quyền admin DB UI. Đây là acceptable cho
T3 admin tooling vì:
- Phpmyadmin chỉ accessible qua `oauth2-proxy → keycloak SSO` (xem CNP
  `15-management.yaml`).
- Microsegmentation (PR #8) cấm phpmyadmin reach mọi resource ngoài
  `data/mysql:3306`.

### Kết luận F-4

✓ **No application service uses MySQL root** — tất cả 7 microservice dùng
   Vault dynamic creds.

✓ **Phpmyadmin is the only consumer of root**, được giới hạn bởi:
   - SSO chain (oauth2-proxy + Keycloak).
   - CNP `allow-phpmyadmin-egress-mysql` chỉ cho phép tới `data/mysql:3306`.
   - CNP `allow-phpmyadmin-ingress` chỉ chấp nhận từ oauth2-proxy.

✓ **MySQL root password lưu trong K8s Secret** `app-secrets`
   (data + security namespace), không bị embed trong code.

### Hardening đề xuất (Phase 5)

- Thay phpmyadmin → static creds Vault (read-only role) cho UI thường,
  dynamic root role chỉ khi admin elevated.
- Áp dụng MFA bắt buộc cho phpmyadmin SSO (Keycloak conditional flow).
- Audit log mọi câu lệnh từ phpmyadmin (Wazuh + MySQL general log).

---

## Audit checklist (cho PR #8 reviewer)

| Item | File ảnh hưởng | Status |
|------|----------------|--------|
| F-1 vault-dev token → Secret | `infras/k8s-yaml/11-vault.yaml`, `02-deploy-infrastructure.sh`, `vault-scripts/99-fast-rebuild-vault.sh`, `vault-scripts/restart_unseal.sh` | DONE |
| F-2 root .gitignore | `.gitignore` (mới) | DONE |
| F-2 rotation runbook | `knowledge-base/22-audit-findings-remediation.md` (file này) | DONE |
| F-4 MySQL root audit doc | `knowledge-base/22-audit-findings-remediation.md` (mục F-4) | DONE |
| F-4 phpmyadmin egress chặn | `infras/k8s-yaml/cilium-policies/namespaces/15-management.yaml` | DONE |
