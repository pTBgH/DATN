<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WorkspaceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'workspace_id'            => $this->WorkspaceID,
            'name'          => $this->Name,
            'logo'          => $this->Logo,
            'workspace_email'         => $this->Email,
            
            // Quyền hạn (nếu được load)
            'permissions'   => $this->permissions ?? null,
            // 'member_status' => $this->member_status ?? null,

            'created_at'    => $this->CreatedAt instanceof \DateTime ? $this->CreatedAt->toIso8601String() : $this->CreatedAt,
            'updated_at'    => $this->UpdatedAt instanceof \DateTime ? $this->UpdatedAt->toIso8601String() : $this->UpdatedAt,
        ];
    }
}