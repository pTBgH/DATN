<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class GenericMail extends Mailable
{
    use Queueable, SerializesModels;

    public $subjectText;
    public $bodyText;
    public $viewName;
    public $viewData;

    /**
     * Constructor hỗ trợ 2 MODE:
     * 
     * MODE 1 - Text thuần (backward compatible):
     *   new GenericMail($subject, $body)
     * 
     * MODE 2 - Blade Template (mới):
     *   new GenericMail($subject, null, $viewName, $viewData)
     */
    public function __construct($subject, $body = null, $viewName = null, $viewData = [])
    {
        $this->subjectText = $subject;
        $this->bodyText = $body;
        $this->viewName = $viewName;
        $this->viewData = $viewData;
    }

    /**
     * Build the message.
     */
    public function build()
    {
        $mail = $this->subject($this->subjectText);

        // Nếu có viewName → Dùng Blade template
        if ($this->viewName) {
            return $mail->view($this->viewName)->with($this->viewData);
        }

        // Fallback: Dùng text thuần (cho code cũ)
        return $mail->html($this->bodyText);
    }
}