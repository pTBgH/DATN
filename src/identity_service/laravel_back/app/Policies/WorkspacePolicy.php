<?php
namespace App\Policies;

use App\Enums\Permission;
use App\Models\Recruiter\Recruiter;
use App\Models\Workspace;
use Illuminate\Support\Facades\DB;

class WorkspacePolicy
{
    private function getPermissions(Recruiter $user, Workspace $workspace): int
    {
        $membership = DB::table('workspace_members')
            ->where('RecruiterID', $user->RecruiterID)
            ->where('WorkspaceID', $workspace->WorkspaceID)
            ->first(['permissions']);
            
        return $membership ? $membership->permissions : 0;
    }

    public function view(Recruiter $user, Workspace $workspace): bool
    {
        return $this->getPermissions($user, $workspace) > 0;
    }

    public function update(Recruiter $user, Workspace $workspace): bool
    {
        $permissions = $this->getPermissions($user, $workspace);
        return ($permissions & Permission::IS_ADMIN->value) === Permission::IS_ADMIN->value;
    }

    public function delete(Recruiter $user, Workspace $workspace): bool
    {
        return $this->update($user, $workspace);
    }
    
    public function viewJobs(Recruiter $user, Workspace $workspace): bool
    {
        $permissions = $this->getPermissions($user, $workspace);
        $required = Permission::CAN_VIEW_CANDIDATE->value;
        return ($permissions & $required) === $required || $this->update($user, $workspace); // Admin cũng được xem
    }
}