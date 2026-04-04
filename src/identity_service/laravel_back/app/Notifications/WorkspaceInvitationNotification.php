<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
// use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

// class WorkspaceInvitationNotification extends Notification implements ShouldQueue

class WorkspaceInvitationNotification extends Notification
{
    use Queueable;

    public string $invitationToken;
    public string $inviterName;
    public string $workspaceName;

    public function __construct(string $invitationToken, string $inviterName, string $workspaceName)
    {
        $this->invitationToken = $invitationToken;
        $this->inviterName = $inviterName;
        $this->workspaceName = $workspaceName;
    }

    public function via($notifiable): array
    {
        return ['mail'];
    }

    public function toMail($notifiable): MailMessage
    {
        // Link này frontend sẽ xử lý
        $acceptUrl = config('app.frontend_url') . '/accept-invitation?token=' . $this->invitationToken;

        return (new MailMessage)
                    ->subject('Invitation to join ' . $this->workspaceName . ' workspace')
                    ->line($this->inviterName . ' has invited you to join the ' . $this->workspaceName . ' workspace on our platform.')
                    ->action('Accept Invitation', $acceptUrl)
                    ->line('This invitation will expire in 48 hours.')
                    ->line('If you were not expecting this invitation, you can ignore this email.');
    }
}