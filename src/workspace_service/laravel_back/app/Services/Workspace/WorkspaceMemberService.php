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
            ->wherePivot('status_id', $status->value ?? $status)
            ->withPivot([
                'workspace_permissions', 'job_permissions', 'candidate_permissions', 
                'pipeline_permissions', 'status_id', 'created_at', 'updated_at'
            ])->get();
    }

    public function createInvitationCode(Workspace $workspace, Recruiter $creator, ?int $expiresInHours = null): WorkspaceInvitation
    {
        $wsId = $workspace->WorkspaceID;
        $userId = $creator->internal_id ?? $creator->id;
        $duration = $expiresInHours ?: 24;
        $cacheKey = "ws_invite_code:{$wsId}:{$userId}";

        try {
            if ($cached = Cache::get($cacheKey)) return $cached;
        } catch (Throwable $e) {}

        do {
            $code = strtoupper(Str::random(6));
        } while (WorkspaceInvitation::where('code', $code)->exists());

        $invitation = WorkspaceInvitation::create([
            'InvitationID' => (string) Str::uuid(),
            'WorkspaceID' => $wsId,
            'InvitedBy'   => $userId,
            'permissions' => null,
            'code'        => $code,
            'email'       => 'CODE_INVITE', 
            'expires_at'  => now()->addHours($duration),
            'created_at'  => now(),
        ]);

        try {
            Cache::put($cacheKey, $invitation, now()->addHours($duration));
        } catch (Throwable $e) {}

        return $invitation;
    }

    public function inviteMembers(Workspace $workspace, Recruiter $inviter, array $invitations): array
    {
        return $this->transaction(function () use ($workspace, $inviter, $invitations) {
            foreach ($invitations as $data) {
                if (empty($data['email'])) continue;
                $this->sendInvitation($workspace, $inviter, $data['email'], $this->resolvePermissions($data));
            }
            return 'Invitations sent.';
        }, 'Invite failed');
    }

    private function sendInvitation(Workspace $ws, Recruiter $inviter, string $email, array $perms): void
    {
        if ($ws->members()->where('email', $email)->exists()) return;
        if (WorkspaceInvitation::where('WorkspaceID', $ws->WorkspaceID)->where('email', $email)->where('expires_at', '>', now())->exists()) return;

        $token = Str::random(40);
        
        WorkspaceInvitation::create([
            'InvitationID' => (string) Str::uuid(),
            'WorkspaceID' => $ws->WorkspaceID,
            'InvitedBy' => $inviter->internal_id ?? $inviter->id,
            'email' => $email,
            'permissions' => $perms,
            'token' => $token,
            'expires_at' => now()->addHours(48),
        ]);

        try {
            // Sử dụng $ws->Name thay vì $ws->companyProfile->CompanyName vì bảng company đã chuyển đi
            Notification::route('mail', $email)->notify(new WorkspaceInvitationNotification(
                $token, 
                $inviter->name ?? $inviter->email, 
                $ws->Name 
            ));
        } catch (Throwable $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => 'Mail failed', ['email' => $email, 'error' => $e->getMessage()]);
        }
    }

    public function joinWithCode(string $code, Recruiter $user): array
    {
        $invitation = WorkspaceInvitation::where('code', $code)->first();
        if (!$invitation) return $this->error('Invitation code not found.', 404);
        if ($invitation->expires_at && $invitation->expires_at->isPast()) return $this->error('Code expired.', 400);
        
        $workspace = Workspace::find($invitation->WorkspaceID);
        if (!$workspace) return $this->error('Workspace not found.', 404);

        $userId = $user->internal_id ?? $user->id;
        if ($workspace->members()->where('workspace_members.RecruiterID', $userId)->exists()) {
            return $this->error('Already a member.', 409);
        }

        try {
            $defaultPermissions = SystemRole::MEMBER->getPermissions();
            $this->assignMember($workspace, $user, $defaultPermissions, WorkspaceMemberStatus::ACTIVE);

            // Gán permission giả để Resource trả về
            $workspace->permissions = $defaultPermissions;

            // Không load 'companyProfile' vì bảng đã xóa
            return [
                'success'   => true, 
                'message'   => 'Joined workspace successfully!',
                'workspace' => $workspace, 
                'code'      => 200
            ];
        } catch (Throwable $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => '[JoinCode] Error', ['msg' => $e->getMessage()]);
            return $this->error('System error.', 500);
        }
    }

    public function acceptInvitation(string $token, Recruiter $user): array
    {
        $invitation = WorkspaceInvitation::where('token', $token)->first();
        if (!$invitation) return $this->error('Invalid token.');
        if ($invitation->expires_at?->isPast()) return $this->error('Expired link.');
        if (strtolower($invitation->email) !== strtolower($user->email)) return $this->error('Wrong email.');

        $ws = Workspace::find($invitation->WorkspaceID);
        if (!$ws) return $this->error('Workspace missing.');

        return $this->transaction(function () use ($ws, $user, $invitation) {
            $this->assignMember($ws, $user, $invitation->permissions, WorkspaceMemberStatus::ACTIVE);
            $invitation->delete();
            
            $ws->permissions = $invitation->permissions;
            return ['message' => 'Joined successfully!', 'workspace' => $ws];
        }, 'Accept failed', true);
    }

    public function updateMembersPermissions(Workspace $workspace, Recruiter $actionBy, array $membersData): array
    {
        return $this->transaction(function () use ($workspace, $actionBy, $membersData) {
            foreach ($membersData as $member) {
                $recruiterId = $member['recruiter_id'];
                $perms = $this->resolvePermissions($member);
                $sanitizedPerms = $this->sanitizePerms($perms);

                $workspace->members()->updateExistingPivot(
                    $recruiterId, 
                    array_merge($this->flattenPerms($sanitizedPerms), ['updated_at' => now()])
                );
            }
            return 'Members updated.';
        }, 'Update failed');
    }

    // --- HELPERS ---
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
        $userId = $user->internal_id ?? $user->id;

        $ws->members()->syncWithoutDetaching([
            $userId => array_merge($this->flattenPerms($p), [
                'status_id' => $status->value ?? $status,
                'created_at' => now(),
                'updated_at' => now()
            ])
        ]);
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
            (new StructuredLogger('system', 'error'))->error(['message' => $errorMsg, ['error' => $e->getMessage()]);
            return ['success' => false, 'message' => $errorMsg, 'code' => 500];
        }
    }

    private function error(string $msg, int $code = 400): array { return ['success' => false, 'message' => $msg, 'code' => $code]; }
    private function success(string $msg): array { return ['success' => true, 'message' => $msg]; }
}