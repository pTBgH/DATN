<?php
// file: app/Models/Traits/HasUuids.php

namespace App\Models\Traits;

use Ramsey\Uuid\Uuid;

trait HasUuids
{
    /**
     * Ghi đè phương thức booting của model.
     */
    protected static function bootHasUuids(): void
    {
        /**
         * Lắng nghe sự kiện "creating" (trước khi một bản ghi mới được lưu vào DB)
         * và tự động tạo UUIDv7 cho khóa chính.
         */
        static::creating(function ($model) {
            // Chỉ gán UUID nếu khóa chính chưa có giá trị
            if (!$model->getKey()) {
                // Dùng UUIDv7
                $model->{$model->getKeyName()} = Uuid::uuid7()->toString();
            }
        });
    }

    /**
     * Cho Laravel biết rằng khóa chính không phải là số nguyên tự tăng.
     */
    public function getIncrementing(): bool
    {
        return false;
    }

    /**
     * Cho Laravel biết kiểu dữ liệu của khóa chính là chuỗi.
     */
    public function getKeyType(): string
    {
        return 'string';
    }
}