<?php

namespace App\Services\Workspace;

use App\Models\Recruiter\Recruiter;
use App\Models\Workspace;
use App\Models\WorkspaceInvitation;
use App\Notifications\WorkspaceInvitationNotification;
use App\Enums\SystemRole;
use App\Enums\WorkspaceMemberStatus;
use App\Enums\WorkspacePermission;
use App\Enums\JobPermission;
use App\Enums\CandidatePermission;
use App\Enums\PipelinePermission;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;
use Carbon\Carbon;
use Throwable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\Cache;

class WorkspaceMemberService
{
    // --- READ ---

    public function getMembers(Workspace $workspace): Collection
    {
        return $this->getMembersByStatus($workspace, WorkspaceMemberStatus::ACTIVE);
    }

    public function getPendingMembers(Workspace $workspace): Collection
    {
        return $this->getMembersByStatus($workspace, WorkspaceMemberStatus::PENDING);
    }

    private function getMembersByStatus(Workspace $workspace, WorkspaceMemberStatus $status): Collection
    {
        return $workspace->members()
            ->wherePivot('status_id', $status)
            ->withPivot([
                'workspace_permissions', 'job_permissions', 'candidate_permissions', 
                'pipeline_permissions', 'status_id', 'created_at', 'updated_at'
            ])->get();
    }

