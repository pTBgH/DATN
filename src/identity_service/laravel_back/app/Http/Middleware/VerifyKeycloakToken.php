<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Models\Recruiter\Recruiter;
use App\Models\User; // <--- Import Model Candidate mới
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use Firebase\JWT\JWT;
use Firebase\JWT\JWK;

class VerifyKeycloakToken
{
    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();
        if (!$token) return response()->json(['message' => 'Token missing'], 401);

        try {
            // 1. Lấy JWKS & Verify Chữ ký
            // TEMP: Hardcode Keycloak URL to test OAuth2 flow (env vars not accessible in Laravel middleware)
            $baseUrl = 'http://keycloak.security.svc.cluster.local:8080';
            $realm = 'job7189';
            $jwksUrl = $baseUrl . "/realms/" . $realm . "/protocol/openid-connect/certs";
            
            Log::info("JWT verification starting", [
                'jwks_url' => $jwksUrl,
                'token_len' => strlen($token)
            ]);
            
            $jwks = null;
            try {
                $jwks = Cache::remember('jwks_identity', 3600, function () use ($jwksUrl) {
                    Log::info("Fetching JWKS from: " . $jwksUrl);
                    try {
                        $response = Http::withOptions(['verify' => false])->get($jwksUrl);
                        Log::info("JWKS fetch response status: " . $response->status());
                        return $response->json();
                    } catch (\Exception $e) {
                        Log::error("JWKS fetch failed: " . $e->getMessage(), ['class' => get_class($e)]);
                        throw $e;
                    }
                });
            } catch (\Exception $cacheError) {
                Log::warning("Cache failed, fetching JWKS directly: " . $cacheError->getMessage());
                // Fall back to direct fetch if cache fails
                $response = Http::withOptions(['verify' => false])->get($jwksUrl);
                $jwks = $response->json();
            }

            Log::info("JWKS retrieved, attempting decode");
            $decoded = JWT::decode($token, JWK::parseKeySet($jwks));
            
            $sub = $decoded->sub; // Keycloak ID
            $azp = $decoded->azp ?? ''; // Client ID

            // Lấy thông tin chung từ Token
            $email = $decoded->email ?? null;
            $givenName = $decoded->given_name ?? '';
            $familyName = $decoded->family_name ?? '';
            $fullName = $decoded->name ?? ($givenName . ' ' . $familyName);
            $username = $fullName;

            // 2. Lấy Config Client ID
            $recruiterClient = config('services.keycloak.clients.recruiter');
            $candidateClient = config('services.keycloak.clients.candidate');

            $user = null;

            // 3. PHÂN LOẠI & SYNC DỮ LIỆU
            if ($azp === $recruiterClient) {
                $recruiter = Recruiter::firstOrCreate(
                    ['KeycloakUserID' => $sub],
                    [
                        'Email' => $email,
                        'UserName' => $username,
                        'FirstName' => $givenName,
                        'LastName' => $familyName,
                        'StatusID' => 1,
                    ]
                );

                if ($recruiter->StatusID != 1) {
                    return response()->json(['message' => 'Account Locked'], 403);
                }
                
                $user = $recruiter; 
                $user->type = 'recruiter';

            } elseif ($azp === $candidateClient) {
                $candidate = User::firstOrCreate(
                    ['KeycloakUserID' => $sub],
                    [
                        'Email'     => $email,
                        'UserName'  => $fullName,
                        'FirstName' => $givenName,
                        'LastName'  => $familyName,
                    ]
                );

                $user = $candidate;
                $user->type = 'candidate';
                
            } else {
                Log::warning("Unknown AZP in Identity: $azp");
                return response()->json(['message' => 'Unauthorized Client'], 401);
            }

            Auth::setUser($user);

            return $next($request);

        } catch (\Exception $e) {
            Log::error("Identity Auth Failed: " . $e->getMessage(), [
                'exception_class' => get_class($e),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'token_received' => !empty($token),
            ]);
            return response()->json(['message' => 'Unauthorized: ' . $e->getMessage()], 401);
        }
    }
}