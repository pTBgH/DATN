<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Services\EmailService;
use Illuminate\Http\Request;

class EmailInternalController extends Controller
{
    protected EmailService $emailService;

    public function __construct(EmailService $emailService)
    {
        $this->emailService = $emailService;
    }

    // POST /api/internal/email/send
    public function send(Request $request)
    {
        $validated = $request->validate([
            'to'      => 'required|email',
            'subject' => 'required|string',
            'body'    => 'required|string',
            'source'  => 'nullable|string'
        ]);

        $success = $this->emailService->sendEmail(
            $validated['to'],
            $validated['subject'],
            $validated['body'],
            $validated['source'] ?? 'API'
        );

        if ($success) {
            return response()->json(['message' => 'Email sent successfully']);
        }

        return response()->json(['message' => 'Failed to send email'], 500);
    }
}