<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Gate;
use App\Models\Recruiter\Recruiter;
use App\Models\Job\JobSubJd;
use App\Services\Workspace\PermissionService;
use App\Enums\JobPermission;
use App\Enums\WorkspacePermission;

class AuthServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // $this->registerPolicies(); // Bật nếu dùng Policies

        $permissionService = app(PermissionService::class);

        // --- 1. SUPER ADMIN GATE (Kiểm tra quyền truy cập Admin Panel) ---
        Gate::define('is-super-admin', function (Recruiter $user) {
            $adminId = config('services.admin_workspace.id');
            
            if (!$adminId) return false;

            // Kiểm tra user có nằm trong Workspace Admin và đang Active không
            // Chúng ta dùng cache hoặc query tối ưu ở đây thông qua relation
            return $user->workspaces()
                        ->where('workspaces.WorkspaceID', $adminId)
                        ->wherePivot('status_id', 1)
                        ->exists();
        });

        // --- 2. JOB GATES (Giữ nguyên) ---
        Gate::define('create-job', function (Recruiter $user, string $workspaceId) use ($permissionService) {
            return $permissionService->check($user, $workspaceId, JobPermission::CREATE_JOB);
        });

        Gate::define('update-job', function (Recruiter $user, $job, string $workspaceId) use ($permissionService) {
            $jobObject = ($job instanceof JobSubJd) ? $job : null;
            if ($permissionService->check($user, $workspaceId, JobPermission::UPDATE_ALL_JOBS)) return true;
            if ($jobObject) {
                return $permissionService->check($user, $workspaceId, JobPermission::UPDATE_THIS_JOB, $jobObject);
            }
            return false;
        });

        // --- 3. WORKSPACE GATES (Giữ nguyên) ---
        Gate::define('manage-members', function (Recruiter $user, string $workspaceId) use ($permissionService) {
            return $permissionService->check($user, $workspaceId, WorkspacePermission::MANAGE_MEMBERS);
        });
    }
}