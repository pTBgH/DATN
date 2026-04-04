<?php

namespace App\Http\Controllers\Workspace;

use App\Http\Controllers\Controller;
use App\Services\Workspace\PermissionService;
use App\Enums\SystemRole;
use Illuminate\Http\JsonResponse;

class PermissionController extends Controller
{
    protected PermissionService $permissionService;

    public function __construct(PermissionService $permissionService)
    {
        $this->permissionService = $permissionService;
    }

    public function index(): JsonResponse
    {
        return response()->json([
            // 1. Danh sách chi tiết các quyền (để vẽ checkbox nếu chọn Custom)
            'permissions' => $this->permissionService->getAllDefinitions(),
            
            // 2. Danh sách Roles (để vẽ Dropdown chọn nhanh)
            'roles' => SystemRole::getDefinitions(), 
        ]);
    }
}