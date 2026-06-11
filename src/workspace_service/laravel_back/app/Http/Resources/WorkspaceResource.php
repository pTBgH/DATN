<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WorkspaceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            // Cả snake_case cũ của backend và alias của frontend để tương thích
            'id'                      => $this->WorkspaceID,
            'workspace_id'            => $this->WorkspaceID,
            'name'                    => $this->Name,
            'logo'                    => $this->Logo,
            'email'                   => $this->Email,
            'workspace_email'         => $this->Email,
            
            // Quyền hạn (nếu được load)
            'permissions'             => $this->permissions ?? null,

            // Tránh lỗi render ở Front End do thiếu các thuộc tính mở rộng
            'location'                => $this->Location ?? null,
            'active_jobs'             => (int) ($this->active_jobs ?? 0),
            'views'                   => (int) ($this->views ?? 0),
            'applications'            => (int) ($this->applications ?? 0),
            'apply_rate'              => ($this->views ?? 0) > 0 ? round((($this->applications ?? 0) / $this->views) * 100, 2) : 0,
            'plan'                    => $this->Plan ?? 'Free',
            'usage'                   => (int) ($this->Usage ?? 0),

            'created_at'              => $this->CreatedAt instanceof \DateTime ? $this->CreatedAt->toIso8601String() : $this->CreatedAt,
            'updated_at'              => $this->UpdatedAt instanceof \DateTime ? $this->UpdatedAt->toIso8601String() : $this->UpdatedAt,
        ];
    }
}