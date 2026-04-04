<?php
namespace App\Enums;

enum WorkspacePermission: int
{
    use BitmaskHelper;

    // === NHÓM 1: STANDARD (Dành cho các Workspace thông thường) ===
    case VIEW_SETTINGS      = 1;
    case UPDATE_INFO        = 2;
    case MANAGE_MEMBERS     = 4;
    case DELETE_WORKSPACE   = 8;
    case MANAGE_BILLING     = 16;
    case VIEW_ANALYTICS     = 32;
    case EXPORT_REPORT      = 64;

    // === NHÓM 2: SYSTEM (Chỉ dành cho Workspace Admin hệ thống) ===
    case OVERRIDE_PERMISSIONS = 128;
    case BAN_WORKSPACE        = 256;
    case UNBAN_WORKSPACE      = 512;

    /**
     * Trả về danh sách các quyền cơ bản (Recruiter dùng được)
     */
    public static function standardCases(): array
    {
        return [
            self::VIEW_SETTINGS,
            self::UPDATE_INFO,
            self::MANAGE_MEMBERS,
            self::DELETE_WORKSPACE,
            self::MANAGE_BILLING,
            self::VIEW_ANALYTICS,
            self::EXPORT_REPORT,
        ];
    }

    /**
     * Trả về danh sách quyền hệ thống (Chỉ Admin hệ thống dùng được)
     */
    public static function systemCases(): array
    {
        return [
            self::OVERRIDE_PERMISSIONS,
            self::BAN_WORKSPACE,
            self::UNBAN_WORKSPACE,
        ];
    }

    /**
     * Mask cho phép gán trong Workspace thường (Tránh leo thang đặc quyền)
     */
    public static function getStandardMask(): int
    {
        return self::getMask(self::standardCases());
    }
}