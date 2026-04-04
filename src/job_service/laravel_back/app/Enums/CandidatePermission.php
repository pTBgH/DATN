<?php

namespace App\Enums;

enum CandidatePermission: int
{
    use BitmaskHelper;

    case VIEW_ALL_CANDIDATES     = 1;   // Bit 1: Xem danh sách & hồ sơ
    case MOVE_CANDIDATE          = 2;   // Bit 2: Di chuyển giữa các stage
    case VIEW_CONTACT_INFO       = 4;   // Bit 3: Xem email/phone
    case COMMENT_ON_CANDIDATE    = 8;   // Bit 4: Comment/Note
    case REJECT_CANDIDATE        = 16;  // Bit 5: Từ chối ứng viên
    case HIRE_CANDIDATE          = 32;  // Bit 6: Tuyển dụng
    case DELETE_CANDIDATE_DATA   = 64;  // Bit 7: Xóa dữ liệu (GDPR)
    case EXPORT_CANDIDATE_REPORT = 128; // Bit 8: Xuất báo cáo

    /**
     * Danh sách quyền chuẩn cho Recruiter Admin
     */
    public static function standardCases(): array
    {
        // Mặc định cho Owner/Admin hưởng full quyền candidate
        return [
            self::VIEW_ALL_CANDIDATES,
            self::MOVE_CANDIDATE,
            self::VIEW_CONTACT_INFO,
            self::COMMENT_ON_CANDIDATE,
            self::REJECT_CANDIDATE,
            self::HIRE_CANDIDATE,
            self::DELETE_CANDIDATE_DATA,
            self::EXPORT_CANDIDATE_REPORT,
        ];
    }

    public static function getStandardMask(): int
    {
        return self::getMask(self::standardCases());
    }
}