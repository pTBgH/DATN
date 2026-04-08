<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use App\Services\Workspace\PermissionService;
use App\Enums\WorkspacePermission;
use App\Enums\JobPermission;
use App\Enums\CandidatePermission; // Đảm bảo đã tạo Enum này
use App\Enums\PipelinePermission;  // Đảm bảo đã tạo Enum này

class CheckPermission
{
    protected PermissionService $permissionService;

    public function __construct(PermissionService $permissionService)
    {
        $this->permissionService = $permissionService;
    }

    public function handle(Request $request, Closure $next, ...$permissions)
    {
        $recruiter = Auth::user();

        // 1. Lấy WorkspaceID từ route parameter
        // Route: /workspaces/{workspace}/...
        $workspaceParam = $request->route('workspace');
        $workspaceId = null;

        if (is_string($workspaceParam)) {
            $workspaceId = $workspaceParam;
        } elseif (is_object($workspaceParam)) {
            // Trường hợp Laravel Model Binding
            $workspaceId = $workspaceParam->WorkspaceID ?? $workspaceParam->id;
        }

        if (!$recruiter || !$workspaceId) {
            // Log::warning("CheckPermission: Missing context.", ['user' => $recruiter ? $recruiter->id : 'null', 'ws' => $workspaceId]);
            return response()->json(['message' => 'Unauthorized context.'], 403);
        }

        // 2. Check danh sách quyền yêu cầu
        foreach ($permissions as $permissionName) {
            // Tìm xem quyền này thuộc Enum nào
            $enum = $this->resolveEnum($permissionName);
            
            if ($enum) {
                // Gọi Service (đã viết ở câu trả lời trước) để check cột tương ứng
                if ($this->permissionService->check($recruiter, $workspaceId, $enum)) {
                    return $next($request);
                }
            } else {
                Log::error("CheckPermission: Unknown permission name '{$permissionName}' in route.");
            }
        }

        return response()->json(['message' => 'You do not have permission to perform this action.'], 403);
    }

    private function resolveEnum(string $name)
    {
        // Danh sách Enum hệ thống hỗ trợ
        $classes = [
            WorkspacePermission::class,
            JobPermission::class,
            CandidatePermission::class, // Nếu chưa có file Enum này, hãy comment tạm
            PipelinePermission::class,  // Nếu chưa có file Enum này, hãy comment tạm
        ];

        foreach ($classes as $class) {
            if (defined("$class::$name")) {
                // Lấy giá trị int
                $val = constant("$class::$name")->value;
                // Trả về Enum case object
                return $class::tryFrom($val);
            }
        }
        return null;
    }
}