<?php

namespace App\Workflow\Nodes;

use App\Services\Kafka\KafkaHelper;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



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
        (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow Node: SendEmail] Executing...");

        // $parameters ở đây đã được ExpressionResolver xử lý (thay thế biến {{..}} thành giá trị thật)
        
        $to = $parameters['to'] ?? null;
        $template = $parameters['template'] ?? 'default';
        $variables = $parameters['variables'] ?? [];

        if (!$to) {
            (new StructuredLogger('system', 'error'))->error(['message' => "[Workflow Node: SendEmail] Missing 'to' email address.");
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

        (new StructuredLogger('system', 'action'))->info(['message' => "[Workflow Node: SendEmail] Command sent to Kafka for: {$to}");

        return [
            'status' => 'sent',
            'sent_at' => now()->toIso8601String()
        ];
    }
}