<?php

namespace App\Services\Recruiter;


use App\Models\RecruiterJobInteract;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class InteractionService
{
    private function updateJobInteraction(string $userId, string $jobId, array $data): UserJobInteract
    {
        try {
            $interaction = UserJobInteract::updateOrCreate(
                [
                    'UserID' => $userId,
                    'JobID'  => $jobId,
                ],
                $data
            );
            
            Log::channel('daily_normal')->info('User job interaction updated', array_merge([
                'user_id' => $userId,
                'job_id' => $jobId,
            ], $data));

            return $interaction;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Error updating user job interaction', [
                'error' => $e->getMessage(),
                'user_id' => $userId,
                'job_id' => $jobId,
                'data' => $data,
            ]);
            throw new \Exception('Error updating interaction status: ' . $e->getMessage());
        }
    }

    public function setJobSaved(string $userId, string $jobId, bool $isSaved): UserJobInteract
    {
        return $this->updateJobInteraction($userId, $jobId, ['IsSaved' => $isSaved]);
    }

    public function setJobHidden(string $userId, string $jobId, bool $isHidden): UserJobInteract
    {
        return $this->updateJobInteraction($userId, $jobId, ['IsHidden' => $isHidden]);
    }

    public function getSavedJobIds(string $userId): array
    {
        try {
            $savedJobIds = UserJobInteract::where('UserID', $userId)
                                          ->where('IsSaved', true)
                                          ->pluck('JobID')
                                          ->all();

            return $savedJobIds;

        } catch (\Exception $e) {
            Log::channel('daily_error')->error('Failed to get saved job IDs for user.', [
                'user_id' => $userId,
                'error' => $e->getMessage(),
            ]);
            return [];
        }
    }

}