<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\Kafka\KafkaHelper;
use App\Models\Job\JobPipeline;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class ConsumePipelineEvents extends Command
{
    protected $signature = 'kafka:consume-pipeline';
    protected $description = 'Sync Pipeline data from Hiring/Workspace Service';

    public function handle(KafkaHelper $kafka)
    {
        $groupId = "job-pipeline-sync-group";
        $topics = ['job7189.pipeline'];
        $consumer = $kafka->createConsumer($groupId, $topics);

        $this->info("Listening for Pipeline events...");
        (new StructuredLogger('system', 'action'))->info(['message' => "Kafka Consumer [Pipeline] started.");

        while (true) {
            $message = $consumer->consume(5000);

            if ($message->err === RD_KAFKA_RESP_ERR_NO_ERROR) {
                try {
                    $payload = json_decode($message->payload, true);
                    $eventType = $payload['event_type'] ?? '';
                    $data = $payload['data'] ?? [];

                    (new StructuredLogger('system', 'action'))->info(['message' => "Pipeline Event: $eventType", ['id' => $data['pipeline_id'] ?? '']);

                    switch ($eventType) {
                        case 'pipeline.created':
                        case 'pipeline.updated':
                            $this->handleUpsert($data);
                            break;
                        
                        case 'pipeline.deleted':
                            $this->handleDelete($data);
                            break;
                    }

                    $consumer->commit($message);
                } catch (\Exception $e) {
                    (new StructuredLogger('system', 'error'))->error(['message' => "Pipeline Sync Error: " . $e->getMessage());
                }
            }
        }
    }

    private function handleUpsert(array $data)
    {
        // Dùng updateOrCreate để xử lý cả Create và Update
        JobPipeline::updateOrCreate(
            ['PipelineID' => $data['pipeline_id']],
            [
                'Name'      => $data['name'],
                'IsDefault' => $data['is_default'] ?? false,
            ]
        );
        $this->info("Upserted Pipeline: " . $data['pipeline_id']);
    }

    private function handleDelete(array $data)
    {
        JobPipeline::where('PipelineID', $data['pipeline_id'])->delete();
        $this->info("Deleted Pipeline: " . $data['pipeline_id']);
    }
}