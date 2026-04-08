<?php

namespace App\Http\Controllers\Hiring;

use App\Http\Controllers\Controller;
use App\Models\Hiring\HiringPipeline;
use App\Workflow\NodeRegistry;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class WorkflowController extends Controller
{
    protected NodeRegistry $registry;

    public function __construct(NodeRegistry $registry)
    {
        $this->registry = $registry;
    }

    public function getDefinitions(string $workspaceId)
    {
        // Có thể check quyền workspace ở đây nếu cần thiết
        return response()->json($this->registry->getDefinitions());
    }

    public function getConfig(string $workspaceId, string $pipelineId)
    {
        try {
            $pipeline = HiringPipeline::where('PipelineID', $pipelineId)
                ->where('WorkspaceID', $workspaceId)
                ->firstOrFail();
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            Log::warning("Pipeline not found: {$pipelineId} in Workspace: {$workspaceId}");
            return response()->json(['error' => 'Pipeline not found'], 404);
        }

        return response()->json($pipeline->WorkflowConfig ?? ['nodes' => [], 'connections' => []]);
    }

    public function updateConfig(Request $request, string $workspaceId, string $pipelineId)
    {
        $pipeline = HiringPipeline::where('PipelineID', $pipelineId)
            ->where('WorkspaceID', $workspaceId)
            ->firstOrFail();

        // Validate sơ bộ cấu trúc JSON
        $data = $request->validate([
            'nodes' => 'required|array',
            'connections' => 'required|array',
            'settings' => 'nullable|array' // Timezone, error handling...
        ]);

        // TODO: Có thể validate kỹ hơn (ví dụ: check xem node type có tồn tại trong registry không)

        $pipeline->WorkflowConfig = $data;
        $pipeline->save();

        Log::info("Workflow updated for Pipeline {$pipelineId}");

        return response()->json([
            'message' => 'Workflow configuration saved successfully.',
            'config' => $pipeline->WorkflowConfig
        ]);
    }
}