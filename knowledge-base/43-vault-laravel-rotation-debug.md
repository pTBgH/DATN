# 43. Vault & Laravel Dynamic Credentials Rotation & Debug

Tài liệu này đặc tả cơ chế nạp lại mật khẩu động (hot-reload) khi Vault Database Engine thực hiện xoay vòng thông tin đăng nhập định kỳ trên cụm `job7189` ZTA.

---

## 1. Bản đồ liên kết các thành phần

Mỗi Pod trong namespace `job7189-apps` chứa 4 containers chạy song song:
1. `vault-agent` (Sidecar - inject bởi Vault Webhook)
2. `env-loader` (Sidecar - image busybox)
3. `env-watcher` (Sidecar - image alpine)
4. `app` (Container chính - chạy Laravel & Nginx qua Supervisor)

### Luồng nạp credential ban đầu và xoay vòng:

```
[Vault Server] 
      │ (Xoay vòng mật khẩu sau 2/3 thời gian của TTL)
      ▼
[vault-agent] 
      │ 
      │ 1. Nạp token từ K8s auth.
      │ 2. Query dynamic role: database/creds/<service-name>
      │ 3. Render file: /vault/secrets/.env.db (và .env.db.lease)
      ▼
[env-loader] 
      │
      │ 1. Phát hiện MD5 /vault/secrets/.env.db thay đổi.
      │ 2. Gộp .env.common + .env.db + .env.extra thành file duy nhất.
      │ 3. Ghi đè lên volume Memory chung: /app-secrets/.env
      ▼
[app container] (Chạy watch-env.sh ngầm dưới supervisor)
      │
      │ 1. Phát hiện MD5 /app-secrets/.env thay đổi.
      │ 2. Copy đè vào thư mục app chính: /var/www/.env
      │ 3. Chạy lệnh: supervisorctl restart laravel-service:*
      ▼
[Laravel & Workers] (Nạp lại cấu hình, kết nối DB bằng credential mới)
```

---

## 2. Các vị trí code quan trọng

- **Hạ tầng / Helm**:
  - `k8s-management/charts/laravel-app/templates/deployment.yaml`: Cấu hình annotations của Vault, shareProcessNamespace, mount memory volume `/app-secrets` và sidecars.
  - `k8s-management/charts/laravel-app/files/env-watcher.sh`: Script theo dõi của container phụ `env-watcher`.
- **Ứng dụng / Project**:
  - `src/<service-name>/laravel_back/docker/watch-env.sh`: Script chạy ngầm trong container `app`.
  - `src/<service-name>/laravel_back/docker/supervisor.conf`: Cấu hình Supervisor khởi chạy Nginx, PHP-FPM, các consumer Kafka, queue worker và script `watch-env.sh`.

---

## 3. Quy trình gỡ lỗi (Debugging / Troubleshooting)

Khi gặp lỗi **SQLSTATE[HY000] [1045] Access denied for user 'v-kubernetes-...'** trên Laravel:

### Bước 1: Kiểm tra xem Vault và MySQL có đang sống ổn định không
```bash
kubectl get pods -n vault
kubectl get pods -n data
```

### Bước 2: Kiểm tra credential mà App đang giữ
Truy cập vào container `app` và xem nội dung `.env` hiện tại:
```bash
kubectl exec -n job7189-apps deploy/identity-service -c app -- grep DB_USERNAME /var/www/.env
```

### Bước 3: Kiểm tra xem user đó có còn tồn tại trên MySQL không
Lấy mật khẩu root MySQL từ Vault và truy vấn bảng user của MySQL:
```bash
ROOT_TOKEN="<vault-root-token>"
MYSQL_PASS=$(kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN='${ROOT_TOKEN}' vault kv get -format=json secret/mysql" | jq -r '.data.data["root-password"]')

kubectl exec -it -n data deploy/mysql -- mysql -uroot -p"${MYSQL_PASS}" -e "SELECT user, host FROM mysql.user;"
```
- **Nếu user trong `.env` không có trong MySQL**: Chứng tỏ cơ chế xoay vòng bị đứt gãy ở bước reload. Laravel vẫn giữ cấu hình cũ trong khi mật khẩu đã bị Vault/MySQL hủy.
- **Nếu user có trong MySQL nhưng vẫn báo 1045**: Kiểm tra lại phân quyền IP/Host hoặc các chính sách Cilium Network Policy chặn kết nối MySQL.

### Bước 4: Kiểm tra log của tiến trình watch-env
Đọc log của pod container `app` để xem `watch-env.sh` có in dòng trạng thái thay đổi không:
```bash
kubectl logs -n job7189-apps deploy/identity-service -c app --tail=100
# Tìm kiếm: "[watch-env] .env changed; syncing to /var/www/.env and restarting php-fpm"
```
Nếu không có dòng này, kiểm tra xem supervisor có đang chạy chương trình `watch-env` không:
```bash
kubectl exec -n job7189-apps deploy/identity-service -c app -- supervisorctl status
```

---

## 4. Kiểm tra thủ công (Manual Trigger)

Để kích hoạt xoay vòng ngay lập tức mà không cần đợi TTL hết hạn (phục vụ kiểm tra lỗi):
1. Đọc Lease ID hiện tại từ pod:
   ```bash
   kubectl exec -n job7189-apps deploy/identity-service -c app -- grep LEASE_ID /var/www/.env
   ```
2. Thu hồi lease trên Vault:
   ```bash
   vault lease revoke <lease_id>
   ```
3. Chờ 5-10 giây, kiểm tra lại `/var/www/.env`. Nếu `DB_USERNAME` thay đổi và Laravel không bị lỗi kết nối, hệ thống nạp lại thành công.

---

## 5. Chu kỳ xoay vòng cấu hình TTL 15 phút

Cụm ZTA áp dụng chính sách xoay vòng định kỳ ngắn để tăng tính an toàn mật khẩu động (mặc định cho môi trường debug/test):

- **TTL (Time to Live)**: Được thiết lập là `15m` (`default_ttl=15m`, `max_ttl=15m`).
- **Thời điểm xoay vòng**: Vault Agent tự động render lại credential khi đi qua **2/3 thời gian của TTL** (tương đương **10 phút**).
- **Cơ chế Zero-Downtime**: 
  - Tại phút thứ 10, Vault Agent sinh ra credential mới (username/password mới) và cập nhật vào ứng dụng. Ứng dụng Laravel tự động hot-reload mà không cần khởi động lại Pod (chỉ Supervisor restart các queue worker/web service bên trong container).
  - Credential cũ vẫn tiếp tục có hiệu lực trong database cho đến hết 15 phút (tức là có 5 phút chạy song song cả user cũ và mới). Điều này giúp các request hoặc queue jobs đang chạy dở dang không bị ngắt kết nối đột ngột.
  - Tại phút thứ 15, Vault Server chính thức thu hồi (revoke) Lease cũ và MySQL tự động xóa user cũ. Lúc này user cũ sẽ không thể kết nối (Access Denied 1045).
