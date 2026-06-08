# 44. Incident: `watch-env` restart storm gây Kong 502 (Bad Gateway)

**Ngày:** 2026-06-08
**Mức độ:** High — toàn bộ API `/api/*` trả 502 sau khi đăng nhập thành công
**Trạng thái:** Đã sửa — `k8s-management/charts/laravel-app` mount đè bản `watch-env.sh` đã fix qua ConfigMap (không rebuild image). Áp cho cả 7 Laravel service.
**Liên quan:** mở rộng từ [43-vault-laravel-rotation-debug.md](./43-vault-laravel-rotation-debug.md)

---

## 1. Triệu chứng

- Đăng nhập Keycloak OK (lấy token 200), nhưng mọi request API qua Kong (ví dụ `GET /api/recruiters/profile`) trả **HTTP 502**:
  ```json
  { "message": "An invalid response was received from the upstream server", "request_id": "d5dbe22a..." }
  ```
- Pod `identity-service` báo `5/5 Running`, endpoint Service vẫn có IP, nhưng health nội bộ `curl http://127.0.0.1:8000/api/health` lúc được lúc `000`.

## 2. Cách chẩn đoán đúng (trace request thật, KHÔNG đoán)

Lấy `request_id` từ chính response 502 rồi tra log Kong + log app theo đúng request đó:

```
[pre-function] ZTA gate enter ... has_token=true
[pre-function] ZTA jwt claims ... azp=recruiter-app user=recruiter1
[pre-function] ZTA OPA decision allow=true user=recruiter1            # auth PASS
[error] connect() failed (111: Connection refused) while connecting to upstream,
        upstream: "http://10.108.224.93:80/api/recruiters/profile"     # x6 (retries=5)
upstream_status: "502, 502, 502, 502, 502, 502"   source: "kong"
```

Đối chiếu log app `identity-service` (container `app`):
```
[08-Jun 15:21:41] NOTICE: ready to handle connections
[08-Jun 15:21:43] NOTICE: ready to handle connections
[08-Jun 15:21:50] NOTICE: ready to handle connections   # php-fpm respawn mỗi ~2-7s
...
[watch-env] Restarting laravel-service processes        # lặp liên tục
```

**Kết luận:** JWT + OPA đều PASS → **không phải Keycloak/quyền**. Lỗi là `connect() failed (111: Connection refused)` — TCP bị từ chối ngay tại pod vì **không có gì nghe ở `:8000`** đúng khoảnh khắc Kong gọi (nginx/php-fpm vừa bị giết, đang khởi động lại). Request **chưa bao giờ tới Laravel** → **không phải DB/credential**, **không phải Cilium** (Cilium chặn sẽ là timeout/drop trong hubble, không phải "connection refused", và việc reload app làm thông ngay chứng tỏ không phải network policy).

## 3. Nguyên nhân gốc

`src/<svc>/laravel_back/docker/watch-env.sh` (bản cũ trong image đang chạy):

1. Theo dõi MD5 `/vault/secrets/.env.db`, lưu `LAST_SUM` **chỉ trong biến RAM**.
2. Khi thấy "khác" → chạy `supervisorctl restart laravel-service:*` — restart **cả group**, **bao gồm chính `watch-env`**.
3. `watch-env` bị SIGTERM → respawn → `LAST_SUM=""` (mất state) → so với MD5 file thấy "khác" → restart cả group lần nữa → **loop vô tận** mỗi ~3s.
4. nginx/php-fpm bị bật-tắt liên tục → Kong gọi trúng "khe" đang down → **502**.

> Lưu ý: file `.env.db` **không hề đổi** (MD5 giống nhau qua nhiều lần đo) — loop là **tự sinh** do mất state + tự restart chính nó, KHÔNG phải do Vault rotate.

**Bản chất:** vấn đề không phải "restart" nói chung, mà là **(a) tự restart chính mình** cộng **(b) chỉ giữ dedup state trong RAM**. Khắc phục **một trong hai** là đủ phá loop; bản fix làm cả hai.

## 4. Logic Laravel ↔ Vault thực tế (làm rõ thêm cho #43)

Mỗi pod có: `vault-agent` → `env-loader` (sidecar) → `env-watcher` (sidecar) → `app` (supervisor chạy nginx/php-fpm + `watch-env`). Có **3 watcher** cùng soi file Vault (dư thừa, chồng chéo):

