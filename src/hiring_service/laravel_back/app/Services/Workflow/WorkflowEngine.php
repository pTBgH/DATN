<?php

namespace App\Services\Workflow;

use App\Models\Hiring\HiringPipeline;
use App\Models\Hiring\HiringExecution;
use App\Workflow\NodeRegistry;
use App\Services\Workflow\ExpressionResolver;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Str;

class WorkflowEngine
{
    protected NodeRegistry $registry;
    protected ExpressionResolver $resolver;

    public function __construct(NodeRegistry $registry, ExpressionResolver $resolver)
    {
        $this->registry = $registry;
        $this->resolver = $resolver;
    }

    public function trigger(string $pipelineId, string $triggerEvent, array $contextData)
    {
        (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow] Trigger signal received. Event: {$triggerEvent}, Pipeline: {$pipelineId}");

        $pipeline = HiringPipeline::find($pipelineId);
        
        if (!$pipeline || empty($pipeline->WorkflowConfig)) {
            (new StructuredLogger('system', 'error'))->error(['message' => "[Workflow] Pipeline not found in DB.");
            return;
        }

        $config = $pipeline->WorkflowConfig; 
        if (is_string($config)) {
            $config = json_decode($config, true);
        }

        if (empty($config)) {
            (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow] No workflow config found.");
            return;
        }

        $nodes = collect($config['nodes'] ?? []);
        $connections = $config['connections'] ?? [];

        // Tìm Node Trigger
        $startNode = $nodes->first(function ($node) use ($triggerEvent, $contextData) {
            $isTrigger = ($node['type'] === 'trigger.stage_entry');
            $configStageId = $node['parameters']['stage_id'] ?? '';
            $currentStageId = $contextData['stage_id'] ?? '';
            return $isTrigger && ($configStageId === $currentStageId);
        });

        if (!$startNode) {
            (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow] No matching trigger node found.");
            return;
        }

        (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow] Starting execution from Node: " . $startNode['id']);

        $execution = HiringExecution::create([
            'ExecutionID' => Str::uuid(),
            'PipelineID' => $pipelineId,
            'ApplicationID' => $contextData['application_id'] ?? 'Unknown',
            'TriggerNodeID' => $startNode['id'],
            'Status' => 'running',
            'ExecutionData' => ['initial' => $contextData],
            'Logs' => [],
            'StartedAt' => now()
        ]);

        $this->runNode($startNode, $contextData, $nodes, $connections, $execution);
    }

    private function runNode($currentNode, $contextData, $allNodes, $connections, $execution)
    {
        $nodeId = $currentNode['id'];
        $nodeType = $currentNode['type'];
        
        $startTime = microtime(true);
        (new StructuredLogger('system', 'action'))->info(['message' => "  -> Processing Node: {$nodeType} [{$nodeId}]");

        $execution->update(['CurrentNode' => $nodeId]);

        // 1. Resolver
        $rawParams = $currentNode['parameters'] ?? [];
        $resolvedParams = $this->resolver->resolve($rawParams, $contextData);

        $nodeOutput = [];
        $nodeError = null;

        // 2. Thực thi Node
        if ($nodeType !== 'trigger.stage_entry') {
            $handler = $this->registry->get($nodeType);
            if ($handler) {
                try {
                    $nodeOutput = $handler->execute($contextData, $resolvedParams);

                    // --- [MỚI] XỬ LÝ TÍN HIỆU WAIT ---
                    if (isset($nodeOutput['__signal']) && $nodeOutput['__signal'] === 'wait') {
                        (new StructuredLogger('system', 'action'))->info(['message' => "  -> Workflow PAUSED. Waiting until: " . $nodeOutput['wait_until']);
                        
                        // Lưu trạng thái ngủ đông
                        $execution->update([
                            'Status' => 'waiting',
                            'WaitUntil' => $nodeOutput['wait_until'],
                            // Lưu context mới nhất để khi dậy thì chạy tiếp với data này
                            'ExecutionData' => array_merge($execution->ExecutionData ?? [], ['latest' => $contextData]) 
                        ]);
                        
                        return; // <--- DỪNG HÀM NGAY LẬP TỨC (Không chạy node sau)
                    }
                    // ---------------------------------

                } catch (\Exception $e) {
                    $nodeError = $e->getMessage();
                    (new StructuredLogger('system', 'error'))->error(['message' => "  -> Node Failed: " . $nodeError);
                }
            } else {
                $nodeError = "Handler not found: {$nodeType}";
            }
        } else {
            $nodeOutput = $contextData;
        }

        // 3. Ghi Log
        $durationMs = round((microtime(true) - $startTime) * 1000, 2);
        
        $logEntry = [
            'node_id' => $nodeId,
            'type' => $nodeType,
            'status' => $nodeError ? 'failed' : 'success',
            'duration_ms' => $durationMs,
            'input' => $contextData,
            'output' => $nodeOutput,
            'error' => $nodeError,
            'timestamp' => now()->toIso8601String()
        ];

        $currentLogs = $execution->Logs ?? [];
        $currentLogs[] = $logEntry;
        
        if ($nodeError) {
            $execution->update(['Status' => 'failed', 'Logs' => $currentLogs]);
            return;
        }
        $execution->update(['Logs' => $currentLogs]);

        // 4. Data Passing
        $nextContext = array_merge($contextData, $nodeOutput);

        // 5. Gọi hàm tìm node tiếp theo (Đã tách ra)
        $this->triggerNextNodes($nodeId, $nextContext, $allNodes, $connections, $execution);
    }

    /**
     * [MỚI] Hàm Helper để tìm và chạy các node tiếp theo
     * Được tách ra để hàm resume() có thể dùng lại logic này
     */
    private function triggerNextNodes($currentNodeId, $contextData, $allNodes, $connections, $execution)
    {
        $nextConnGroups = $connections[$currentNodeId]['main'] ?? [];
        $hasNext = false;

        foreach ($nextConnGroups as $group) {
            foreach ($group as $conn) {
                $nextNodeId = $conn['node'];
                $nextNode = $allNodes->firstWhere('id', $nextNodeId);
                
                if ($nextNode) {
                    $hasNext = true;
                    // Đệ quy chạy tiếp
                    $this->runNode($nextNode, $contextData, $allNodes, $connections, $execution);
                }
            }
        }

        // Nếu không còn node nào nối tiếp -> Kết thúc
        if (!$hasNext) {
            $execution->update(['Status' => 'completed', 'FinishedAt' => now()]);
            (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow] Execution Completed.");
        }
    }

    /**
     * Hàm đánh thức quy trình (Gọi từ Cronjob)
     */
    public function resume(string $executionId)
    {
        $execution = HiringExecution::find($executionId);
        if (!$execution || $execution->Status !== 'waiting') return;

        (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow] Resuming Execution: {$executionId}");

        // Lấy lại config
        $pipeline = HiringPipeline::find($execution->PipelineID);
        $config = $pipeline->WorkflowConfig;
        if (is_string($config)) $config = json_decode($config, true);
        
        $allNodes = collect($config['nodes'] ?? []);
        $connections = $config['connections'] ?? [];

        // Khôi phục trạng thái
        $currentNodeId = $execution->CurrentNode; // Node Wait vừa chạy xong
        // Lấy context dữ liệu tại thời điểm dừng
        $contextData = $execution->ExecutionData['latest'] ?? $execution->ExecutionData['initial'];

        // Cập nhật trạng thái chạy lại
        $execution->update(['Status' => 'running', 'WaitUntil' => null]);

        // Tìm node SAU node Wait và chạy
        $this->triggerNextNodes($currentNodeId, $contextData, $allNodes, $connections, $execution);
    }
}