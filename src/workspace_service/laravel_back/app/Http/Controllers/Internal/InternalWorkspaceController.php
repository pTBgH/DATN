<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;
use App\Enums\SystemRole;
use App\Enums\WorkspaceMemberStatus;

class InternalWorkspaceController extends Controller
{
    public function getUserWorkspaces($userId)
    {
        $memberships = DB::table('workspace_members')
            ->join('workspaces', 'workspace_members.WorkspaceID', '=', 'workspaces.WorkspaceID')
            ->where('workspace_members.RecruiterID', $userId)
            ->where('workspace_members.status_id', 1) // Active only
            ->select([
                'workspaces.WorkspaceID',
                'workspaces.Name as WorkspaceName',
                'workspaces.Logo as WorkspaceLogo',
                'workspaces.Email as WorkspaceEmail',
                'workspace_members.*',
                'workspace_members.created_at as joined_at'
            ])
            ->get();

        $result = $memberships->map(function ($mem) {
            $permissions = [
                'workspace' => (int) $mem->workspace_permissions,
                'job'       => (int) $mem->job_permissions,
                'candidate' => (int) $mem->candidate_permissions,
                'pipeline'  => (int) $mem->pipeline_permissions,
            ];
            
            $roleLabel = 'Member'; 
            if (class_exists(SystemRole::class) && method_exists(SystemRole::class, 'inferRoles')) {
                $roleInfo = SystemRole::inferRoles($permissions);
                $roleLabel = !empty($roleInfo['roles']) ? $roleInfo['roles'][0]->label() : 'Custom';
            }

            // Mức độ an toàn/khớp với kiểu WorkspaceMinimal của frontend:
            $statusLabel = 'Active';
            if (class_exists(WorkspaceMemberStatus::class)) {
                $statusEnum = WorkspaceMemberStatus::tryFrom((int)$mem->status_id);
                $statusLabel = $statusEnum ? $statusEnum->label() : 'Active';
            }

            $permissionList = [];
            if ($mem->workspace_permissions > 0) $permissionList[] = 'workspace';
            if ($mem->job_permissions > 0) $permissionList[] = 'job';
            if ($mem->candidate_permissions > 0) $permissionList[] = 'candidate';
            if ($mem->pipeline_permissions > 0) $permissionList[] = 'pipeline';
            if (empty($permissionList)) {
                $permissionList = ['member'];
            }

            return [
                'workspace_id'  => $mem->WorkspaceID,
                'email'         => $mem->WorkspaceEmail ?? '',
                'member_status' => $statusLabel,
                'permissions'   => $permissionList,
                'company' => [
                    'name'         => $mem->WorkspaceName ?? 'Unnamed Workspace',
                    'logo'         => $mem->WorkspaceLogo ?? null,
                    'active_jobs'  => 0,
                    'views'        => 0,
                    'applications' => 0,
                    'apply_rate'   => 0,
                ],
                'created_at'    => $mem->joined_at,
            ];
        });

        return response()->json($result);
    }
}