<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth; // Sử dụng Facade cho gọn gàng
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Firebase\JWT\JWT;
use Firebase\JWT\JWK; 
use App\Models\Recruiter\Recruiter;

class AuthenticateOptional
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        if (!$token) {
            return $next($request);
        }

        $cacheKey = 'user_for_token:' . hash('sha256', $token);

        $user = cache()->remember($cacheKey, 60, function () use ($token, $request) {
            try {
                $realm = config('services.keycloak.realm');
                $baseUrl = rtrim(config('services.keycloak.base_url'), '/');
                $jwksUrl = "{$baseUrl}/realms/{$realm}/protocol/openid-connect/certs";

                $jwks = cache()->remember('keycloak_jwks_cache', 3600, function () use ($jwksUrl) {
                    $res = Http::get($jwksUrl);
                    if (!$res->successful()) {
                        throw new \Exception("Unable to fetch JWKS");
                    }
                    return $res->json();
                });

                $publicKeys = JWK::parseKeySet($jwks);
                $decoded = JWT::decode($token, $publicKeys);
                $sub = $decoded->sub ?? null;

                if (!$sub) {
                    return null;
                }

                return User::where('KeycloakUserID', $sub)->first();

            } catch (\Throwable $e) {
                Log::channel('daily_error')->error('Optional Auth: Token verification failed during cache population.', [
                    'error_message' => $e->getMessage(),
                ]);
                return null;
            }
        });
        
        if ($user) {
            Auth::setUser($user);
        }

        return $next($request);
    }
}