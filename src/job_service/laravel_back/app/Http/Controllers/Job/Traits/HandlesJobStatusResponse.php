<?php

namespace App\Http\Controllers\Job\Traits;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

trait HandlesJobStatusResponse
{
    private function handleAction(string $action, \Closure $serviceCall): JsonResponse
    {
        try {
            $result = $serviceCall();
            
            Log::channel('daily_normal')->info("Job status action '{$action}' executed successfully.", [
                'job_id' => $result['job']->job_id ?? null, // Sử dụng snake_case
                'new_status_code' => $result['job']->status_code ?? null, // Sử dụng snake_case
                'message' => $result['message'],
            ]);
            
            return $this->buildSuccessResponse($result);

        } catch (\Throwable $e) {
            Log::channel('daily_error')->error("Exception in JobStatusController@{$action}", [
                'error_message' => $e->getMessage(), 'stack_trace' => $e->getTraceAsString(),
            ]);
            return response()->json(['error' => 'An unexpected server error occurred. Please try again later.'], 500);
        }
    }

    private function buildSuccessResponse(array $result): JsonResponse
    {
        if (!$result['success']) {
            return response()->json(['message' => $result['message']], $result['code'] ?? 400);
        }
        
        return response()->json($result['job']);
    }
}