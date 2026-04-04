<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\Kafka\KafkaHelper;
use App\Models\Job\JobApplication;
use App\Models\Hiring\HiringPipeline;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\Http;

class ConsumeApplications extends Command
{
    protected $signature = 'kafka:consume-applications';
    protected $description = 'Listen for new job applications';

    public function handle(KafkaHelper $kafka)
    {
        $topic = 'job7189.applications';
        $groupId = 'hiring-service-group';

        $consumer = $kafka->createConsumer($groupId, [$topic]);

        $this->info("Listening to topic: $topic...");

        while (true) {
            // Timeout 120s
            $message = $consumer->consume(120 * 1000);

            switch ($message->err) {
                case RD_KAFKA_RESP_ERR_NO_ERROR:
                    $this->processMessage($message);
                    $consumer->commit($message); // Commit thủ công khi thành công
                    break;
                
                case RD_KAFKA_RESP_ERR__PARTITION_EOF:
                case RD_KAFKA_RESP_ERR__TIMED_OUT:
                    // Không có tin mới, tiếp tục loop
                    break;

                default:
                    (new StructuredLogger('system', 'error'))->error(['message' => "Kafka Error: " . $message->errstr());
                    break;
            }
        }
    }

    private function processMessage($message)
    {
        $payload = json_decode($message->payload, true);
        if (($payload['event_type'] ?? '') !== 'candidate.applied') return;

        $data = $payload['data'];
        $this->info("Processing Application: " . $data['application_id']);

        (new StructuredLogger('system', 'action'))->info(['message' => "Received Application Event", $data);
        (new StructuredLogger('system', 'action'))->info(['message' => "Assigning Stage for Application: " . $data['application_id']);

        // 1. Tìm Pipeline & Stage đầu tiên
        // Logic: Lấy Pipeline Default của Workspace -> Lấy Stage có order thấp nhất
        $pipeline = HiringPipeline::where('WorkspaceID', $data['workspace_id'])
            ->where('IsDefault', true)
            ->first();

        // Nếu không có default, lấy cái đầu tiên
        if (!$pipeline) {
            $pipeline = HiringPipeline::where('WorkspaceID', $data['workspace_id'])->orderBy('CreatedAt')->first();
        }

        $stageId = null;
        if ($pipeline) {
            $firstStage = $pipeline->stages()->orderBy('StageOrder', 'asc')->first();
            $stageId = $firstStage ? $firstStage->StageID : null;
        }

        // 2. Lưu vào Database (QUAN TRỌNG: Dùng ID từ Kafka)
        try {
            // Dùng updateOrCreate để idempotent (tránh duplicate nếu Kafka gửi lại)
            JobApplication::updateOrCreate(
                ['ApplicationID' => $data['application_id']], // Key tìm kiếm (dùng ID từ Candidate gửi sang)
                [
                    'JobID'       => $data['job_id'],
                    'CVID'        => $data['cv_id'],
                    'ApplicantID' => $data['applicant_id'],
                    'WorkspaceID' => $data['workspace_id'],
                    'StageID'     => $stageId,
                    'StatusID'    => 1,
                    'Name'        => $data['applicant_name'] ?? null,
                    'Email'       => $data['applicant_email'] ?? null,
                    'CvUrl'       => $data['cv_path'] ?? null,
                    'AppliedAt'   => $data['applied_at'] ?? now()
                ]
            );
            $this->info("Saved Application [{$data['application_id']}] with Stage [{$stageId}]");

        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "DB Save Failed: " . $e->getMessage());
        }
    }

    private function getWorkspaceId($jobId) {
        // Logic gọi API sang Job Service hoặc lấy từ cache
        // Tạm thời fake để code chạy
        return '019b2178-5b78-7048-9978-f3ee7e15acc1'; 
    }
}