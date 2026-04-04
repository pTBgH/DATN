<?php

namespace App\Http\Controllers\Job;

use App\Http\Controllers\Controller;
use App\Http\Resources\JobSubJdResource;
use App\Services\Job\JobMakingService;
use App\Services\CompanyDataEnricher; // <--- Service bơm dữ liệu
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class JobMakingController extends Controller
{
    private JobMakingService $jobMakingService;
    private CompanyDataEnricher $enricher;

    public function __construct(
        JobMakingService $jobMakingService,
        CompanyDataEnricher $enricher
    ) {
        $this->jobMakingService = $jobMakingService;
        $this->enricher = $enricher;
    }

    // --- API: Lưu Nháp (DRAFT) ---
    // Quyền: CREATE_JOB
    public function saveDraft(Request $request, string $wsId): JsonResponse
    {        
        $validatedData = $request->validate($this->jobMakingService->validationRules());

        // Truyền $wsId vào Service
        $job = $this->jobMakingService->createDraftJob($validatedData, Auth::user(), $wsId);
        
        if ($job) {
            // Enrich dữ liệu công ty trước khi trả về
            $this->enricher->enrichOne($job);
            return response()->json(new JobSubJdResource($job), 201);
        }

        return response()->json(['message' => 'Failed.'], 500);
    }

    // --- API: Đăng và Gửi Duyệt (PENDING) ---
    // Quyền: CREATE_JOB (hoặc REQUEST_APPROVE_NEW)
    public function submitNewJob(Request $request, string $wsId): JsonResponse
    {
        $validatedData = $request->validate($this->jobMakingService->validationRules());

        // Gọi hàm tạo và submit
        $job = $this->jobMakingService->createAndSubmitJob($validatedData, Auth::user(), $wsId);
        
        if ($job) {
            // Bơm thông tin công ty
            $this->enricher->enrichOne($job);

            return response()->json(new JobSubJdResource($job), 201);
        }

        return response()->json(['message' => 'Failed to submit job.'], 500);
    }

    // --- API: Tạo Manual (Thường dùng cho tính năng nhập liệu thủ công đặc biệt) ---
    // Logic: Thường giống Draft nhưng có thể có xử lý riêng, ở đây ta map về draft
    public function createManualJob(Request $request, string $wsId): JsonResponse
    {
        $validatedData = $request->validate($this->jobMakingService->validationRules());

        $job = $this->jobMakingService->createManualJob($validatedData, Auth::user(), $wsId);
        
        if ($job) {
            $this->enricher->enrichOne($job);
            return response()->json(new JobSubJdResource($job), 201);
        }

        return response()->json(['message' => 'An internal error occurred while creating the job manually.'], 500);
    }
}