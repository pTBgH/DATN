<?php

namespace App\Services;

use App\Mail\GenericMail;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class EmailService
{
    public function sendEmail(string $to, string $subject, string $body, string $source = 'System'): bool
    {
        try {
            // 1. Gửi Mail
            Mail::to($to)->send(new GenericMail($subject, $body));

            // 2. Ghi Log Thành công
            $this->logToDb($to, $subject, $body, 'sent', null, $source);
            
            return true;

        } catch (\Exception $e) {
            // 3. Ghi Log Thất bại
            Log::error("Mail Send Error: " . $e->getMessage());
            $this->logToDb($to, $subject, $body, 'failed', $e->getMessage(), $source);
            return false;
        }
    }

    private function logToDb($to, $subject, $body, $status, $error, $source)
    {
        try {
            DB::table('email_logs')->insert([
                'Recipient'    => $to,
                'Subject'      => $subject,
                'Content'      => substr($body, 0, 500) . '...', // Lưu ngắn gọn thôi
                'Status'       => $status,
                'ErrorMessage' => $error,
                'TriggeredBy'  => $source,
                'CreatedAt'    => now()
            ]);
        } catch (\Exception $e) {
            Log::error("Failed to log email to DB: " . $e->getMessage());
        }
    }
}