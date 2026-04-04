<?php

namespace App\Http\Controllers\Job;

use App\Http\Controllers\Controller;
use App\Http\Resources\JobSubJdResource;
use App\Services\Job\JobStatusServicev2;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class JobStatusController extends Controller
{
    protected JobStatusServicev2 $jobStatusService;

    public function __construct(JobStatusServicev2 $jobStatusService)
    {
        $this->jobStatusService = $jobStatusService;
    }

    private function respond(array $result): JsonResponse
    {
        if (!$result['success']) {
            return response()->json(['message' => $result['message']], $result['code'] ?? 400);
        }
        return response()->json([
            'message' => $result['message'],
            'job'     => new JobSubJdResource($result['job'])
        ]);
    }

    // --- USER ACTIONS ---

    public function submit(string $workspaceId, string $jobId): JsonResponse
    {
        return $this->respond($this->jobStatusService->submit($jobId, $workspaceId));
    }

    public function unpublish(string $workspaceId, string $jobId): JsonResponse
    {
        return $this->respond($this->jobStatusService->unpublish($jobId, $workspaceId));
    }

    public function archive(string $workspaceId, string $jobId): JsonResponse
    {
        return $this->respond($this->jobStatusService->archive($jobId, $workspaceId));
    }

    public function restore(string $workspaceId, string $jobId): JsonResponse
    {
        return $this->respond($this->jobStatusService->restore($jobId, $workspaceId));
    }

    // --- ADMIN ACTIONS ---

    public function approve(string $jobId): JsonResponse
    {
        return $this->respond($this->jobStatusService->approve($jobId));
    }

    public function reject(Request $request, string $jobId): JsonResponse
    {
        return $this->respond($this->jobStatusService->reject($jobId, $request->input('reason')));
    }
}
