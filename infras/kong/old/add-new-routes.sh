#!/bin/bash

# Cổng Admin của Kong (Check xem là 8001 hay 9001, thường forward là 8001)
KONG_ADMIN="http://localhost:19001"

echo "🚀 Bắt đầu thêm các API mới vào Kong..."

# Hàm tiện ích để thêm Route
add_route() {
    SERVICE_NAME=$1
    ROUTE_NAME=$2
    ROUTE_PATH=$3
    REGEX_PRIORITY=$4

    echo "\n--- Xử lý Route: $ROUTE_NAME ($SERVICE_NAME) ---"

    # 1. Lấy ID của Service
    SERVICE_ID=$(curl -s "$KONG_ADMIN/services/$SERVICE_NAME" | jq -r .id)

    if [ "$SERVICE_ID" == "null" ] || [ -z "$SERVICE_ID" ]; then
        echo "❌ Lỗi: Không tìm thấy Service '$SERVICE_NAME'. Bỏ qua."
        return
    fi

    # 2. Xóa Route cũ nếu có (để update)
    # Lấy ID route cũ
    OLD_ROUTE_ID=$(curl -s "$KONG_ADMIN/routes/$ROUTE_NAME" | jq -r .id)
    if [ "$OLD_ROUTE_ID" != "null" ]; then
        curl -s -X DELETE "$KONG_ADMIN/routes/$OLD_ROUTE_ID"
        echo "   🗑️  Đã xóa route cũ."
    fi

    # 3. Tạo Route mới
    # Nếu có Priority (cho Regex) thì thêm vào
    if [ -z "$REGEX_PRIORITY" ]; then
        curl -s -X POST "$KONG_ADMIN/services/$SERVICE_ID/routes" \
            -d "name=$ROUTE_NAME" \
            -d "paths[]=$ROUTE_PATH" \
            -d "strip_path=false" > /dev/null
    else
        curl -s -X POST "$KONG_ADMIN/services/$SERVICE_ID/routes" \
            -d "name=$ROUTE_NAME" \
            -d "paths[]=$ROUTE_PATH" \
            -d "regex_priority=$REGEX_PRIORITY" \
            -d "strip_path=false" > /dev/null
    fi
    echo "   ✅ Đã tạo Route mới: $ROUTE_PATH"

    # 4. Bật bảo vệ JWT (Luôn bật cho các API này)
    curl -s -X POST "$KONG_ADMIN/routes/$ROUTE_NAME/plugins" \
        -d "name=jwt" \
        -d "config.claims_to_verify=exp" \
        -d "config.key_claim_name=iss" > /dev/null
    echo "   🔒 Đã bật JWT Plugin."
}

# ==============================================================================
# 1. JOB SERVICE (Admin Categories)
# ==============================================================================
add_route "job-service" "job-admin-categories" "/api/admin/categories"

# ==============================================================================
# 2. HIRING SERVICE (Interview & Scorecard)
# ==============================================================================
# Route thường
add_route "hiring-service" "hiring-interviews" "/api/interviews"

# Route Regex: /api/applications/{id}/scorecards
# Lưu ý: %2B là mã hóa của dấu cộng (+) trong URL encode
add_route "hiring-service" "hiring-scorecards" "~/api/applications/[^/]%2B/scorecards" 100

# ==============================================================================
# 3. COMMUNICATION SERVICE (Chat)
# ==============================================================================
add_route "communication-service" "comm-conversations" "/api/conversations"
add_route "communication-service" "comm-messages" "/api/messages"

# Route Regex: /api/conversations/{id}/messages
add_route "communication-service" "comm-messages-history" "~/api/conversations/[^/]%2B/messages" 100

echo "\n🎉 HOÀN TẤT CẤU HÌNH KONG CHO API MỚI!"