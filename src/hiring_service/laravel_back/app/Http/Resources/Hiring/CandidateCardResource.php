<?php
namespace App\Http\Resources\Hiring;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CandidateCardResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'application_id' => $this->ApplicationID,
            'cv_id' => $this->CVID,
            'candidate_name' => $this->Name,
            'candidate_email'=> $this->Email,
            'cv_url'         => $this->CvUrl,  
            'score' => 70, // Demo score
            'applied_at' => $this->AppliedAt,
        ];
    }
}