    public function createInvitationCode(Workspace $workspace, Recruiter $creator, ?int $expiresInHours = null): WorkspaceInvitation
    {
        $wsId = $workspace->WorkspaceID;
        $userId = $creator->RecruiterID;
        
        $duration = $expiresInHours ?: 24;

        $cacheKey = "ws_invite_code:{$wsId}:{$userId}";

        try {
            $cachedInvite = \Illuminate\Support\Facades\Cache::get($cacheKey);
            if ($cachedInvite) {
                return $cachedInvite;
            }
        } catch (Throwable $e) {
            Log::channel('daily_error')->warning("[CreateCode] Cache read failed", ['error' => $e->getMessage()]);
        }

        do {
            $code = strtoupper(Str::random(6));
        } while (WorkspaceInvitation::where('code', $code)->exists());

        try {
            $invitation = WorkspaceInvitation::create([
                'WorkspaceID' => $wsId,
                'InvitedBy'   => $userId,
                'permissions' => null,
                'code'        => $code,
                'expires_at'  => now()->addHours($duration),
                'created_at'  => now(),
            ]);

            try {
                \Illuminate\Support\Facades\Cache::put($cacheKey, $invitation, now()->addHours($duration));
            } catch (Throwable $e) {
                Log::channel('daily_error')->warning("[CreateCode] Cache write failed", ['error' => $e->getMessage()]);
            }

            return $invitation;

        } catch (Throwable $e) {
            Log::channel('daily_error')->error("[CreateCode] DB Failed", [
                'ws_id' => $wsId,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            throw $e;
        }
    }

    public function inviteMembers(Workspace $workspace, Recruiter $inviter, array $invitations): array
    {
        (new StructuredLogger('system', 'action'))->info(['message' => '[InviteMembers] START', ['ws' => $workspace->WorkspaceID, 'count' => count($invitations)]);
        
        return $this->transaction(function () use ($workspace, $inviter, $invitations) {
            foreach ($invitations as $data) {
                $this->sendInvitation($workspace, $inviter, $data['email'] ?? '', $this->resolvePermissions($data));
            }
            return 'Invitations sent.';
        }, 'Invite failed');
    }

    private function sendInvitation(Workspace $ws, Recruiter $inviter, string $email, array $perms): void
    {
        // Skip if already member or pending invite
        if ($ws->members()->where('Email', $email)->exists()) return;
        if (WorkspaceInvitation::where('WorkspaceID', $ws->WorkspaceID)->where('email', $email)->where('expires_at', '>', now())->exists()) return;

        $token = Str::random(40);
        
        WorkspaceInvitation::create([
            'WorkspaceID' => $ws->WorkspaceID,
            'InvitedBy' => $inviter->RecruiterID,
            'email' => $email,
            'permissions' => $perms,
            'token' => $token,
            'expires_at' => now()->addHours(48),
        ]);

        try {
            Notification::route('mail', $email)->notify(new WorkspaceInvitationNotification(
                $token, 
                $inviter->FullName ?? $inviter->Email, 
                $ws->companyProfile->CompanyName ?? $ws->Name
            ));
        } catch (Throwable $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => 'Mail failed', ['email' => $email, 'error' => $e->getMessage()]);
        }
    }

    public function joinWithCode(string $code, Recruiter $user): array
    {
        // 1. Validate (Giữ nguyên logic cũ)
        $invitation = WorkspaceInvitation::where('code', $code)->first();
        if (!$invitation) return ['success' => false, 'message' => 'Invitation code not found.', 'code' => 404];
        if ($invitation->expires_at && $invitation->expires_at->isPast()) return ['success' => false, 'message' => 'This invitation code has expired.', 'code' => 400];
        $workspace = Workspace::find($invitation->WorkspaceID);
        if (!$workspace) return ['success' => false, 'message' => 'The workspace no longer exists.', 'code' => 404];
        if ($workspace->members()->where('rct_profiles.RecruiterID', $user->RecruiterID)->exists()) {
            return ['success' => false, 'message' => 'You are already a member of this workspace.', 'code' => 409];
        }

        try {
            // 2. Lấy quyền MEMBER
            $defaultPermissions = SystemRole::MEMBER->getPermissions();

            // 3. Gán user vào workspace với trạng thái ACTIVE
            $this->assignMember(
                $workspace, 
                $user, 
                $defaultPermissions,
                WorkspaceMemberStatus::ACTIVE
            );

            // 4. Load và trả về
            $workspace->load(['companyProfile', 'plan']);
            $workspace->permissions = $defaultPermissions;

            return [
                'success'   => true, 
                'message'   => 'Joined workspace successfully!',
                'workspace' => $workspace,
                'code'      => 200
            ];

        } catch (Throwable $e) {
            // --- SỬA LẠI LOG TẠI ĐÂY ---
            // Thêm $e->getMessage() để biết chính xác lỗi SQL là gì
            Log::channel('daily_error')->error('[JoinCode] DB Error', [
                'message' => $e->getMessage(), // <--- THÊM DÒNG NÀY
                'trace'   => $e->getTraceAsString()
            ]);
            
            return [
                'success' => false, 
                'message' => 'Failed to join workspace due to a system error.',
                'code'    => 500
            ];
        }
    }

    public function acceptInvitation(string $token, Recruiter $user): array
    {
        $invitation = WorkspaceInvitation::where('token', $token)->first();
        if (!$invitation) return $this->error('Invalid token.');
        if ($invitation->expires_at?->isPast()) return $this->error('Expired link.');
        if (strtolower($invitation->email) !== strtolower($user->Email)) return $this->error('Wrong email.');

        $ws = Workspace::find($invitation->WorkspaceID);
        if (!$ws) return $this->error('Workspace missing.');

        return $this->transaction(function () use ($ws, $user, $invitation) {
            $this->assignMember($ws, $user, $invitation->permissions, WorkspaceMemberStatus::ACTIVE);
            $invitation->delete();
            
            $ws->load(['companyProfile', 'plan']);
            $ws->permissions = $invitation->permissions;
            
            return ['message' => 'Joined successfully!', 'workspace' => $ws];
        }, 'Accept failed', true); // true = return data array
    }

    public function updateMembersPermissions(Workspace $workspace, Recruiter $actionBy, array $membersData): array
    {
        return $this->transaction(function () use ($workspace, $actionBy, $membersData) {
            
            foreach ($membersData as $member) {
                $recruiterId = $member['recruiter_id'];
                
                // 1. Phân giải quyền từ Role/Custom input
                $perms = $this->resolvePermissions($member);

                // 2. [QUAN TRỌNG] LUÔN LUÔN lọc bỏ các bit quyền hệ thống
                // Điều này ngăn Admin của workspace tự gán cho mình hoặc người khác các quyền của Super Admin
                $sanitizedPerms = $this->sanitizePerms($perms);

                // Ghi log để theo dõi ai đã đổi quyền cho ai
                Log::channel('daily_audit')->info('Member permissions updated.', [
                    'workspace_id'  => $workspace->WorkspaceID,
                    'admin_id'      => $actionBy->RecruiterID,
                    'target_id'     => $recruiterId,
                    'original_perms' => $perms,         // Quyền user cố gán
                    'sanitized_perms'=> $sanitizedPerms // Quyền thực tế được gán
                ]);
                
                // 3. Cập nhật vào DB với dữ liệu đã được làm sạch
                $workspace->members()->updateExistingPivot(
                    $recruiterId, 
                    array_merge($this->flattenPerms($sanitizedPerms), ['updated_at' => now()])
                );
            }
            return 'Members updated successfully.';
        }, 'Update failed');
    }

    // --- HELPERS (Logic Core) ---

    private function resolvePermissions(array $input): array
    {
        $final = ['workspace' => 0, 'job' => 0, 'candidate' => 0, 'pipeline' => 0];
        $roles = $input['roles'] ?? (isset($input['role']) ? [$input['role']] : []);

        foreach ($roles as $key) {
            if ($role = SystemRole::tryFrom($key)) {
                $tpl = $role->getPermissions();
                foreach ($final as $k => $v) $final[$k] |= $tpl[$k];
            }
        }

        if (!empty($input['permissions'])) {
            foreach ($final as $k => $v) $final[$k] |= ($input['permissions'][$k] ?? 0);
        }
        return $final;
    }

    private function sanitizePerms(array $perms): array
    {
        return [
            'workspace' => $perms['workspace'] & WorkspacePermission::getStandardMask(),
            'job'       => $perms['job'] & JobPermission::getStandardMask(),
            'candidate' => $perms['candidate'] & CandidatePermission::getStandardMask(),
            'pipeline'  => $perms['pipeline'] & PipelinePermission::getStandardMask(),
        ];
    }

    private function flattenPerms(array $perms): array
    {
        return [
            'workspace_permissions' => $perms['workspace'],
            'job_permissions'       => $perms['job'],
            'candidate_permissions' => $perms['candidate'],
            'pipeline_permissions'  => $perms['pipeline'],
        ];
    }

    private function assignMember(Workspace $ws, Recruiter $user, ?array $perms, WorkspaceMemberStatus $status): void
    {
        $p = $perms ?? ['workspace' => 0, 'job' => 0, 'candidate' => 0, 'pipeline' => 0];
        $ws->members()->syncWithoutDetaching([
            $user->RecruiterID => array_merge($this->flattenPerms($p), [
                'status_id' => $status,
                'created_at' => now(),
                'updated_at' => now()
            ])
        ]);
    }

    // --- HELPERS (Response & Log) ---

    private function success(string $msg): array { return ['success' => true, 'message' => $msg]; }
    
    private function error(string $msg): array { return ['success' => false, 'message' => $msg]; }

    private function exception(string $msg, Throwable $e): array 
    {
        (new StructuredLogger('system', 'error'))->error(['message' => $msg, ['error' => $e->getMessage()]);
        return ['success' => false, 'message' => $msg]; // Hide detail in prod
    }

    private function transaction(callable $callback, string $errorMsg, bool $returnData = false): array
    {
        try {
            return DB::transaction(function () use ($callback, $returnData, $errorMsg) {
                $result = $callback();
                if ($returnData && is_array($result)) return array_merge(['success' => true], $result);
                return ['success' => true, 'message' => $result];
            });
        } catch (Throwable $e) {
            return $this->exception($errorMsg, $e);
        }
    }

    public function removeMember(Workspace $ws, Recruiter $actionBy, Recruiter $target): array
    {
        try {
            $ws->members()->detach($target->RecruiterID);
            return $this->success('Removed.');
        } catch (Throwable $e) {
            return $this->exception('Remove failed', $e);
        }
    }

}