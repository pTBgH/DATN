<?php

namespace App\Enums;

enum SystemRole: string
{
    // --- CẤP QUẢN TRỊ (Level 1) ---
    case ADMIN          = 'admin';
    case REC_OPS        = 'rec_ops';

    // --- CẤP THỰC THI (Level 2) ---
    case RECRUITER      = 'recruiter';
    case SOURCER        = 'sourcer';
    case COORDINATOR    = 'coordinator';

    // --- CẤP ĐÁNH GIÁ (Level 3) ---
    case HIRING_MANAGER = 'hiring_manager';
    case INTERVIEWER    = 'interviewer';
    case MEMBER          = 'member';

    public function label(): string
    {
        return match ($this) {
            self::ADMIN          => 'Admin (Toàn quyền)',
            self::REC_OPS        => 'Recruitment Ops (Cấu hình)',
            self::RECRUITER      => 'Recruiter (Tuyển dụng)',
            self::SOURCER        => 'Sourcer (Tìm nguồn)',
            self::COORDINATOR    => 'Coordinator (Điều phối)',
            self::HIRING_MANAGER => 'Hiring Manager (Trưởng bộ phận)',
            self::INTERVIEWER    => 'Interviewer (Phỏng vấn)',
            self::MEMBER          => 'Member (Thành viên)',
        };
    }

    public function description(): string
    {
        return match ($this) {
            self::ADMIN          => 'Quyền lực tối cao. Quản lý thành viên, gói cước (Billing), và cấu hình toàn hệ thống.',
            self::REC_OPS        => 'Kiến trúc sư quy trình. Được sửa Pipeline, tạo Template email/đánh giá, xem báo cáo hiệu suất.',
            self::RECRUITER      => 'Người tuyển dụng chính. Đăng tin, quản lý ứng viên từ A-Z, gửi Offer.',
            self::SOURCER        => 'Chuyên săn nhân tài. Thêm ứng viên (Prospect), chuyển đổi sang Candidate.',
            self::COORDINATOR    => 'Hậu cần. Chỉ xem danh sách ứng viên để xếp lịch phỏng vấn.',
            self::HIRING_MANAGER => 'Người ra quyết định. Đăng yêu cầu tuyển dụng (Job), xem và duyệt ứng viên của team mình.',
            self::INTERVIEWER    => 'Người đánh giá. Chỉ xem CV được giao và chấm điểm (Scorecard).',
            self::MEMBER          => 'Tài khoản đã được quản trị viên phê duyệt nhưng chưa gán vai trò.',
        };
    }

    public function getPermissions(): array
    {
        return match ($this) {
            self::ADMIN => [
                'workspace' => WorkspacePermission::getStandardMask(),
                'job'       => JobPermission::getStandardMask(),
                'candidate' => CandidatePermission::getStandardMask(),
                'pipeline'  => PipelinePermission::getStandardMask(),
            ],
            self::REC_OPS => [
                'workspace' => WorkspacePermission::VIEW_SETTINGS->value | WorkspacePermission::VIEW_ANALYTICS->value | WorkspacePermission::EXPORT_REPORT->value,
                'job'       => JobPermission::READ_JOB->value,
                'candidate' => CandidatePermission::VIEW_ALL_CANDIDATES->value,
                'pipeline'  => PipelinePermission::getStandardMask(),
            ],
            self::RECRUITER => [
                'workspace' => WorkspacePermission::VIEW_SETTINGS->value,
                'job'       => JobPermission::getStandardMask() & ~JobPermission::DELETE_JOB->value,
                'candidate' => CandidatePermission::getStandardMask(),
                'pipeline'  => PipelinePermission::READ_PIPELINE->value,
            ],
            self::SOURCER => [
                'workspace' => 0,
                'job'       => JobPermission::READ_JOB->value,
                'candidate' => CandidatePermission::VIEW_ALL_CANDIDATES->value | CandidatePermission::MOVE_CANDIDATE->value | CandidatePermission::COMMENT_ON_CANDIDATE->value,
                'pipeline'  => PipelinePermission::READ_PIPELINE->value,
            ],
            self::COORDINATOR => [
                'workspace' => 0,
                'job'       => JobPermission::READ_JOB->value,
                'candidate' => CandidatePermission::VIEW_ALL_CANDIDATES->value | CandidatePermission::COMMENT_ON_CANDIDATE->value,
                'pipeline'  => PipelinePermission::READ_PIPELINE->value,
            ],
            self::HIRING_MANAGER => [
                'workspace' => WorkspacePermission::VIEW_ANALYTICS->value,
                'job'       => JobPermission::CREATE_JOB->value | JobPermission::UPDATE_JOB->value | JobPermission::READ_JOB->value | JobPermission::CLOSE_JOB->value,
                'candidate' => CandidatePermission::getStandardMask() & ~CandidatePermission::DELETE_CANDIDATE_DATA->value,
                'pipeline'  => PipelinePermission::READ_PIPELINE->value,
            ],
            self::INTERVIEWER => [
                'workspace' => 0,
                'job'       => JobPermission::READ_JOB->value,
                'candidate' => CandidatePermission::VIEW_ALL_CANDIDATES->value | CandidatePermission::COMMENT_ON_CANDIDATE->value,
                'pipeline'  => PipelinePermission::READ_PIPELINE->value,
            ],
            self::MEMBER => [
                'workspace' => 0,
                'job'       => 0,
                'candidate' => 0,
                'pipeline'  => 0,
            ],
        };
    }

    /**
     * Logic tìm nhiều Role gần đúng
     */
    public static function inferRoles(array $currentPerms): array
    {
        $matchedRoles = [];
        $coveredMask = ['workspace' => 0, 'job' => 0, 'candidate' => 0, 'pipeline' => 0];

        foreach (self::cases() as $role) {
            $template = $role->getPermissions();

            $isSuperset = 
                (((int)$currentPerms['workspace'] & $template['workspace']) === $template['workspace']) &&
                (((int)$currentPerms['job']       & $template['job'])       === $template['job']) &&
                (((int)$currentPerms['candidate'] & $template['candidate']) === $template['candidate']) &&
                (((int)$currentPerms['pipeline']  & $template['pipeline'])  === $template['pipeline']);

            if ($isSuperset) {
                if ($role === self::ADMIN) {
                    return ['roles' => [self::ADMIN], 'is_custom' => false];
                }
                $matchedRoles[] = $role;
                $coveredMask['workspace'] |= $template['workspace'];
                $coveredMask['job']       |= $template['job'];
                $coveredMask['candidate'] |= $template['candidate'];
                $coveredMask['pipeline']  |= $template['pipeline'];
            }
        }

        $hasExtra = 
            ((int)$currentPerms['workspace'] & ~$coveredMask['workspace']) > 0 ||
            ((int)$currentPerms['job']       & ~$coveredMask['job'])       > 0 ||
            ((int)$currentPerms['candidate'] & ~$coveredMask['candidate']) > 0 ||
            ((int)$currentPerms['pipeline']  & ~$coveredMask['pipeline'])  > 0;

        return [
            'roles' => $matchedRoles,
            'is_custom' => $hasExtra || empty($matchedRoles)
        ];
    }

    /**
     * [MỚI] Trả về định nghĩa cho Frontend
     */
    public static function getDefinitions(): array
    {
        $data = [];
        foreach (self::cases() as $case) {
            $data[] = [
                'key'         => $case->value,
                'label'       => $case->label(),
                'description' => $case->description(),
                'permissions' => $case->getPermissions(),
            ];
        }
        return $data;
    }
}