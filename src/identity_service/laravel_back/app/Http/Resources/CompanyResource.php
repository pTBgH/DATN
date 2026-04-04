<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class CompanyResource extends JsonResource
{
    public function toArray($request): array
    {
        $views = (int) ($this->views ?? 0);
        $applications = (int) ($this->applications ?? 0);
        $apply_rate = ($views > 0) ? round(($applications / $views) * 100, 2) : 0;

        return [
            // Dựa trên CompanyMinimalState interface
            'id' => $this->WorkspaceID,
            'name' => $this->Name,
            'logo' => $this->Logo,
            'permissions' => (int) $this->permissions, // <-- Sẽ lấy từ thuộc tính đính kèm

            // Dựa trên CompanyState interface
            'location' => $this->Location,
            'active_jobs' => (int) $this->active_jobs, // <-- Sẽ lấy từ thuộc tính đính kèm
            'views' => (int) $this->views,             // <-- Sẽ lấy từ thuộc tính đính kèm
            'applications' => (int) $this->applications, // <-- Sẽ lấy từ thuộc tính đính kèm
            'apply_rate' => $apply_rate,
            'email' => $this->Email,
            'plan' => $this->Plan,
            'usage' => $this->UsageCount ? (int) $this->UsageCount : null,
        ];
    }
}