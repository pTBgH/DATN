<?php

namespace App\Services\Workspace;

use App\Models\Recruiter\Recruiter;
use App\Models\Job\JobSubJd;
use App\Models\Permission\JobPermissionOverride;
use App\Enums\JobPermission;
use App\Enums\WorkspacePermission;
use App\Enums\CandidatePermission;
use App\Enums\PipelinePermission;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Contracts\Auth\Authenticatable;

class PermissionService
{
    public function check(Authenticatable $user, string $targetWorkspaceId, $permission, $object = null): bool
    {
        $adminWorkspaceId = config('services.admin_workspace.id');
        $isSystemPermission = $this->isSystemPermission($permission);

        if ($isSystemPermission) {
            if (!$adminWorkspaceId) return false; // Chưa cấu hình Admin WS

            $adminPerms = $this->getWorkspacePermissions($user->RecruiterID, $adminWorkspaceId);
            if (!$adminPerms) return false; // User không nằm trong Admin WS

            return $this->checkBitmask($adminPerms, $permission, $object, $user);
        }

        if ($adminWorkspaceId) {
            $adminPerms = $this->getWorkspacePermissions($user->RecruiterID, $adminWorkspaceId);
            
            // Giả sử WorkspacePermission có case OVERRIDE_PERMISSIONS (bit 128 hoặc tùy bạn định nghĩa)
            if ($adminPerms && defined(WorkspacePermission::class . '::OVERRIDE_PERMISSIONS')) {
                $godModeBit = constant(WorkspacePermission::class . '::OVERRIDE_PERMISSIONS')->value;
                if (($adminPerms['workspace_permissions'] & $godModeBit) === $godModeBit) {
                    return true; // Cho phép tất cả hành động
                }
            }
        }

        $targetPerms = $this->getWorkspacePermissions($user->RecruiterID, $targetWorkspaceId);
        
        if (!$targetPerms) return false; // Không phải thành viên của workspace đích

        return $this->checkBitmask($targetPerms, $permission, $object, $user);
    }

    private function checkBitmask(array $perms, $permission, $object, $user): bool
    {
        $permissionValue = $permission->value;

        if ($permission instanceof JobPermission) {
            $mask = $perms['job_permissions'];

            if ($object instanceof JobSubJd) {
                $override = JobPermissionOverride::where('job_id', $object->JobID)
                    ->where('recruiter_id', $user->RecruiterID)
                    ->first();
                
                if ($override) {
                    $mask = $override->job_permissions;
                }
            }
            return ($mask & $permissionValue) === $permissionValue;
        }

        if ($permission instanceof WorkspacePermission) {
            return ($perms['workspace_permissions'] & $permissionValue) === $permissionValue;
        }

        if ($permission instanceof CandidatePermission) {
            return ($perms['candidate_permissions'] & $permissionValue) === $permissionValue;
        }

        if ($permission instanceof PipelinePermission) {
            return ($perms['pipeline_permissions'] & $permissionValue) === $permissionValue;
        }

        return false;
    }

    private function isSystemPermission($permission): bool
    {
        $enumClass = get_class($permission);
        
        if (method_exists($enumClass, 'systemCases')) {
            $systemCases = $enumClass::systemCases();
            foreach ($systemCases as $case) {
                if ($permission === $case) return true;
            }
        }
        return false;
    }

    private function getWorkspacePermissions(string $userId, string $workspaceId): ?array
    {
        $key = "perms:v2:{$workspaceId}:{$userId}";

        return Cache::remember($key, 3600, function () use ($userId, $workspaceId) {
            $member = DB::table('workspace_members')
                ->where('WorkspaceID', $workspaceId)
                ->where('RecruiterID', $userId)
                ->where('status_id', 1)
                ->first();

            if (!$member) return null;

            return [
                'workspace_permissions' => (int)$member->workspace_permissions,
                'job_permissions'       => (int)$member->job_permissions,
                'candidate_permissions' => (int)$member->candidate_permissions,
                'pipeline_permissions'  => (int)$member->pipeline_permissions,
            ];
        });
    }

    public function clearCache(string $userId, string $workspaceId): void
    {
        Cache::forget("perms:v2:{$workspaceId}:{$userId}");
    }

    public function getAllDefinitions(): array
    {
        return [
            'workspace' => $this->formatEnum(WorkspacePermission::class),
            'job'       => $this->formatEnum(JobPermission::class),
            'candidate' => $this->formatEnum(CandidatePermission::class),
            'pipeline'  => $this->formatEnum(PipelinePermission::class),
        ];
    }

    private function formatEnum(string $enumClass): array
    {
        $systemValues = [];
        if (method_exists($enumClass, 'systemCases')) {
            $systemValues = array_map(fn($c) => $c->value, $enumClass::systemCases());
        }

        $result = [];
        foreach ($enumClass::cases() as $case) {
            $result[] = [
                'key'   => $case->name,
                'value' => $case->value,
                'label' => $this->humanize($case->name),
                'is_system' => in_array($case->value, $systemValues),
            ];
        }
        return $result;
    }

    private function humanize(string $name): string
    {
        return ucwords(str_replace('_', ' ', strtolower($name)));
    }    
}