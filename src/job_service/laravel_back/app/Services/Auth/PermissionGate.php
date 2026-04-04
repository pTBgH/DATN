<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class PermissionGate
{
    /**
     * Check quyền của User trong Workspace.
     * Logic: Check Redis -> Nếu thiếu thì gọi Workspace Service -> Lưu Cache.
     */
    public function check(string $workspaceId, string $userId, int $requiredBit): bool
    {
        // Key Cache: perms:{workspace_id}:{user_id}
        $cacheKey = "perms:{$workspaceId}:{$userId}";

        $perms = Cache::remember($cacheKey, 300, function () use ($workspaceId, $userId) {
            // URL gọi sang Workspace Service (Internal)
            $url = config('services.microservices.workspace') . "/api/internal/permissions/{$workspaceId}/{$userId}";
            
            try {
                $response = Http::timeout(2)->get($url);
                if ($response->successful()) {
                    return $response->json(); // Trả về ['job' => 123, 'workspace' => 456...]
                }
            } catch (\Exception $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "PermissionGate Error: " . $e->getMessage()]);
            }
            return null;
        });

        if (!$perms) return false;

        // Lấy quyền Job (bitmask) và so sánh
        $userJobPerm = $perms['job'] ?? 0;
        return ($userJobPerm & $requiredBit) === $requiredBit;
    }
}