<?php

namespace App\Listeners;

use App\Enums\JobStatusEnum;
use App\Events\JobStateChanged;
use App\Models\Job\JobJd;
use App\Models\Job\JobSubJd;
use App\Models\Job\JobStat;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class JobPublishingListener
{
    public function handle(JobStateChanged $event): void
    {
        $jobSub = $event->jobSubJd; 

        Log::channel('daily_normal')->info('[Listener] Triggered', [
            'job_id' => $jobSub->JobID,
            'new_status' => $jobSub->status->name
        ]);

        try {
            if ($jobSub->status === JobStatusEnum::PUBLISHED) {
                $this->publish($jobSub);
            } 
            else {
                $this->unpublish($jobSub);
            }
        } catch (Throwable $e) {
            Log::channel('daily_error')->error('[Listener] FAILED', [
                'job_id' => $jobSub->JobID,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            throw $e;
        }
    }

    private function publish(JobSubJd $jobSub): void
    {
        $dataToSync = $this->transform($jobSub);

        JobJd::updateOrCreate(
            ['JobID' => $jobSub->JobID],
            $dataToSync
        );

        JobStat::firstOrCreate(
            ['job_id' => $jobSub->JobID]
        );

        Log::channel('daily_normal')->info('[Listener] Job published/updated successfully.', ['job_id' => $jobSub->JobID]);
    }

    private function unpublish(JobSubJd $jobSub): void
    {
        $deletedCount = JobJd::destroy($jobSub->JobID);

        if ($deletedCount > 0) {
            Log::channel('daily_normal')->info('[Listener] Job unpublished (deleted from job_jds).', [
                'job_id' => $jobSub->JobID
            ]);
        }
    }

    private function transform(JobSubJd $jobSub): array
    {
        $attributes = $jobSub->toArray();
        
        $excludeFields = [
            'status', 'CreatedAt', 'UpdatedAt', 'Version', 
            'PipelineID', 
            'job_stat', 'company_info', 'job_jd'
        ];

        foreach ($excludeFields as $field) {
            unset($attributes[$field]);
        }
    
        if (empty($attributes['slug'])) {
            $attributes['slug'] = Str::slug($jobSub->Title) . '-' . Str::random(6);
        }
        
        if ($jobSub->OpenDate) {
            $attributes['OpenDate'] = $jobSub->OpenDate->format('Y-m-d');
        }
        if ($jobSub->EndDate) {
            $attributes['EndDate'] = $jobSub->EndDate->format('Y-m-d');
        }

        $attributes['IsActive'] = true;

        return $attributes;
    }
}