<?php
namespace App\Http\Resources\Hiring;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ApplicationDetailResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'id' => $this->ApplicationID,
            'stage' => [
                'id' => $this->stage->StageID,
                'name' => $this->stage->Name,
                'color' => $this->stage->Color,
            ],
            'candidate' => [
                'id' => $this->CandidateID, // ID tham chiếu
                'cv_id' => $this->CVID,     // ID tham chiếu
                'name' => $this->Name,      // Snapshot
                'email' => $this->Email,    // Snapshot
                'phone' => $this->Phone,    // Snapshot
                'cv_url' => $this->CvUrl,   // Snapshot
            ],
            'applied_at' => $this->AppliedAt,
        ];
    }
}