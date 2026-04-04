<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;
use App\Enums\SystemRole;

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
                'workspaces.Name as WorkspaceName', // Đổi alias cho khớp logic dưới
                'workspaces.Logo as WorkspaceLogo',
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

            return [
                'workspace_id' => $mem->WorkspaceID,
                'workspace_name'=> $mem->WorkspaceName ?? 'Unnamed Workspace',
                'workspace_logo'=> $mem->WorkspaceLogo,
                'role_label'   => $roleLabel,
                'permissions'  => $permissions,
                'status_id'    => (int) $mem->status_id,
                'joined_at'    => $mem->joined_at,
            ];
        });

        return response()->json($result);
    }
}