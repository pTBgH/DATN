<?php

namespace App\Enums;

enum WorkspaceMemberStatus: int
{
    case ACTIVE  = 1; // Đã duyệt, đang hoạt động
    case PENDING = 2; // Đang trong hàng chờ (Vừa join by code)
    case REJECTED = 3; // Bị từ chối (Optional)
    
    public function label(): string
    {
        return match ($this) {
            self::ACTIVE  => 'Active',
            self::PENDING => 'Pending',
            self::REJECTED => 'Rejected',
            default       => 'Unknown',
        };
    }
}