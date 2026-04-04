<?php

namespace App\Http\Resources;

use App\Enums\JobStatusEnum; // Thêm use để có thể truy cập trực tiếp
use Illuminate\Http\Resources\Json\JsonResource;

class JobSubJdResource extends JsonResource
{
    public function toArray($request)
    {
        $currentStatus = $this->status ?? JobStatusEnum::DRAFT;

        $isLive = in_array($currentStatus, [
            JobStatusEnum::PUBLISHED,
            JobStatusEnum::PENDING,
            JobStatusEnum::DRAFT // DRAFT vẫn có record bên job_jds
        ]);

        // Safe access: $this->jobJd có thể null nếu đồng bộ lỗi, fallback về $this->ViewCount
        $realViewCount = ($isLive && $this->jobJd) ? $this->jobJd->ViewCount : $this->ViewCount;
        $realApplyCount = ($isLive && $this->jobJd) ? $this->jobJd->ApplyCount : $this->ApplyCount;        

        return [
            'job_id' => $this->JobID,
            'title' => $this->Title,
            'slug' => $this->slug,
            'pipeline_name' => $this->pipeline_name ?? $this->pipeline?->Name ?? null,
            // 'company_id' => $this->whenLoaded('companyInfo', fn() => $this->CompanyID),
            // 'company_name' => $this->whenLoaded('companyInfo', fn() => $this->companyInfo?->CompanyName),
            'version' => $this->Version,
            // 3. Sử dụng label của $currentStatus
            'status' => $currentStatus->label(),
            'updated_at' => $this->UpdatedAt?->toIso8601String(),
            'created_at' => $this->CreatedAt?->toIso8601String(),

            'view_count' => (int) ($this->jobStat?->view_count ?? 0),
            'apply_count' => (int) ($this->jobStat?->apply_count ?? 0),
            
            // ... các trường còn lại giữ nguyên ...
            'description' => $this->Description,
            'requirements' => $this->Requirements,
            'benefits' => $this->Benefits,
            'salary_min' => $this->MinSalary,
            'salary_max' => $this->MaxSalary,
            'deadline' => $this->EndDate ? $this->EndDate->format('Y-m-d') : null,
            'open_date' => $this->OpenDate ? $this->OpenDate->format('Y-m-d') : null,
            'exp_years' => $this->ExperienceYear,
            'min_age' => $this->MinAge,
            'max_age' => $this->MaxAge,
            'keywords' => $this->Keywords,
            'job_link' => $this->JobLink,
            'picture_url' => $this->PictureUrl,
            'detail_address' => $this->detail_address,
            'job_type' => $this->job_type_name,
            'job_sector' => $this->job_sector_name,
            'working_type' => $this->working_type_name,
            'contract_type' => $this->contract_type_name,
            'degree_level' => $this->degree_level_name,
            'sex' => $this->sex_name,
            'currency' => $this->currency_code,
        ];
    }
}