1. `vault-agent` render `/vault/secrets/{.env.common,.env.db,.env.db.lease}`.
2. `env-loader` (md5 `.env.db`) merge → `/vault/secrets/.env` → publish `/app-secrets/.env`.
3. **Laravel đọc creds từ `/var/www/.env`** lúc php-fpm worker bootstrap. `run.sh` chỉ `route:cache` (KHÔNG `config:cache`) nên `.env` được đọc "live". `postStart` chỉ `cp /app-secrets/.env → /var/www/.env` **một lần** khi pod khởi động.
4. Khi rotate cần (a) cập nhật `/var/www/.env` và (b) cho worker nạp lại:
   - **`identity-service`**: có `HotReloadServiceProvider` + route `POST /api/internal/reload-db`. `env-watcher` gọi endpoint này → `DB::reconnect()` runtime → **zero-downtime, không cần restart**. → identity **không cần** in-app `watch-env`.
   - **6 service còn lại** (job, communication, storage, hiring, workspace, candidate): **KHÔNG có** endpoint reload-db. `env-watcher` fallback `SIGUSR2` cho php-fpm, nhưng USR2 chỉ làm worker đọc lại `/var/www/.env` — mà `env-watcher` **không** cập nhật file này. **Chỉ in-app `watch-env` mới copy `/vault/secrets/.env → /var/www/.env`.** → với 6 service này, in-app `watch-env` đang **load-bearing** cho rotation, nên **không thể bỏ** nếu chưa đổi cơ chế.

## 5. Cách sửa (không rebuild image)

Viết lại `watch-env.sh` để không bao giờ tự-loop, đồng thời **giữ nguyên** hành vi sync credential mà 6 service kia phụ thuộc:

```diff
- LAST_SUM=""                                   # RAM only -> mất khi restart
- if [ "$SUM" != "$LAST_SUM" ]; then
-   supervisorctl restart laravel-service:*     # restart cả watch-env -> loop
+ LAST_SUM=$(cat /tmp/watch-env.last-sum ...)   # persist -> sống qua restart
+ # cần MD5 đổi VÀ >= 300s kể từ lần restart trước (cooldown)
+ if [ "$SUM" != "$LAST_SUM" ] && [ $((NOW - LAST_RESTART_TIME)) -gt 300 ]; then
+   cp -f /vault/secrets/.env /var/www/.env
+   supervisorctl restart laravel-service:nginx laravel-service:php8-fpm \
+                         laravel-service:laravel-queue_00   # KHÔNG có watch-env
```

Điểm chính:
- Dedup/cooldown state ghi ra `/tmp` → process respawn vẫn nhớ đã xử lý creds hiện tại.
- Tên restart phải **đủ tiền tố group** (`laravel-service:nginx`...). Tên trần (`nginx`) dưới supervisor có group sẽ **fail âm thầm** → hỏng reload ở 6 service không có endpoint HTTP.
- Loại trừ `watch-env` và one-shot `laravel-schedule`.

**Triển khai không rebuild:** image đang chạy giữ script cũ, nên đưa bản fixed vào chart `laravel-app` và mount đè `/usr/local/bin/watch-env.sh` qua ConfigMap `subPath` trong container `app`. Một `helm upgrade` mỗi service là áp cho cả 7 và **sống sót qua pod restart**.

- `k8s-management/charts/laravel-app/files/watch-env.sh` (mới — bản canonical)
- `templates/env-watcher-configmap.yaml` — thêm key `watch-env.sh`
- `templates/deployment.yaml` — mount `subPath: watch-env.sh` vào container `app`
- `src/*/laravel_back/docker/watch-env.sh` — chuẩn hoá đồng nhất cả 7 (repo trước đó không đồng nhất: chỉ identity có fix một phần)

## 6. Rollout

```bash
NS=job7189-apps
for SVC in identity job communication storage hiring workspace candidate; do
  helm upgrade --install "$SVC-service" k8s-management/charts/laravel-app \
    -n "$NS" -f "k8s-management/values/$SVC-values.yaml"
  kubectl -n "$NS" rollout status "deploy/$SVC-service" --timeout=300s
done
```

> Cảnh báo `cosign signature ... http: server gave HTTP response to HTTPS client` khi upgrade là **pre-existing** (registry nội bộ chạy HTTP), không liên quan fix này.

## 7. Kiểm chứng (identity-service)

```
grep -c MIN_RESTART_INTERVAL /usr/local/bin/watch-env.sh   -> 2 (đã mount bản fixed; bản cũ = 0)
supervisorctl status   -> nginx/php8-fpm RUNNING, uptime tăng đều (KHÔNG reset)
log 30s                -> hết spam "[watch-env] Restarting...", php-fpm không respawn liên tục
health x5              -> 200,200,200,200,200
GET /api/recruiters/profile (qua tunnel) -> 200
```

## 8. Bài học & follow-up

- **Trace bằng request thật** (lấy `request_id` từ response rồi tra log Kong) thay vì đoán bằng curl tự chế.
- `connect() failed (111: Connection refused)` = lỗi tầng app (không ai nghe), **không phải** network policy/Cilium.
- Tránh dùng `supervisorctl restart <group>:*` cho watcher nằm trong chính group đó; giữ state ra file, không tự restart.
- **Dư thừa kiến trúc:** đang có 3 watcher cùng soi một file Vault. Hướng dọn dẹp (chưa làm, để follow-up):
  - **B:** trỏ Laravel đọc thẳng `/app-secrets/.env` (symlink `/var/www/.env`) → để `env-loader` + `env-watcher` (USR2) lo → **bỏ hẳn in-app `watch-env`**.
  - **C:** thêm `HotReloadServiceProvider` + route `/api/internal/reload-db` cho cả 7 → reconnect runtime, zero-downtime, bỏ in-app `watch-env`.
