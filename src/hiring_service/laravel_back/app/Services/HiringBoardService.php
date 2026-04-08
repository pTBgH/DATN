<?php

namespace App\Services;

use App\Models\Hiring\HiringPipeline;
use App\Models\Job\JobApplication;
use App\Models\Hiring\PipelineStage;
use App\Http\Resources\Hiring\CandidateCardResource;
use App\Http\Resources\Hiring\ApplicationDetailResource;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Illuminate\Contracts\Auth\Authenticatable;
use App\Services\Kafka\KafkaHelper;
use App\Services\Workflow\WorkflowEngine;
use App\Services\Workflow\WorkflowContextBuilder;
use Throwable;

class HiringBoardService
{
    protected KafkaHelper $kafka;
    protected WorkflowEngine $workflowEngine;
    protected WorkflowContextBuilder $contextBuilder;

    public function __construct(WorkflowEngine $workflowEngine, WorkflowContextBuilder $contextBuilder, KafkaHelper $kafka)
    {
        $this->workflowEngine = $workflowEngine;
        $this->contextBuilder = $contextBuilder;
        $this->kafka = $kafka;
    }

    public function getBoardData(string $jobId, string $workspaceId, Authenticatable $recruiter): array
    {
        try {
            // 1. Xác định Pipeline (Ưu tiên Default nếu Job chưa gắn PipelineID)
            $pipeline = HiringPipeline::where('WorkspaceID', $workspaceId)
                                      ->where('IsDefault', true)
                                      ->first();

            if (!$pipeline) {
                $pipeline = HiringPipeline::where('WorkspaceID', $workspaceId)->first();
            }

            if (!$pipeline) {
                return ['success' => false, 'message' => 'No pipeline found for this workspace.'];
            }

            // 2. Lấy Stages
            $stages = $pipeline->stages()->orderBy('StageOrder')->get();

            // 3. Lấy Applications
            // QUAN TRỌNG: Lấy trực tiếp từ bảng job_applications.
            // Vì đã có cột Snapshot (Name, CvUrl...) nên không cần join hay gọi API đi đâu cả.
            $applications = JobApplication::where('JobID', $jobId)
                                          ->orderBy('AppliedAt', 'desc')
                                          ->get();

            // Group ứng viên theo Stage để hiển thị cột Kanban
            $applicationsByStage = $applications->groupBy('StageID');

            $formattedStages = $stages->map(function ($stage) use ($applicationsByStage) {
                return [
                    'stage_id' => $stage->StageID,
                    'name' => $stage->Name,
                    'order' => $stage->StageOrder,
                    'color' => $stage->Color,
                    'is_system_stage' => (bool)$stage->IsSystemStage,
                    
                    // Resource này sẽ map các trường Name, Email từ snapshot
                    'candidates' => CandidateCardResource::collection(
                        $applicationsByStage->get($stage->StageID, collect())
                    ),
                ];
            });

            return [
                'success' => true,
                'data' => [
                    'job_id' => $jobId,
                    'pipeline_id' => $pipeline->PipelineID,
                    'stages' => $formattedStages
                ]
            ];
        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Get Board Error', ['error' => $e->getMessage()]);
            return ['success' => false, 'message' => 'Internal Server Error'];
        }
    }

    public function moveApplicationToStage(string $applicationId, string $newStageId, Authenticatable $recruiter): array
    {
        try {
            $application = JobApplication::findOrFail($applicationId);
            $newStage = PipelineStage::findOrFail($newStageId);
            
            // 1. Transaction Update DB
            DB::transaction(function() use ($application, $newStageId) {
                $application->StageID = $newStageId;
                $application->save();
            });

            Log::info("Application moved to Stage: " . $newStage->Name);

            // 2. Trigger Workflow Automation (Logic giữ nguyên)
            try {
                $context = $this->contextBuilder->buildForStageMove(
                    $application, 
                    $newStage->Name, 
                    $recruiter->getAuthIdentifier()
                );

                $pipelineId = $newStage->PipelineID;
                $this->workflowEngine->trigger($pipelineId, 'stage_entry', $context);

            } catch (\Exception $e) {
                Log::error("Workflow Trigger Failed: " . $e->getMessage());
            }

            return ['success' => true, 'message' => 'Moved successfully.'];

        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Move App Error', ['error' => $e->getMessage()]);
            return ['success' => false, 'message' => 'Internal Server Error'];
        }
    }

    public function getApplicationDetail(string $applicationId): array
    {
        // QUAN TRỌNG: Không dùng with('cv') hay gọi HTTP nữa
        $app = JobApplication::with(['stage'])->find($applicationId);
        
        if (!$app) {
            return ['success' => false, 'message' => 'Not found'];
        }

        // Dữ liệu chi tiết lấy thẳng từ Snapshot trong DB
        // Resource sẽ chịu trách nhiệm format dữ liệu này
        return ['success' => true, 'data' => new ApplicationDetailResource($app)];
    }
}