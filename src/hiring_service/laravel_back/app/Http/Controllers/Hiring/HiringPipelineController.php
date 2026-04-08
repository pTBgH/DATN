<?php

namespace App\Http\Controllers\Hiring;

use App\Http\Controllers\Controller;
use App\Models\Hiring\HiringPipeline;
use App\Http\Resources\Hiring\HiringPipelineResource;
use App\Services\Kafka\KafkaHelper; 
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

use Throwable;

class HiringPipelineController extends Controller
{
    protected KafkaHelper $kafka;
    public function __construct(KafkaHelper $kafka)
    {
        $this->kafka = $kafka;
    }
    public function index(string $workspaceId)
    {
        $pipelines = HiringPipeline::where('WorkspaceID', $workspaceId)
            ->with(['stages' => function ($query) {
                $query->orderBy('StageOrder', 'asc');
            }])
            ->get();

        return HiringPipelineResource::collection($pipelines);
    }
  
    public function show(string $workspaceId, string $pipelineId)
    {
        $pipeline = HiringPipeline::where('PipelineID', $pipelineId)
            ->where('WorkspaceID', $workspaceId)
            ->with(['stages' => function ($query) {
                $query->orderBy('StageOrder', 'asc');
            }])
            ->first();

        if (!$pipeline) {
            return response()->json(['message' => 'Pipeline not found.'], 404);
        }
        
        return new HiringPipelineResource($pipeline);
    }

    public function store(Request $request, string $workspaceId)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'stages' => 'required|array|min:1',
            'stages.*.name' => 'required|string|max:100',
            'stages.*.color' => 'nullable|string|max:7',
        ]);

        try {
            $pipeline = DB::transaction(function () use ($workspaceId, $validated) {
                $newPipeline = HiringPipeline::create([
                    'WorkspaceID' => $workspaceId,
                    'Name' => $validated['name'],
                    'IsDefault' => false
                ]);
                
                $stageData = [];
                foreach ($validated['stages'] as $index => $stage) {
                    $stageData[] = [
                        'Name' => $stage['name'],
                        'Color' => $stage['color'] ?? '#FFFFFF',
                        'StageOrder' => $index + 1,
                        'IsSystemStage' => false
                    ];
                }
                
                $orderOffset = count($stageData);
                $stageData[] = ['Name' => 'Hired', 'Color' => '#DFF0D8', 'StageOrder' => $orderOffset + 1, 'IsSystemStage' => true];
                $stageData[] = ['Name' => 'Rejected', 'Color' => '#F2DEDE', 'StageOrder' => $orderOffset + 2, 'IsSystemStage' => true];

                $newPipeline->stages()->createMany($stageData);

                return $newPipeline;
            });

            try {
                $this->kafka->produce('job7189.pipeline', [
                    'event_type' => 'pipeline.created',
                    'timestamp'  => now()->toIso8601String(),
                    'data' => [
                        'pipeline_id'  => $pipeline->PipelineID,
                        'workspace_id' => $pipeline->WorkspaceID,
                        'name'         => $pipeline->Name,
                        'is_default'   => (bool) $pipeline->IsDefault,
                    ]
                ]);
            } catch (Throwable $k) {
                Log::error("Kafka Produce Error (Pipeline Created): " . $k->getMessage());
            }
            // Trả về Resource
            return response()->json(new HiringPipelineResource($pipeline->load('stages')), 201);

        } catch (Throwable $e) {
            Log::error('Create Pipeline Failed', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Internal Server Error'], 500);
        }
    }

    public function update(Request $request, string $workspaceId, string $pipelineId)
    {
        $pipeline = HiringPipeline::where('PipelineID', $pipelineId)
            ->where('WorkspaceID', $workspaceId)
            ->first();

        if (!$pipeline) return response()->json(['message' => 'Not found'], 404);
        
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'stages' => 'required|array',
            'stages.*.name' => 'required|string|max:100',
            'stages.*.color' => 'nullable|string|max:7',
        ]);

        try {
            DB::transaction(function () use ($pipeline, $validated) {
                $pipeline->update(['Name' => $validated['name']]);
                $pipeline->stages()->where('IsSystemStage', false)->delete();
                
                $stageData = [];
                foreach ($validated['stages'] as $index => $stage) {
                    $stageData[] = [
                        'Name' => $stage['name'],
                        'Color' => $stage['color'] ?? '#FFFFFF',
                        'StageOrder' => $index + 1,
                        'IsSystemStage' => false
                    ];
                }
                $pipeline->stages()->createMany($stageData);

                $orderOffset = count($validated['stages']);
                $pipeline->stages()->where('Name', 'Hired')->update(['StageOrder' => $orderOffset + 1]);
                $pipeline->stages()->where('Name', 'Rejected')->update(['StageOrder' => $orderOffset + 2]);
            });

            try {
                $this->kafka->produce('job7189.pipeline', [
                    'event_type' => 'pipeline.updated',
                    'timestamp'  => now()->toIso8601String(),
                    'data' => [
                        'pipeline_id'  => $pipeline->PipelineID,
                        'workspace_id' => $pipeline->WorkspaceID,
                        'name'         => $pipeline->Name,
                        'is_default'   => (bool) $pipeline->IsDefault,
                    ]
                ]);
            } catch (Throwable $k) {
                Log::error("Kafka Produce Error (Pipeline Updated): " . $k->getMessage());
            }

            // Trả về Resource
            return new HiringPipelineResource($pipeline->load('stages'));

        } catch(Throwable $e) {
            Log::channel('daily_error')->error('Update Pipeline Failed', ['error' => $e->getMessage()]);
            return response()->json(['message' => 'Internal Server Error', 'error' => $e], 500);
        }
    }

    public function destroy(string $workspaceId, string $pipelineId)
    {
        $pipeline = HiringPipeline::where('PipelineID', $pipelineId)
            ->where('WorkspaceID', $workspaceId)
            ->first();

        if (!$pipeline) {
            return response()->json(['message' => 'Pipeline not found.'], 404);
        }
        if ($pipeline->IsDefault) {
            return response()->json(['message' => 'Cannot delete the default pipeline.'], 400);
        }
        
        // Kiểm tra xem có Job nào đang dùng Pipeline này không?
        // (Trong Hiring Service, cần check bảng job_applications hoặc bảng jobs nội bộ)
        // Ví dụ: Check xem có application nào đang gắn với pipeline này ko
        // $hasApps = $pipeline->stages()->whereHas('applications')->exists(); 
        
        // Tạm thời xóa mềm hoặc xóa cứng tùy logic
        $pipeline->delete();

                try {
            $this->kafka->produce('job7189.pipeline', [
                'event_type' => 'pipeline.deleted',
                'timestamp'  => now()->toIso8601String(),
                'data' => [
                    'pipeline_id' => $pipelineId,
                    'workspace_id' => $workspaceId
                ]
            ]);
        } catch (Throwable $k) {
            Log::error("Kafka Produce Error (Pipeline Deleted): " . $k->getMessage());
        }
        
        return response()->json(null, 204);
    }
}