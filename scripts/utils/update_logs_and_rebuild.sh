#!/bin/bash
echo "Đang cập nhật các lệnh Log:: thành StructuredLogger một cách tương đối (Naive replace)..."

for svc in src/*_service/laravel_back/app; do
    if [ -d "$svc" ]; then
        # Thêm use StructuredLogger vào các file có use Illuminate\Support\Facades\Log;
        find "$svc" -type f -name "*.php" -exec sed -i 's/use Illuminate\\Support\\Facades\\Log;/use Illuminate\\Support\\Facades\\Log;\nuse App\\Support\\Logging\\StructuredLogger;/g' {} +
        
        # Thay thế cơ bản Log::info('msg') -> (new StructuredLogger('app', 'info'))->info(['message' => 'msg'])
        # Lưu ý: Do regex bash không thể hiểu hết AST của PHP, đây là thay thế bề mặt.
        find "$svc" -type f -name "*.php" -exec sed -i "s/Log::info(/\\(new StructuredLogger('system', 'action')\\)->info(['message' => /g" {} +
        find "$svc" -type f -name "*.php" -exec sed -i "s/Log::error(/\\(new StructuredLogger('system', 'error')\\)->error(['message' => /g" {} +
        find "$svc" -type f -name "*.php" -exec sed -i "s/Log::warning(/\\(new StructuredLogger('system', 'warning')\\)->warning(['message' => /g" {} +
    fi
done

echo "Hoàn tất cập nhật code log. Tiến hành build và restart lại các pod..."
# Chạy script rebuild laravel nếu có
if [ -f "./rebuild-laravel.sh" ]; then
    bash ./rebuild-laravel.sh
elif [ -f "./04-build-and-push-images.sh" ]; then
    bash ./04-build-and-push-images.sh
    kubectl rollout restart deployment -l app.kubernetes.io/part-of=job7189 -n job7189-apps
else
    echo "Không tìm thấy script build. Đang tự restart pods..."
    kubectl rollout restart deployment -n job7189-apps
fi

echo "Hoàn tất!"
