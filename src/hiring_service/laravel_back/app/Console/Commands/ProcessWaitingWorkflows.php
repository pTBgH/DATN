<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Hiring\HiringExecution;
use App\Services\Workflow\WorkflowEngine;

class ProcessWaitingWorkflows extends Command
{
    protected $signature = 'workflow:process-waiting';
    protected $description = 'Wake up waiting workflows';

    public function handle(WorkflowEngine $engine)
    {
        try {
            // Log bắt đầu chạy để biết nó có sống không
            // $this->info("Checking waiting workflows..."); 

            $executions = HiringExecution::where('Status', 'waiting')
                ->where('WaitUntil', '<=', now())
                ->get();

            foreach ($executions as $exec) {
                $this->info("Waking up execution: {$exec->ExecutionID}");
                $engine->resume($exec->ExecutionID);
            }
        } catch (\Exception $e) {
            // Catch lỗi để không làm crash scheduler
            $this->error("Error: " . $e->getMessage());
            \Illuminate\Support\Facades\(new StructuredLogger('system', 'error'))->error(['message' => "Scheduler Error: " . $e->getMessage());
            return 1; // Return exit code 1
        }
        
        return 0; // Success
    }
}