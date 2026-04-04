#!/bin/sh


# 1. CẤU HÌNH MỚI CHO KONG
KONG_ADMIN="http://localhost:19001" # Port Admin Kong (Phai port forwading trc)


# URL Realm MỚI (Giá trị trường "iss" trong Token)

# NEW_REALM_URL="http://auth.job7189.com/realms/job7189"
NEW_REALM_URL="https://cv-auth.neu.edu.vn/realms/topjob"

# Public Key MỚI (Lấy từ Bước 1)

# NEW_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv+zbBITiDjsVanHaDNaxl5JqPPUUqD9jBAz6BYs+dARNeeBXy0hjgMt5vlH6GWDhNyqrToHIaXe8djfiNE2RwVScVGIlwyMSvDguCU8Te828HXzOK0UiQGeT9KN06aX/ooWZY6GXVIm6p2zFNX2M/uHuNVrgaTh3/kNEtffJeAQAiBBNfqdcakKyfAAmJmS0JO8wjX07ypxi2ws6bmwMH0VQMbFPAo1NshyEsr1++T8nIgKROzP37y+15bD9eG0DpQgaJQ0EHIOzcj04QMtKUTJCdSYxqlUKGXlZT16TNzO8c5Z9uIBnmGoDZwu4yKlJ4GE2B5yMgJPiKkLcMbPgMQIDAQAB
# -----END PUBLIC KEY-----"

NEW_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtK10WmTfINKQIz4sD1U9jNqg3dW95kGZC9v6ofWM8/EFQ44PaxwCc4KbaHtXKKf/528dXedC63TVL1XxFxLWzCfeS3GJv0uLg3hwsTupGSxswodRYjlw3t6kFADxXMfYhmSd34LB5L6sgfKX73jv85NmUAVN4CASvRZDB5JKeqNzyoJcUnfIEMBsWkl2WHInXTbt7M+1plKODfeDrmLDj/q/6bMXxwKxmkhz8as+iOh4t7+xc1qqXdw/IL2YdoKdBHpK7QtxTQnTt78A1tPZ7/osW3Nmv5QEvLkCfD8rVsVAI074/5+aF6bbkfakRe4jQm+yHzY7NVkE1Y0mknSm6QIDAQAB
-----END PUBLIC KEY-----"


# 2. XÓA CẤU HÌNH CŨ (QUAN TRỌNG)
echo "Đang xóa Consumer cũ để reset key..."
# Xóa consumer sẽ tự động xóa luôn các JWT credential cũ gắn với nó
curl -s -X DELETE "$KONG_ADMIN/consumers/keycloak-user" > /dev/null


# 3. TẠO LẠI TỪ ĐẦU
echo "Tạo lại Consumer..."
curl -s -X POST "$KONG_ADMIN/consumers" \
 -d "username=keycloak-user" \
 -d "custom_id=keycloak-issuer"


echo "Nạp Public Key MỚI..."
# Lưu ý: key=$NEW_REALM_URL để Kong khớp với iss trong token mới
curl -s -X POST "$KONG_ADMIN/consumers/keycloak-user/jwt" \
 -d "algorithm=RS256" \
 -d "key=$NEW_REALM_URL" \
 --data-urlencode "rsa_public_key=$NEW_RSA_PUBLIC_KEY"


echo "Cập nhật Plugin cho các Route..."
# Danh sách các route cần bảo vệ
ROUTERS="job-workspace-context job-admin workspace-core hiring-applications candidate-resumes candidate-interactions comm-conversations identity-profiles"


for ROUTE in $ROUTERS; do
 # Thử xóa plugin cũ trước (nếu có) để tránh lỗi conflict
 PLUGIN_ID=$(curl -s "$KONG_ADMIN/routes/$ROUTE/plugins" | jq -r '.data[] | select(.name=="jwt") | .id')
 if [ "$PLUGIN_ID" != "" ] && [ "$PLUGIN_ID" != "null" ]; then
     curl -s -X DELETE "$KONG_ADMIN/routes/$ROUTE/plugins/$PLUGIN_ID" > /dev/null
 fi


 # Tạo plugin mới
 curl -s -X POST "$KONG_ADMIN/routes/$ROUTE/plugins" \
   -d "name=jwt" \
   -d "config.claims_to_verify=exp" \
   -d "config.key_claim_name=iss" > /dev/null
  
 echo "$ROUTE: Secured"
done


echo "HOÀN TẤT CHUYỂN ĐỔI KEYCLOAK!"