<?php

namespace App\Http\Controllers\Job;

use App\Http\Controllers\Controller;
use App\Services\Job\JobService;
use App\Http\Resources\JobSubJdResource; // <--- Import Resource
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Throwable;

class JobHistoryController extends Controller
{
    public function __construct(protected JobService $jobService) {}

    public function rollback(string $workspaceId, string $jobId, Request $request): JsonResponse
    {
        try {
            $validated = $request->validate([
                'version' => 'required|integer|min:1'
            ]);

            $recruiter = Auth::user();

            Log::channel('daily_normal')->info('Rollback action triggered.', [
                'job_id' => $jobId,
                'target_version' => $validated['version'],
                'user_id' => $recruiter->RecruiterID,
                'workspace_id' => $workspaceId
            ]);

            $rolledBackJob = $this->jobService->rollbackJob(
                $jobId, 
                $validated['version'], 
                $recruiter,
                $workspaceId
            );

            if (!$rolledBackJob) {
                return response()->json([
                    'message' => 'Unable to rollback job. It may not exist in this workspace or the version is invalid.'
                ], 404);
            }

            return response()->json(new JobSubJdResource($rolledBackJob));

        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Rollback failed with exception.', [
                'job_id' => $jobId,
                'error' => $e->getMessage()
            ]);
            return response()->json(['message' => 'An unexpected error occurred during rollback.'], 500);
        }
    }
}