<?php
namespace App\Enums;

enum JobPermission: int
{
    use BitmaskHelper;

    // === STANDARD ===
    case READ_JOB               = 1;
    case CREATE_JOB             = 2;
    case UPDATE_JOB             = 4;
    case REQUEST_APPROVE_NEW    = 8;
    case REQUEST_APPROVE_UPDATE = 16;
    case CLOSE_JOB              = 32;
    case PAUSE_JOB              = 64;
    case RESUME_JOB             = 128;
    case ARCHIVE_JOB            = 256;
    case DELETE_JOB             = 512;
    case SHARE_JOB_EXTERNAL     = 1024;
    
    // === SYSTEM ADMIN ONLY ===
    case APPROVE_JOB            = 2048;  // Duyệt tin (nếu sàn bắt duyệt)
    case REJECT_JOB             = 4096;  // Từ chối tin
    case SUSPEND_JOB            = 8192;  // Đình chỉ do vi phạm
    case UNSUSPEND_JOB          = 16384; // Gỡ đình chỉ

    public static function standardCases(): array
    {
        return [
            self::READ_JOB, self::CREATE_JOB, self::UPDATE_JOB,
            self::REQUEST_APPROVE_NEW, self::REQUEST_APPROVE_UPDATE,
            self::CLOSE_JOB, self::PAUSE_JOB, self::RESUME_JOB,
            self::ARCHIVE_JOB, self::DELETE_JOB, self::SHARE_JOB_EXTERNAL
        ];
    }

    public static function systemCases(): array
    {
        return [
            self::APPROVE_JOB, self::REJECT_JOB, 
            self::SUSPEND_JOB, self::UNSUSPEND_JOB
        ];
    }

    public static function getStandardMask(): int
    {
        return self::getMask(self::standardCases());
    }
}