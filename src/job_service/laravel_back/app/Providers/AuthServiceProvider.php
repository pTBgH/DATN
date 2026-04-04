<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Gate;
use App\Services\Auth\PermissionGate; // <--- DÙNG CÁI MỚI (REDIS)
use App\Enums\JobPermission;
use App\Enums\WorkspacePermission;

class AuthServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $permissionGate = app(PermissionGate::class);

        // --- 1. JOB GATES (Đã sửa cho Microservice) ---
        // Bỏ ép kiểu Recruiter, $user ở đây là GenericUser
        Gate::define('create-job', function ($user, string $workspaceId) {
            $gate = app(PermissionGate::class);
            // Lấy ID từ GenericUser
            $userId = $user->id ?? $user->RecruiterID;
            
            return $gate->check($workspaceId, $userId, JobPermission::CREATE_JOB->value);
        });

        Gate::define('update-job', function ($user, $job, string $workspaceId) {
            $gate = app(PermissionGate::class);
            $userId = $user->id ?? $user->RecruiterID;

            // Logic check quyền update...
            // Tạm thời check quyền chung UPDATE_JOB
            return $gate->check($workspaceId, $userId, JobPermission::UPDATE_JOB->value);
        });

        // --- 2. SUPER ADMIN & WORKSPACE GATES ---
        // Trong Job Service, chúng ta tạm thời return false hoặc bỏ qua logic này
        // vì Job Service không có dữ liệu để check Super Admin theo cách cũ (Join bảng).
        Gate::define('is-super-admin', function ($user) use ($permissionGate) {
            // Lấy ID cấu hình cứng của Admin Workspace
            $adminWsId = config('services.admin_workspace.id');
            
            if (!$adminWsId) return false;

            // Lấy ID user (GenericUser)
            $userId = $user->id ?? $user->RecruiterID;

            return $permissionGate->check($adminWsId, $userId, 1); 

        });


        Gate::define('manage-members', function ($user) {
            return false; // Job Service không quản lý member
        });
    }
}