<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AuthenticateInternalApi
{
    public function handle(Request $request, Closure $next)
    {
        $secret = $request->header('X-Internal-API-Secret');
        
        if (!$secret || $secret !== config('services.nextjs.internal_api_secret')) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }
        
        return $next($request);
    }
}