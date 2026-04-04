<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class EnsureUserRole
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  $role  'recruiter' hoặc 'candidate'
     */
    public function handle(Request $request, Closure $next, string $role)
    {
        $user = Auth::user();

        // 1. Nếu chưa đăng nhập (đã bị IdentifyUserContext chặn trước rồi, nhưng check lại cho chắc)
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        // 2. Lấy type từ GenericUser (đã được IdentifyUserContext set)
        $userType = $user->type ?? 'unknown';

        // 3. So khớp cực gắt
        if ($userType !== $role) {
            return response()->json([
                'message' => "Access denied. This endpoint is for [{$role}] only.",
                'your_role' => $userType
            ], 403);
        }

        return $next($request);
    }
}