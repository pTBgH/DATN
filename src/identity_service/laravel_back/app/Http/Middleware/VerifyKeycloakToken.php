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
            
            Log::info("[VerifyKeycloak-01] JWT verification starting", [
                'jwks_url' => $jwksUrl,
                'token_len' => strlen($token),
                'token_first_100' => substr($token, 0, 100)
            ]);
            
            $jwks = null;
            try {
                Log::info("[VerifyKeycloak-02] Attempting cache lookup");
                $jwks = Cache::remember('jwks_identity', 3600, function () use ($jwksUrl) {
                    Log::info("[VerifyKeycloak-03] Cache miss, fetching JWKS from: " . $jwksUrl);
                    try {
                        $response = Http::withOptions(['verify' => false])->get($jwksUrl);
                        Log::info("[VerifyKeycloak-04] JWKS fetch response status: " . $response->status());
                        return $response->json();
                    } catch (\Exception $e) {
                        Log::error("[VerifyKeycloak-ERR-A] JWKS fetch failed", [
                            'message' => $e->getMessage(),
                            'class' => get_class($e),
                            'file' => $e->getFile(),
                            'line' => $e->getLine()
                        ]);
                        throw $e;
                    }
                });
            } catch (\Exception $cacheError) {
                Log::warning("[VerifyKeycloak-05] Cache failed, fetching JWKS directly: " . $cacheError->getMessage());
                // Fall back to direct fetch if cache fails
                try {
                    $response = Http::withOptions(['verify' => false])->get($jwksUrl);
                    $jwks = $response->json();
                    Log::info("[VerifyKeycloak-06] Direct JWKS fetch succeeded");
                } catch (\Exception $directError) {
                    Log::error("[VerifyKeycloak-ERR-B] Direct JWKS fetch also failed", [
                        'message' => $directError->getMessage(),
                        'class' => get_class($directError)
                    ]);
                    throw $directError;
                }
            }

            Log::info("[VerifyKeycloak-07] JWKS retrieved, keys count: " . count($jwks['keys'] ?? []));
            Log::info("[VerifyKeycloak-08] Attempting JWT::decode");
            $decoded = JWT::decode($token, JWK::parseKeySet($jwks));
            
            Log::info("[VerifyKeycloak-09] JWT decoded successfully");
            $sub = $decoded->sub; // Keycloak ID
            $azp = $decoded->azp ?? ''; // Client ID
            Log::info("[VerifyKeycloak-10] Extracted claims", ['sub' => $sub, 'azp' => $azp]);

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
            Log::error("[VerifyKeycloak-ERROR] Auth Failed", [
                'exception_class' => get_class($e),
                'message' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace_snippet' => array_slice(explode("\n", $e->getTraceAsString()), 0, 5),
                'token_received' => !empty($token),
            ]);
            return response()->json(['message' => 'Unauthorized: ' . $e->getMessage()], 401);
        }
    }
}