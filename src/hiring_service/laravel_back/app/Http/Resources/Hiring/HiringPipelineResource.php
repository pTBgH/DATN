<?php

namespace App\Http\Resources\Hiring;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HiringPipelineResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'pipeline_id'   => $this->PipelineID,
            'workspace_id'  => $this->WorkspaceID,
            'name'          => $this->Name,
            'is_default'    => (bool) $this->IsDefault,
            
            // Nhúng danh sách stages đã format sang snake_case
            'stages'        => PipelineStageResource::collection($this->whenLoaded('stages')),
            
            'created_at'    => $this->CreatedAt,
            'updated_at'    => $this->UpdatedAt,
        ];
    }
}