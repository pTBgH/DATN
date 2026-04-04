<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class JobJdResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            // ===== COMPANY (GIỮ NGUYÊN) =====
            'company_id'   => $this->CompanyID,
            'company_name' => $this->company->CompanyName ?? null, 
            'company_logo' => $this->company->PicturePath ?? null,

            // ===== JOB CORE =====
            'job_id' => $this->JobID,
            'title'  => $this->Title,
            'slug'   => $this->slug,

            // ===== CONTENT (align JobSubJd) =====
            'description'  => $this->Job_Description,
            'requirements' => $this->Job_Requirements,
            'benefits'     => $this->Job_Benefits,

            // ===== SALARY =====
            'salary_min' => (int) $this->MinSalary,
            'salary_max' => (int) $this->MaxSalary,

            // ===== LOCATION =====
            // 'location_id'    => $this->LocationID,
            'detail_address' => $this->detail_address,

            // ===== STATS =====
            'view_count'  => (int) $this->ViewCount,
            'apply_count' => (int) $this->ApplyCount,

            // ===== STATUS / TIME =====
            'is_active'  => (bool) $this->IsActive,
            'created_at' => $this->CreatedAt?->toIso8601String(),
        ];
    }
}
