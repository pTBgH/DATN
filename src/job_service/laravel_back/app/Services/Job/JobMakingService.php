<?php

namespace App\Services\Job;

use App\Http\Controllers\Job\Traits\JobValidationRules;
use App\Models\Job\JobSubJd;
use App\Services\Job\JobVersioningService;
use App\Enums\JobStatusEnum;
use Illuminate\Support\Facades\Log;
use Illuminate\Contracts\Auth\Authenticatable; 
use Throwable;

class JobMakingService
{
    use JobValidationRules;

    private JobService $jobService;
    private JobVersioningService $versioningService;

    public function __construct(JobService $jobService, JobVersioningService $versioningService)
    {
        $this->jobService = $jobService;
        $this->versioningService = $versioningService;
    }

    /**
     * Hàm nội bộ dùng chung để tạo Job
     */
    private function createJob(array $data, Authenticatable $recruiter, string $wsId, JobStatusEnum $status): JobSubJd
    {
        try {
            $payload = $this->jobService->mapRequestToDbFields($data);

            // --- ÉP CỨNG ID TỪ URL (Bảo mật) ---
            $payload['CompanyID'] = $wsId; 
            $payload['status'] = $status;
            
            if (!empty($data['pipeline_id'])) {
                $payload['PipelineID'] = $data['pipeline_id'];
            }

            $creatorId = $recruiter->getAuthIdentifier();

            // 1. Tạo Job
            $job = JobSubJd::create($payload);

            // 2. Versioning
            $job->Version = 1;
            $job->save();

            // 3. Snapshot ban đầu
            $originalData = $job->toArray();
            $originalData['OpenDate'] = isset($originalData['OpenDate']) 
                ? \Carbon\Carbon::parse($originalData['OpenDate'])->format('Y-m-d') 
                : now()->format('Y-m-d');

            $originalData['EndDate'] = isset($originalData['EndDate']) 
                ? \Carbon\Carbon::parse($originalData['EndDate'])->format('Y-m-d') 
                : null;

            $this->versioningService->createInitialSnapshot($job->JobID, $originalData, $recruiter);

            Log::channel('daily_normal')->info('Job created successfully.', [
                'job_id' => $job->JobID, 
                'status' => $status->name,
                'creator_id' => $creatorId,
                'workspace_id' => $wsId
            ]);

            return $job;

        } catch (Throwable $e) {

            $errorPayload = [
                'workspace_id' => $wsId,
                'status' => $status->name,
                'payload' => $payload ?? null,
                'exception' => get_class($e),
                'error' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString()
            ];

            Log::channel('daily_error')->error('Job Create Failed', $errorPayload);

            // 🔥 BẮN THẲNG LỖI RA CONTROLLER
            throw new \Exception(
                'Job creation failed: ' . $e->getMessage(),
                500
            );
        }
    }

    // ================= PUBLIC METHODS =================

    public function createDraftJob(array $data, Authenticatable $recruiter, string $wsId): JobSubJd
    {
        return $this->createJob($data, $recruiter, $wsId, JobStatusEnum::DRAFT);
    }

    public function createAndSubmitJob(array $data, Authenticatable $recruiter, string $wsId): JobSubJd
    {
        return $this->createJob($data, $recruiter, $wsId, JobStatusEnum::PENDING);
    }

    public function createManualJob(array $data, Authenticatable $recruiter, string $wsId): JobSubJd
    {
        return $this->createDraftJob($data, $recruiter, $wsId);
    }
}
