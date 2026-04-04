<?php
namespace App\Enums;

enum JobStatusEnum: int
{
    case DRAFT      = 0;
    case PENDING    = 10;
    case PUBLISHED  = 20;
    case ARCHIVED   = 30;
    case EXPIRED    = 40;
    case REJECTED   = 41;

    public function label(): string
    {
        return match ($this) {
            self::DRAFT      => 'Draft',
            self::PENDING    => 'Pending',
            self::PUBLISHED  => 'Published',
            self::ARCHIVED   => 'Archived',
            self::EXPIRED    => 'Expired',
            self::REJECTED   => 'Rejected',
        };
    }
}