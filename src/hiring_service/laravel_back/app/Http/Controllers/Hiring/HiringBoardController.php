<?php

namespace App\Http\Controllers\Hiring;

use App\Http\Controllers\Controller;
use App\Services\HiringBoardService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class HiringBoardController extends Controller
{
    protected HiringBoardService $boardService;

    public function __construct(HiringBoardService $boardService)
    {
        $this->boardService = $boardService;
    }

    public function getBoard(Request $request, string $jobId): JsonResponse
    {
        try {
            // 1. Gọi sang Job Service lấy thông tin (CompanyID/WorkspaceID)
            $jobInfo = $this->fetchJobInfo($jobId);

            if (!$jobInfo) {
                return response()->json(['message' => 'Job not found or Job Service unavailable.'], 404);
            }

            // Lấy company_id từ response của Job Service
            $workspaceId = $jobInfo['company_id'] ?? null;

            if (!$workspaceId) {
                return response()->json(['message' => 'Invalid Job Data (Missing company_id).'], 500);
            }
            
            // 2. Gọi Service lấy dữ liệu Board
            $result = $this->boardService->getBoardData($jobId, $workspaceId, Auth::user());

            if (!$result['success']) {
                return response()->json(['message' => $result['message']], 500);
            }

            return response()->json($result['data']);

        } catch (\Exception $e) {
            Log::error("HiringBoardController Error: " . $e->getMessage());
            return response()->json(['message' => 'Internal Server Error'], 500);
        }
    }

    public function moveApplication(Request $request, string $applicationId): JsonResponse
    {
        $validated = $request->validate([
            'new_stage_id' => 'required|string'
        ]);

        $result = $this->boardService->moveApplicationToStage(
            $applicationId, 
            $validated['new_stage_id'], 
            Auth::user()
        );

        if (!$result['success']) {
            return response()->json(['message' => $result['message']], $result['status_code'] ?? 500);
        }

        return response()->json($result);
    }

    public function showApplication(string $applicationId): JsonResponse
    {
        $result = $this->boardService->getApplicationDetail($applicationId);
        
        if (!$result['success']) {
            return response()->json(['message' => $result['message']], 404);
        }
        
        return response()->json($result['data']);
    }

    private function fetchJobInfo($jobId)
    {
        try {
            $baseUrl = config('services.microservices.job');
            if (empty($baseUrl)) {
                throw new \Exception("Job Service URL not configured in config/services.php");
            }

            $url = "{$baseUrl}/api/public/jobs/{$jobId}";
            
            $response = Http::timeout(5)->get($url);

            if ($response->successful()) {
                $data = $response->json();
                // Xử lý wrapper 'data' của Laravel Resource
                return isset($data['data']) ? $data['data'] : $data;
            }

            Log::warning("Fetch Job failed. Status: {$response->status()} - URL: {$url}");
            return null;

        } catch (\Exception $e) {
            Log::error("Fetch Job Info Exception: " . $e->getMessage());
            return null;
        }
    }
}