<?php

namespace App\Http\Resources\Hiring;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PipelineStageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'stage_id'      => $this->StageID,
            'name'          => $this->Name,
            'order'         => (int) $this->StageOrder,
            'color'         => $this->Color,
            'is_system'     => (bool) $this->IsSystemStage,
            'created_at'    => $this->CreatedAt,
        ];
    }
}