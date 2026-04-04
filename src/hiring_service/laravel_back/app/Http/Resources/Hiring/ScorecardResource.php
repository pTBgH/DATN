<?php

namespace App\Http\Resources\Hiring;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ScorecardResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'scorecard_id'     => $this->ScorecardID,
            'application_id'   => $this->ApplicationID,
            
            // Trả về thông tin người chấm đầy đủ
            'interviewer' => [
                'id'   => $this->InterviewerID,
                'name' => $this->InterviewerName,
            ],

            'score_data'       => $this->ScoreJson,
            'comment'          => $this->Comment,
            'created_at'       => $this->CreatedAt,
        ];
    }
}