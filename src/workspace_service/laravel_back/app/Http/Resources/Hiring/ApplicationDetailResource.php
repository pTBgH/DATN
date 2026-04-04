<?php
namespace App\Http\Resources\Hiring;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Http\Resources\CvResource;

class ApplicationDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'application_id' => $this->ApplicationID,
            'applied_at' => optional($this->AppliedAt)->toIso8601String(),
            'current_stage' => [
                'id' => optional($this->stage)->StageID,
                'name' => optional($this->stage)->Name,
            ],
            'cv' => new CvResource($this->whenLoaded('cv')),
        ];
    }
}