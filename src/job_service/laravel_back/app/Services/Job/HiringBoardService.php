<?php

namespace App\Services\Job;

use App\Models\Job\JobSubJd;
use App\Models\Recruiter\Recruiter;
use App\Models\Hiring\HiringPipeline;
use App\Models\Job\JobApplication;
use App\Models\Hiring\PipelineStage;
use App\Http\Resources\Hiring\CandidateCardResource;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\DB;
use Throwable;

class HiringBoardService
{
    public function getBoardData(JobSubJd $job, Recruiter $recruiter): array
    {
        $jobId = $job->JobID;
        try {
            // Logic tìm Pipeline: Ưu tiên pipeline của Job -> Fallback về Default của Workspace
            $pipeline = $job->pipeline;
            if (!$pipeline) {
                // job->companyInfo->WorkspaceID giả định là có quan hệ này
                // Nếu chưa có, có thể lấy qua recruiter->workspaces()->first()
                $workspaceId = $job->companyInfo->WorkspaceID ?? $recruiter->workspaces()->first()?->WorkspaceID;
                
                if (!$workspaceId) throw new \Exception("Cannot determine workspace for this job.");

                $pipeline = HiringPipeline::where('WorkspaceID', $workspaceId)
                                          ->where('IsDefault', true)->first();
                
                if (!$pipeline) return ['success' => false, 'message' => 'Default pipeline not found.'];
            }

            $stages = $pipeline->stages()->get();
            $applications = JobApplication::where('JobID', $jobId)->with('cv')->get();
            $applicationsByStage = $applications->groupBy('StageID');

            $formattedStages = $stages->map(function ($stage) use ($applicationsByStage) {
                return [
                    'stageId' => $stage->StageID,
                    'name' => $stage->Name,
                    'order' => $stage->StageOrder,
                    'color' => $stage->Color,
                    'isSystemStage' => $stage->IsSystemStage,
                    'candidates' => CandidateCardResource::collection($applicationsByStage->get($stage->StageID, collect())),
                ];
            });

            return [
                'success' => true,
                'data' => [
                    'jobTitle' => $job->Title,
                    'pipelineId' => $pipeline->PipelineID,
                    'stages' => $formattedStages
                ]
            ];
        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Get Board Error', ['error' => $e->getMessage()]);
            return ['success' => false, 'message' => 'Internal Server Error'];
        }
    }

    public function moveApplicationToStage(JobApplication $application, string $newStageId, Recruiter $recruiter): array
    {
        try {
            $newStage = PipelineStage::findOrFail($newStageId);
            $currentStage = $application->stage;

            // Chặn di chuyển nếu đang ở Hired/Rejected
            if ($currentStage && $currentStage->IsSystemStage && in_array($currentStage->Name, ['Hired', 'Rejected'])) {
                return ['success' => false, 'message' => 'Cannot move finalized application.', 'status_code' => 403];
            }

            // Tìm pipeline để validate
            $job = $application->job;
            $pipeline = $job->pipeline ?? $application->workspace->defaultPipeline;

            if (!$pipeline || $newStage->PipelineID !== $pipeline->PipelineID) {
                return ['success' => false, 'message' => 'Invalid stage for this job.', 'status_code' => 422];
            }

            DB::transaction(function() use ($application, $newStageId) {
                $application->StageID = $newStageId;
                $application->save();
            });

            return ['success' => true, 'message' => 'Moved successfully.'];
        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Move App Error', ['error' => $e->getMessage()]);
            return ['success' => false, 'message' => 'Internal Server Error'];
        }
    }
}