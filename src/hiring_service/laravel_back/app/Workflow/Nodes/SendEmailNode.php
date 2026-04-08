<?php

namespace App\Workflow\Nodes;

use App\Services\Kafka\KafkaHelper;
use Illuminate\Support\Facades\Log;

class SendEmailNode implements WorkflowNodeInterface
{
    protected KafkaHelper $kafka;

    public function __construct(KafkaHelper $kafka)
    {
        $this->kafka = $kafka;
    }

    public function getType(): string
    {
        return 'action.send_email';
    }

    public function execute(array $context, array $parameters): array
    {
        Log::info("[Workflow Node: SendEmail] Executing...");

        // $parameters ở đây đã được ExpressionResolver xử lý (thay thế biến {{..}} thành giá trị thật)
        
        $to = $parameters['to'] ?? null;
        $template = $parameters['template'] ?? 'default';
        $variables = $parameters['variables'] ?? [];

        if (!$to) {
            Log::error("[Workflow Node: SendEmail] Missing 'to' email address.");
            throw new \Exception("Missing email address");
        }

        // Bắn Kafka lệnh gửi mail
        $this->kafka->produce('job7189.communication', [
            'event_type' => 'command.send_email',
            'timestamp'  => microtime(true),
            'data' => [
                'to' => $to,
                'template' => $template,
                'variables' => $variables
            ]
        ]);

        Log::info("[Workflow Node: SendEmail] Command sent to Kafka for: {$to}");

        return [
            'status' => 'sent',
            'sent_at' => now()->toIso8601String()
        ];
    }
}