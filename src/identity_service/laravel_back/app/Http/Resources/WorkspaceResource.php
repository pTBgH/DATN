<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use App\Enums\WorkspaceMemberStatus;

class WorkspaceResource extends JsonResource
{
    public function toArray($request): array
    {
        // Tính toán các chỉ số
        $views = (int) ($this->views ?? 0);
        $applications = (int) ($this->applications ?? 0);
        $apply_rate = ($views > 0) ? round(($applications / $views) * 100, 2) : 0;

        // Xử lý quan hệ an toàn
        $companyProfile = $this->whenLoaded('companyProfile');
        $location = $companyProfile && $companyProfile->relationLoaded('location') ? $companyProfile->location : null;

        return [
            // --- ID chuẩn (sẽ không bị lỗi _i_d nữa) ---
            'workspace_id' => $this->WorkspaceID, 
            'email' => $this->Email,
            'member_status' => $this->when(isset($this->member_status), function () {
                $statusEnum = WorkspaceMemberStatus::tryFrom($this->member_status);
                return $statusEnum?->label();
            }),
            'permissions' => $this->when(isset($this->permissions), $this->permissions),

            // --- Phần dữ liệu Company ---
            'company' => [
                'name' => $companyProfile->CompanyName ?? null,
                'logo' => $companyProfile->PicturePath ?? null,
                'location' => $location->DetailLocation ?? null,
                'size' => $this->whenLoaded('companyProfile', fn() => $this->companyProfile?->size?->SizeRange),
                'industry' => $this->whenLoaded('companyProfile', function () {
                    return $this->companyProfile?->industry?->NameEN ?? null;
                }),
                // Stats
                'active_jobs' => (int) ($this->active_jobs ?? 0),
                'views' => $views,
                'applications' => $applications,
                'apply_rate' => $apply_rate,
            ],

            'plan_code' => $this->whenLoaded('plan', fn() => $this->plan->PlanCode),
            'max_usage' => $this->whenLoaded('plan', fn() => $this->plan->MaxUsage),
            'usage' => $this->UsageCount ? (int) $this->UsageCount : 0,            
            'created_at' => $this->CreatedAt->toIso8601String(),
            'updated_at' => $this->UpdatedAt->toIso8601String(),
        ];
    }
}