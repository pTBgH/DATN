<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Models\Recruiter\Recruiter;
use App\Models\User; // <--- Import Model Candidate mới
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


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
            $jwksUrl = rtrim(config('services.keycloak.base_url'), '/') . "/realms/" . config('services.keycloak.realm') . "/protocol/openid-connect/certs";
            
            $jwks = Cache::remember('jwks_identity', 3600, function () use ($jwksUrl) {
                return Http::withOptions(['verify' => false])->get($jwksUrl)->json();
            });

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
                (new StructuredLogger('system', 'warning'))->warning(['message' => "Unknown AZP in Identity: $azp"]);
                return response()->json(['message' => 'Unauthorized Client'], 401);
            }

            Auth::setUser($user);

            return $next($request);

        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Identity Auth Failed: " . $e->getMessage()]);
            return response()->json(['message' => 'Unauthorized'], 401);
        }
    }
}