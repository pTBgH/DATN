<?php

namespace App\Http\Middleware;

use App\Models\Recruiter\Recruiter; // Đảm bảo namespace của Model đúng
use Closure;
use Illuminate\Http\Request;
use Firebase\JWT\JWT;
use Firebase\JWT\JWK;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;

use Symfony\Component\HttpFoundation\Response;
use Firebase\JWT\ExpiredException; // Thêm exception này để bắt lỗi hết hạn
use Firebase\JWT\SignatureInvalidException;
use Firebase\JWT\BeforeValidException;use Illuminate\Support\Str; // Import Str để dùng uuid() nếu cần

class VerifyKeycloakToken
{
    public function handle(Request $request, Closure $next): Response
    {
        // Log::channel('daily_normal')->info('--- VerifyKeycloakToken Middleware Triggered ---');

        $rawToken = $request->bearerToken();

        if (!$rawToken) {
            return response()->json(['message' => 'Token not provided.'], 401);
        }

        $token = trim($rawToken);
        
        if (substr_count($token, '.') !== 2) {
            return response()->json(['message' => 'Invalid token format.'], 401);
        }

        try {
            $realm = config('services.keycloak.realm');
            $baseUrl = rtrim(config('services.keycloak.base_url'), '/');
            $jwksUrl = "{$baseUrl}/realms/{$realm}/protocol/openid-connect/certs";

            $jwks = cache()->remember('keycloak_jwks_cache_recruiter', 3600, function () use ($jwksUrl) {
                $res = Http::get($jwksUrl);
                $res->throw(); // Ném exception nếu có lỗi, gọn hơn
                return $res->json();
            });

            // Log::channel('daily_normal')->info('Fetched JWKS from Keycloak.', ['jwks_url' => $jwksUrl]);

            $publicKeys = JWK::parseKeySet($jwks);
            JWT::$leeway = 60;
            $decoded = JWT::decode($token, $publicKeys);
            
            Log::channel('daily_error')->info('EEEEEEEEEEEEEEEEEEEEEEE.', [
                'decoded' => $decoded,
                'token' => $token,
                'puclickey' => $publicKeys,
            ]);

            $sub = $decoded->sub ?? null;

            if (!$sub) {
                (new StructuredLogger('system', 'warning'))->warning(['message' => 'Middleware STOPPED: No "sub" claim in token.');
                return response()->json(['message' => 'Invalid token payload.'], 401);
            }
            $recruiter = Recruiter::firstOrCreate(
                [
                    'KeycloakUserID' => $sub // Điều kiện để tìm kiếm
                ],
                [
                    'StatusID' => 1, // Luôn bắt đầu với trạng thái "NEW"
                    'UserName' => $decoded->name ?? 'New Recruiter',
                    'FirstName' => $decoded->given_name ?? null,
                    'LastName' => $decoded->family_name ?? null,
                    'Email' => $decoded->email ?? null,
                ]
            );

            // Log::channel('daily_normal')->info('Recruiter looked up or created.', [
            //     'keycloak_sub' => $sub,
            //     'recruiter_id' => $recruiter->RecruiterID,
            //     'was_created' => $recruiter->wasRecentlyCreated,
            // ]);


            Auth::setUser($recruiter);

            // Log::channel('daily_normal')->info('Recruiter authenticated and set on request.', [
            //     'recruiter_id' => $recruiter->RecruiterID,
            // ]);

            return $next($request);

        } catch (ExpiredException $e) {
            // Bắt lỗi Token hết hạn riêng biệt
            Log::channel("daily_error")->warning('JWT Expired.', [
                'error' => $e->getMessage(),
                'ip' => $request->ip()
            ]);
            return response()->json(['message' => 'Token expired.'], 401);

        } catch (SignatureInvalidException $e) {
            // Bắt lỗi Chữ ký sai (có thể do dùng sai Realm hoặc Keycloak reset keys)
            Log::channel("daily_error")->error('JWT Signature Verification Failed.', [
                'error' => $e->getMessage(),
                'hint' => 'Check if Keycloak Realm keys match the cached keys.'
            ]);
            return response()->json(['message' => 'Invalid token signature.'], 401);

        } catch (BeforeValidException $e) {
            // Token chưa đến thời điểm hiệu lực
            Log::channel("daily_error")->warning('JWT Before Valid.', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Token not yet valid.'], 401);

        } catch (\Firebase\JWT\SignatureInvalidException $e) {
            Log::channel("daily_error")->error('JWT Signature Verification Failed.', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Invalid token signature.'], 401);
        } catch (\Throwable $e) {
            Log::channel("daily_error")->error('Middleware CRASHED: Unexpected error.', [
                'error_message' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(), // Lấy full trace khi có lỗi nghiêm trọng
            ]);
            return response()->json(['message' => 'Server error during authentication.'], 500);
        }
    }
}