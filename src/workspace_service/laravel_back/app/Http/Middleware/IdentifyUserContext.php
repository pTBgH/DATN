<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Auth\GenericUser;
use App\Models\ServiceUser; // <--- Model mới
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


class IdentifyUserContext
{
    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();
        if (!$token) return response()->json(['message' => 'Token missing'], 401);

        // 1. Decode Token (Offline)
        $tokenParts = explode('.', $token);
        $payload = json_decode(base64_decode($tokenParts[1]), true);
        $keycloakId = $payload['sub'] ?? null;
        $azp = $payload['azp'] ?? '';

        if (!$keycloakId) return response()->json(['message' => 'Invalid Token'], 401);

        // 2. Phân loại User (Logic cũ)
        $recruiterClient = config('services.keycloak.clients.recruiter');
        $candidateClient = config('services.keycloak.clients.candidate');
        $userType = ($azp === $recruiterClient) ? 'recruiter' : (($azp === $candidateClient) ? 'candidate' : 'unknown');

        if ($userType === 'unknown') return response()->json(['message' => 'Unauthorized Client'], 401);

        // 3. TÌM TRONG DB CỤC BỘ (Không gọi HTTP, không gọi Redis)
        $localUser = ServiceUser::where('keycloak_id', $keycloakId)->first();

        // 4. LAZY SYNC (Nếu chưa có trong DB cục bộ mới gọi Identity)
        if (!$localUser) {
            $localUser = $this->fetchAndSyncFromIdentity($keycloakId, $userType, $payload);
        }

        if (!$localUser) {
            return response()->json(['message' => 'User identity not found'], 403);
        }

        // 5. Set Auth
        $user = new GenericUser([
            'id' => $localUser->internal_id,
            'RecruiterID' => ($userType === 'recruiter') ? $localUser->internal_id : null,
            'UserID'      => ($userType === 'candidate') ? $localUser->internal_id : null,
            'email' => $localUser->email,
            'name' => $localUser->name,
            'type' => $localUser->type
        ]);

        Auth::setUser($user);

        return $next($request);
    }

    private function fetchAndSyncFromIdentity($keycloakId, $userType, $payload)
    {
        try {
            $identityUrl = config('services.microservices.identity');
            
            // Gọi sang Identity (Chỉ chạy 1 lần duy nhất trong đời user)
            $response = Http::timeout(2)->post("{$identityUrl}/api/internal/auth/sync-user", [
                'keycloak_id' => $keycloakId,
                'type'        => $userType,
                'email'       => $payload['email'] ?? null,
                'name'        => $payload['name'] ?? 'User',
            ]);

            if ($response->successful()) {
                $data = $response->json();
                
                // LƯU VÀO DB CỤC BỘ CỦA JOB SERVICE
                return ServiceUser::create([
                    'internal_id' => $data['id'],
                    'keycloak_id' => $keycloakId,
                    'email'       => $data['email'],
                    'name'        => $data['name'],
                    'type'        => $userType
                ]);
            }
        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Identity Sync Failed: " . $e->getMessage());
        }
        return null;
    }
}