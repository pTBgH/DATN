<?php

namespace App\Listeners;

use App\Enums\JobStatusEnum;
use App\Events\JobStateChanged;
use App\Models\Job\JobJd;
use App\Models\Job\JobSubJd;
use App\Models\Job\JobStat;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Carbon\Carbon;
use Throwable;

class JobPublishingListener
{
    public function handle(JobStateChanged $event): void
    {
        $jobSub = $event->jobSubJd; 
        Log::channel('stderr')->info("[Listener] Processing Job ID: {$jobSub->JobID}, Status: {$jobSub->status->name}");

        try {
            if ($jobSub->status === JobStatusEnum::PUBLISHED) {
                $this->publish($jobSub);
            } else {
                // Nếu không phải Published (VD: Closed, Suspended...), xóa khỏi bảng hiển thị
                $this->unpublish($jobSub);
            }
        } catch (Throwable $e) {
            // Log lỗi ra stderr để kubectl logs thấy được
            Log::channel('stderr')->error('[Listener] FAILED', [
                'job_id' => $jobSub->JobID,
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    private function publish(JobSubJd $jobSub): void
    {
        // 1. Chuẩn bị dữ liệu từ bảng Sub
        $dataToSync = $this->transform($jobSub);

        // 2. Lấy thông tin Công ty (Snapshot) từ Workspace Service
        $companyInfo = $this->getCompanySnapshot($jobSub->CompanyID);

        // 3. Gán vào các cột Snapshot vừa tạo trong DB
        $dataToSync['CompanyNameSnapshot'] = $companyInfo['name'];
        $dataToSync['CompanyLogoSnapshot'] = $companyInfo['logo'];
        $dataToSync['CompanyLocationSnapshot'] = $companyInfo['location_id']; // Hoặc text nếu muốn

        // 4. Lưu vào bảng Read (JobJd)
        JobJd::updateOrCreate(
            ['JobID' => $jobSub->JobID],
            $dataToSync
        );

        // 5. Tạo bảng thống kê (nếu chưa có)
        JobStat::firstOrCreate(['job_id' => $jobSub->JobID]);

        Log::channel('stderr')->info("[Listener] Job published successfully with Snapshot Data.");
    }

    private function unpublish(JobSubJd $jobSub): void
    {
        JobJd::destroy($jobSub->JobID);
        Log::channel('stderr')->info("[Listener] Job unpublished.");
    }

    private function getCompanySnapshot($workspaceId)
    {
        // Cache 1 tiếng để đỡ gọi nhiều
        return Cache::remember("snapshot:ws:{$workspaceId}", 3600, function () use ($workspaceId) {
            try {
                $url = config('services.microservices.workspace'); // http://workspace-service
                $response = Http::timeout(2)->post("{$url}/api/internal/companies/batch-info", [
                    'ids' => [$workspaceId]
                ]);

                if ($response->successful()) {
                    $data = $response->json();
                    $info = $data[$workspaceId] ?? null;
                    if ($info) {
                        return [
                            'name' => $info['CompanyName'],
                            'logo' => $info['PicturePath'],
                            'location_id' => $info['LocationID']
                        ];
                    }
                }
            } catch (Throwable $e) {
                Log::channel('stderr')->error("Failed to fetch company snapshot: " . $e->getMessage());
            }

            return ['name' => 'Unknown Company', 'logo' => null, 'location_id' => null];
        });
    }

    private function transform(JobSubJd $jobSub): array
    {
        $attributes = $jobSub->toArray();
        
        $excludeFields = [
            'status', 'CreatedAt', 'UpdatedAt', 'Version', 
            'PipelineID', 'pending_data', 
            'job_stat', 'company_info', 'job_jd', 'pipeline', 'changes', 'snapshots'
        ];

        foreach ($excludeFields as $field) unset($attributes[$field]);
    
        // Slug & Date logic
        if (empty($attributes['slug'])) {
            $attributes['slug'] = Str::slug($jobSub->Title) . '-' . Str::random(6);
        }
        if (!empty($jobSub->OpenDate)) {
            $attributes['OpenDate'] = \Carbon\Carbon::parse($jobSub->OpenDate)->format('Y-m-d');
        }
        if (!empty($jobSub->EndDate)) {
            $attributes['EndDate'] = \Carbon\Carbon::parse($jobSub->EndDate)->format('Y-m-d');
        }

        $attributes['IsActive'] = true;
        return $attributes;
    }
}