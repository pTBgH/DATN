<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\Kafka\KafkaHelper;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use App\Mail\GenericMail;

class ConsumeNotifications extends Command
{
    protected $signature = 'kafka:consume-notifications';
    protected $description = 'Consume notification events from Kafka and dispatch emails';

    protected KafkaHelper $kafka;

    public function __construct(KafkaHelper $kafka)
    {
        parent::__construct();
        $this->kafka = $kafka;
    }

    public function handle(KafkaHelper $kafka)
    {
        $topics = ['job7189.applications', 'job7189.hiring'];
        $consumer = $kafka->createConsumer('communication-service-group', $topics);

        $this->info("🚀 Communication Service is now listening...");
        $this->info("📬 Subscribed to: " . implode(', ', $topics));
        $this->line("");

        while (true) {
            $message = $consumer->consume(120 * 1000);
            
            switch ($message->err) {
                case RD_KAFKA_RESP_ERR_NO_ERROR:
                    try {
                        $this->processMessage($message);
                        $consumer->commit($message);
                    } catch (\Throwable $e) {
                        $this->error("❌ Error: " . $e->getMessage());
                        Log::error("Kafka Message Processing Failed", [
                            'error' => $e->getMessage(),
                            'trace' => $e->getTraceAsString()
                        ]);
                    }
                    break;
                
                case RD_KAFKA_RESP_ERR__PARTITION_EOF:
                case RD_KAFKA_RESP_ERR__TIMED_OUT:
                    break;

                default:
                    $this->warn("Kafka Error: " . $message->errstr());
                    break;
            }
        }
    }

    protected function processMessage($message): void
    {
        $payload = json_decode($message->payload, true);
        $eventType = $payload['event_type'] ?? 'unknown';
        $data = $payload['data'] ?? [];

        $this->info("📨 Event: {$eventType}");

        switch ($eventType) {
            case 'candidate.applied':
                $this->handleCandidateApplied($data);
                break;

            // case 'application.stage_moved':
            //     $this->handleStageMoved($data);
            //     break;

            case 'command.send_email':
                $this->handleCommandSendEmail($data);
                break;
            default:
                $this->warn("⚠️ Unknown event type: {$eventType}");
        }
    }

    protected function handleCandidateApplied(array $data): void
    {
        $email = $data['applicant_email'] ?? null;

        if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error("Invalid email");
            return;
        }

        $this->info("✉️  Sending to: {$email}");

        try {
            $subject = "Ứng tuyển thành công: " . ($data['job_title'] ?? 'Vị trí công việc');
            
            // Chuẩn bị data cho template
            $viewData = [
                'candidate_name' => $data['applicant_name'] ?? 'Ứng viên',
                'job_title'      => $data['job_title'] ?? 'Vị trí công việc',
                'company_name'   => $data['company_name'] ?? 'Công ty',
                'applied_at'     => $data['applied_at'] ?? now()->toDateTimeString()
            ];

            // Gửi email với Blade template
            Mail::to($email)->send(
                new GenericMail($subject, null, 'emails.applied', $viewData)
            );

            $this->info("Email sent!");

        } catch (\Exception $e) {
            $this->error("Failed: " . $e->getMessage());
            Log::error("Email Failed", [
                'recipient' => $email,
                'error' => $e->getMessage()
            ]);
        }
    }

    protected function handleStageMoved(array $data): void
    {
        $email = $data['applicant_email'] ?? null;

        if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error("❌ Invalid email");
            return;
        }

        $this->info("✉️  Sending to: {$email}");

        try {
            $subject = "Cập nhật hồ sơ: " . ($data['job_title'] ?? 'Vị trí công việc');
            
            $viewData = [
                'candidate_name'  => $data['applicant_name'] ?? 'Ứng viên',
                'job_title'       => $data['job_title'] ?? 'Vị trí công việc',
                'new_stage_name'  => $data['new_stage_name'] ?? 'Giai đoạn mới',
                'company_name'    => $data['company_name'] ?? 'Công ty'
            ];

            Mail::to($email)->send(
                new GenericMail($subject, null, 'emails.stage_moved', $viewData)
            );

            $this->info("✅ Email sent!");

        } catch (\Exception $e) {
            $this->error("❌ Failed: " . $e->getMessage());
            Log::error("Email Failed", [
                'recipient' => $email,
                'error' => $e->getMessage()
            ]);
        }
    }

    protected function handleCommandSendEmail(array $data): void
    {
        $email = $data['to'] ?? null;
        $template = $data['template'] ?? 'emails.default';
        $variables = $data['variables'] ?? [];

        if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error("❌ Invalid email in command");
            return;
        }

        $this->info("✉️  Executing Command: Send Email to {$email} (Template: {$template})");

        try {
            // Tự động sinh Subject nếu không có (hoặc lấy từ config/template)
            $subject = match($template) {
                'emails.stage_moved' => "Cập nhật hồ sơ: " . ($variables['job_title'] ?? ''),
                'emails.interview_invite' => "Mời phỏng vấn: " . ($variables['job_title'] ?? ''),
                default => "Thông báo từ Job7189"
            };

            // Gửi mail
            Mail::to($email)->send(
                new GenericMail($subject, null, $template, $variables)
            );

            $this->info("✅ Email sent successfully!");

        } catch (\Exception $e) {
            $this->error("❌ Failed to send email: " . $e->getMessage());
            Log::error("Email Command Failed", ['error' => $e->getMessage()]);
        }
    }
}