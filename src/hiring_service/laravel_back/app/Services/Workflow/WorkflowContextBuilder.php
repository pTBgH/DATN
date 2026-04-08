<?php

namespace App\Services\Workflow;

use App\Models\Job\JobApplication;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class WorkflowContextBuilder
{
    /**
     * Xây dựng context đầy đủ cho sự kiện chuyển vòng
     */
    public function buildForStageMove(JobApplication $application, string $newStageName, string $actorId): array
    {
        Log::info("[ContextBuilder] Building context for AppID: {$application->ApplicationID}");

        // 1. Dữ liệu cơ bản có sẵn trong Hiring DB
        $context = [
            'application_id' => $application->ApplicationID,
            'job_id'         => $application->JobID,
            'stage_id'       => $application->StageID,
            'stage_name'     => $newStageName,
            'actor_id'       => $actorId, // Recruiter ID
            'timestamp'      => now()->toIso8601String(),
        ];

        // 2. Enrich: Lấy thông tin Ứng viên (Từ Identity Service)
        // ApplicantID là ID nội bộ (UUID)
        $candidateInfo = $this->fetchCandidateInfo($application->ApplicantID);
        $context['candidate_email'] = $candidateInfo['email'] ?? null;
        $context['candidate_name']  = $candidateInfo['name'] ?? 'Ứng viên';

        // 3. Enrich: Lấy thông tin Job (Từ Job Service)
        $jobInfo = $this->fetchJobInfo($application->JobID);
        $context['job_title']    = $jobInfo['title'] ?? 'Công việc';
        $context['company_name'] = $jobInfo['company_name'] ?? 'Công ty';

        Log::info("[ContextBuilder] Context built successfully.", ['keys' => array_keys($context)]);

        return $context;
    }

    private function fetchCandidateInfo(string $userId): array
    {
        try {
            $url = config('services.microservices.identity');
            // Gọi API Internal lấy chi tiết user
            $fullUrl = "{$url}/api/internal/users/{$userId}";
            
            Log::info("[ContextBuilder] Calling Identity: {$fullUrl}");

            $response = Http::timeout(2)->get($fullUrl);
            
            if ($response->successful()) {
                return $response->json();
            }
            
            Log::warning("[ContextBuilder] Fetch Candidate Failed: " . $response->status());
        } catch (\Exception $e) {
            Log::error("[ContextBuilder] Fetch Candidate Exception: " . $e->getMessage());
        }
        return [];
    }

    private function fetchJobInfo(string $jobId): array
    {
        try {
            $url = config('services.microservices.job');
            // Gọi API Public Job để lấy cả snapshot company
            $fullUrl = "{$url}/api/public/jobs/{$jobId}";

            $response = Http::timeout(2)->get($fullUrl);
            
            if ($response->successful()) {
                $data = $response->json();
                return [
                    'title' => $data['title'] ?? $data['Title'] ?? null,
                    'company_name' => $data['company_name'] ?? $data['CompanyNameSnapshot'] ?? null
                ];
            }
            
            Log::warning("[ContextBuilder] Fetch Job Failed: " . $response->status());
        } catch (\Exception $e) {
            Log::error("[ContextBuilder] Fetch Job Exception: " . $e->getMessage());
        }
        return [];
    }
}