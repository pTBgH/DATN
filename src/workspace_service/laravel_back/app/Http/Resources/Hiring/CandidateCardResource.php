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
            'candidate_name' => optional($this->cv)->Name ?? 'N/A',
            'position' => optional($this->cv)->Position ?? 'N/A',
            'avatar_url' => optional($this->cv)->ProfileImage,
            'score' => 70, // Demo score
            'applied_at' => optional($this->AppliedAt)->toIso8601String(),
        ];
    }
}