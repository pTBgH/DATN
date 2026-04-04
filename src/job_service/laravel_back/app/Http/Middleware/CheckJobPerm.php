<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use App\Enums\JobPermission;

class CheckJobPerm
{
    public function handle(Request $request, Closure $next, string $permissionName)
    {
        // 1. Lấy User Object (để check type) thay vì chỉ lấy ID
        $user = Auth::user(); 
        
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        // --- ĐOẠN BẠN CẦN THÊM VÀO ĐÂY ---
        // Kiểm tra xem có phải Recruiter không. 
        // Nếu là Candidate (dù có token xịn) cũng chặn luôn.
        if (($user->type ?? '') !== 'recruiter') {
            return response()->json(['message' => 'Only recruiters can perform this action.'], 403);
        }
        // ---------------------------------

        $userId = $user->id; // Lấy ID từ object đã lấy
        $workspaceId = $request->route('wsId') ?? $request->route('workspace');

        if (!$workspaceId) {
            return response()->json(['message' => 'Workspace context missing'], 400);
        }

        // 2. Map tên quyền sang Bitmask
        try {
            $requiredBit = constant(JobPermission::class . '::' . $permissionName)->value;
        } catch (\Exception $e) {
            return response()->json(['message' => "Invalid Permission: $permissionName"], 500);
        }

        // 3. Hỏi Workspace Service (Cache 5 phút)
        $cacheKey = "perms:{$workspaceId}:{$userId}";
        $perms = Cache::remember($cacheKey, 300, function () use ($workspaceId, $userId) {
            try {
                $url = config('services.microservices.workspace') . "/api/internal/permissions/{$workspaceId}/{$userId}";
                $response = Http::timeout(2)->get($url);
                return $response->successful() ? $response->json() : ['job' => 0];
            } catch (\Exception $e) {
                return ['job' => 0];
            }
        });

        // 4. Check Bitmask
        $userJobPerm = $perms['job'] ?? 0;
        if (($userJobPerm & $requiredBit) !== $requiredBit) {
            return response()->json(['message' => 'Permission Denied'], 403);
        }

        return $next($request);
    }
}