<?php

namespace App\Http\Resources\Hiring;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InterviewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'interview_id'   => $this->InterviewID,
            'application_id' => $this->ApplicationID,
            'start_time'     => $this->StartTime->toIso8601String(),
            'end_time'       => $this->EndTime->toIso8601String(),
            'status'         => $this->Status, // Scheduled, Completed, Cancelled
            'location'       => $this->Location, // Link Google Meet hoặc Phòng họp
            'note'           => $this->Note,
            'created_at'     => $this->CreatedAt,
            'feedback'       => $this->Feedback
        ];
    }
}