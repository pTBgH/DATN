<?php

namespace App\Http\Controllers\Job\Traits;

use App\Http\Resources\JobSubJdResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



trait HandlesJobUpdate
{
    public function handleUpdate(Request $request, string $workspaceId, string $jobId): JsonResponse
    {
        try {
            $validatedData = $request->validate($this->validationRules());
            $updatedJob = $this->jobService->updateJob($jobId, $validatedData, Auth::user(), $workspaceId);
            
            if (!$updatedJob) {
                return response()->json(['message' => 'Job not found or unauthorized.'], 404);
            }

            return response()->json(new JobSubJdResource($updatedJob));

        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json(['errors' => $e->errors()], 422);
        
        } catch (\Throwable $e) {
            Log::channel('daily_normal')->warning('[JobUpdate] Blocked action.', [
                'job_id'  => $jobId,
                'user_id' => Auth::id(),
                'reason'  => $e->getMessage()
            ]);

            return response()->json(['message' => $e->getMessage()], 400); // Bad Request
        }
    }

    abstract protected function validationRules(): array;
}