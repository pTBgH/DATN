<?php

namespace App\Http\Controllers\Workspace;

use App\Http\Controllers\Controller;
use App\Enums\WorkspacePermission;
use App\Http\Resources\WorkspaceResource; // Import Resource
use App\Models\Workspace;
use App\Services\Workspace\PermissionService;
use App\Services\Workspace\WorkspaceService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Throwable;

class WorkspaceController extends Controller
{
    protected WorkspaceService $workspaceService;
    protected PermissionService $permissionService;

    public function __construct(WorkspaceService $workspaceService, PermissionService $permissionService)
    {
        $this->workspaceService = $workspaceService;
        $this->permissionService = $permissionService;
    }

    public function index(Request $request): JsonResponse
    {
        $recruiter = Auth::user();
        $workspaces = $this->workspaceService->getWorkspacesFor($recruiter);

        // Sử dụng Resource Collection để trả về snake_case
        return WorkspaceResource::collection($workspaces)->response();
    }

    public function store(Request $request)
    {
        try {
            // 1. Validate
            // Lưu ý: Không dùng 'exists' DB check cho size/industry vì bảng đó ở Job Service
            $validatedData = $request->validate([
                'name'        => 'required|string|max:255',
                'email'       => 'required|email|max:255',
                'location'    => 'nullable|string|max:255',
                'size'        => 'nullable|integer', 
                'industry'    => 'nullable|integer',
                'city'        => 'nullable|integer',
                'district'    => 'nullable|integer',
                'logo'        => 'nullable|string',
                'website'     => 'nullable|string',
            ]);
            
            $user = Auth::user();
            if (!$user) return response()->json(['message' => 'Unauthorized'], 401);

            // 2. Gọi Service
            $workspace = $this->workspaceService->createNewWorkspace($validatedData, $user);

            // 3. Trả về Resource
            return new WorkspaceResource($workspace);

        } catch (Throwable $e) {
            Log::error('Create WS Error', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Failed to create workspace.', 'debug' => $e->getMessage()], 500);
        }
    }

    public function show(Workspace $workspace): JsonResponse
    {
        if (!$this->permissionService->check(Auth::user(), $workspace->WorkspaceID, WorkspacePermission::VIEW_SETTINGS)) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $recruiter = Auth::user();
        $workspaceDetails = $this->workspaceService->getWorkspaceDetails($workspace, $recruiter);

        return response()->json(new WorkspaceResource($workspaceDetails));
    }

    public function update(Request $request, Workspace $workspace)
    {
        if (!$this->permissionService->check(Auth::user(), $workspace->WorkspaceID, WorkspacePermission::UPDATE_INFO)) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        try {
            $validatedData = $request->validate([
                'name'        => 'sometimes|required|string|max:255',
                'logo'        => 'nullable|string',
                'location'    => 'nullable|string',
                'size'     => 'nullable|integer',
                'city'     => 'nullable|integer',
                'district' => 'nullable|integer',
                'industry' => 'nullable|integer',
                'website'     => 'nullable|string',
            ]);

            $updatedWorkspace = $this->workspaceService->updateWorkspace($workspace, $validatedData);
            
            return new WorkspaceResource($updatedWorkspace);

        } catch (Throwable $e) {
            Log::error('Update WS Error', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Failed to update workspace.'], 500);
        }
    }

    public function destroy(Workspace $workspace): JsonResponse
    {
        if (!$this->permissionService->check(Auth::user(), $workspace->WorkspaceID, WorkspacePermission::DELETE_WORKSPACE)) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        try {
            $this->workspaceService->deleteWorkspace($workspace);
            return response()->json(['message' => 'Workspace deleted successfully.'], 200);
        } catch (Throwable $e) {
            return response()->json(['message' => 'Failed to delete workspace.'], 500);
        }
    }
}