<?php

namespace App\Http\Controllers\Recruiter;

use App\Http\Controllers\Controller;
use App\Services\Recruiter\RecruiterService;
use App\Http\Resources\RecruiterResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\Http;  // <--- Bắt buộc có
use Illuminate\Support\Facades\Cache; // <--- Bắt buộc có
use App\Services\Kafka\KafkaHelper;

class RecruiterController extends Controller
{
    private $recruiterService;
    protected KafkaHelper $kafka;

    public function __construct(RecruiterService $recruiterService, KafkaHelper $kafka)
    {
        $this->recruiterService = $recruiterService;
        $this->kafka = $kafka;
    }

    // --- CÁC HÀM STORE/UPDATE GIỮ NGUYÊN ---
    public function store(Request $request)
    {
        $recruiter = $request->user();
        $validatedData = $request->validate([
            'company_id' => 'nullable|string|max:64',
        ]);
        $recruiter->update($validatedData);
        Cache::forget("profile:full:{$recruiter->RecruiterID}");
        return new RecruiterResource($recruiter);
    }

    public function update(Request $request)
    {
        $recruiter = Auth::user();
        $validatedData = $request->validate([
            'user_name' => 'sometimes|nullable|string|max:255',
            'phone_number' => 'sometimes|nullable|string|max:20',
            'first_name' => 'sometimes|nullable|string|max:100',
            'last_name' => 'sometimes|nullable|string|max:100',
        ]);
        
        $updatedRecruiter = $this->recruiterService->updateProfile($recruiter, $validatedData);
        
        try {
            $this->kafka->produce('job7189.identity', [
                'event_type' => 'user.updated',
                'timestamp'  => microtime(true),
                'data' => [
                    'id'          => $updatedRecruiter->RecruiterID,
                    'keycloak_id' => $updatedRecruiter->KeycloakUserID,
                    'email'       => $updatedRecruiter->Email,
                    'name'        => $updatedRecruiter->UserName,
                    'type'        => 'recruiter'
                ]
            ]);
        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Kafka Update Failed: " . $e->getMessage());
        }
        Cache::forget("profile:full:{$recruiter->RecruiterID}");
        
        return new RecruiterResource($updatedRecruiter);
    }

    // --- HÀM NÀY SỬA LẠI ĐỂ KHÔNG QUERY DB WORKSPACE ---
    public function getMyProfile()
    {
        $recruiter = Auth::user();
        $userId = $recruiter->RecruiterID;
        
        // Key cache cho profile
        $cacheKey = "profile:full:{$userId}";

        // Cache 5 phút
        $data = Cache::remember($cacheKey, 20, function () use ($recruiter, $userId) {
            
            // 1. Mặc định workspace là rỗng (Fail-safe)
            $workspaces = [];

            try {
                // 2. Gọi sang Workspace Service để lấy dữ liệu
                // Đảm bảo bạn đã cấu hình biến môi trường WORKSPACE_SERVICE_URL
                $wsUrl = config('services.microservices.workspace'); 
                $url = "{$wsUrl}/api/internal/workspaces/by-user/{$userId}";
                
                // Timeout cực ngắn (1s) để nếu Workspace Service chết thì trang Profile vẫn load được
                $response = Http::timeout(1)->get($url);
                
                if ($response->successful()) {
                    $workspaces = $response->json();
                } else {
                    // Log nhẹ để biết, không throw lỗi ra ngoài
                    (new StructuredLogger('system', 'warning'))->warning(['message' => "Cannot fetch workspaces. Status: " . $response->status());
                }
            } catch (\Exception $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Workspace Service Unreachable: " . $e->getMessage());
                // Vẫn giữ $workspaces = [] để code chạy tiếp
            }

            // 3. Trả về cấu trúc JSON thủ công 
            // (Không dùng RecruiterResource cũ vì nó có ->load() gây lỗi)
            return [
                'recruiter_id' => $recruiter->RecruiterID,
                'email'        => $recruiter->Email,
                'phone_number' => $recruiter->PhoneNumber,
                'user_name'    => $recruiter->UserName,
                'first_name'   => $recruiter->FirstName,
                'last_name'    => $recruiter->LastName,
                'avatar'       => $recruiter->AvatarUrl ?? null,
                'status_id'    => $recruiter->StatusID,
                
                // Dữ liệu từ Service khác
                'workspaces'   => $workspaces 
            ];
        });

        return response()->json($data);
    }
}