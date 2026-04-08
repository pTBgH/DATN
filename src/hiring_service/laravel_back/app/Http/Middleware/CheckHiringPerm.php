<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
// Nhớ copy Enum PipelinePermission sang Hiring Service
use App\Enums\PipelinePermission; 

class CheckHiringPerm
{
    public function handle(Request $request, Closure $next, string $permissionName)
    {
        $userId = Auth::id();
        
        // Lấy WorkspaceID từ URL (chỉ áp dụng cho các route có {workspaceId})
        $workspaceId = $request->route('workspaceId');

        if (!$userId || !$workspaceId) {
            // Nếu route không có workspaceId (ví dụ route /board/{jobId}), 
            // middleware này không dùng được, phải check trong Controller.
            return $next($request); 
        }

        try {
            $requiredBit = constant(PipelinePermission::class . '::' . $permissionName)->value;
        } catch (\Exception $e) {
            return response()->json(['message' => "Invalid Permission: $permissionName"], 500);
        }

        // Gọi Workspace Service để check quyền (Cache 5 phút)
        $cacheKey = "perms:{$workspaceId}:{$userId}";
        $perms = Cache::remember($cacheKey, 300, function () use ($workspaceId, $userId) {
            try {
                $url = config('services.microservices.workspace') . "/api/internal/permissions/{$workspaceId}/{$userId}";
                $response = Http::timeout(2)->get($url);
                return $response->successful() ? $response->json() : null;
            } catch (\Exception $e) {
                return null;
            }
        });

        // Hiring Service quan tâm đến 'pipeline_permissions'
        $userPerm = $perms['pipeline'] ?? 0;

        if (($userPerm & $requiredBit) !== $requiredBit) {
            return response()->json(['message' => 'Permission Denied'], 403);
        }

        return $next($request);
    }
}