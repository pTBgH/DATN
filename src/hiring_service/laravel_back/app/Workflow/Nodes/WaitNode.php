<?php

namespace App\Workflow\Nodes;

use Carbon\Carbon;

class WaitNode implements WorkflowNodeInterface
{
    public function getType(): string
    {
        return 'action.wait';
    }

    public function execute(array $context, array $parameters): array
    {
        $hours = (int) ($parameters['duration'] ?? 24); // Mặc định 24h
        
        // Tính thời gian đánh thức
        $wakeUpTime = Carbon::now()->addHours($hours);

        // Trả về một mảng đặc biệt để Engine nhận biết
        return [
            '__signal' => 'wait',
            'wait_until' => $wakeUpTime->toDateTimeString(),
            'message' => "Waiting for {$hours} hours"
        ];
    }
}