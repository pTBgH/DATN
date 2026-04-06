<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class CompanyDataEnricher
{
    /**
     * Hàm làm giàu dữ liệu cho DANH SÁCH Job (Collection hoặc Paginator)
     * Dùng cho API Search, History...
     */
    public function enrich($jobs)
    {
        // Lấy Collection ra nếu là Paginator
        $collection = $jobs instanceof LengthAwarePaginator ? $jobs->getCollection() : $jobs;

        if ($collection->isEmpty()) return $jobs;

        // 1. Lấy danh sách CompanyID (Duy nhất)
        $companyIds = $collection->pluck('CompanyID')->unique()->filter()->values()->toArray();

        if (empty($companyIds)) return $jobs;

        // 2. Kiểm tra Cache Redis
        $cachedData = [];
        $missingIds = [];

        foreach ($companyIds as $id) {
            $cacheKey = "companies:{$id}";
            $data = Cache::get($cacheKey);
            
            if ($data) {
                $cachedData[$id] = $data;
            } else {
                $missingIds[] = $id;
            }
        }

        // 3. Gọi Batch API sang Workspace Service (nếu thiếu cache)
        if (!empty($missingIds)) {
            try {
                $url = config('services.microservices.workspace'); // http://workspace-service
                $response = Http::timeout(2)->post("{$url}/api/internal/companies/batch-info", [
                    'ids' => $missingIds
                ]);

                if ($response->successful()) {
                    $freshData = $response->json();
                    
                    // Lưu Cache và gán vào mảng data
                    foreach ($freshData as $id => $info) {
                        Cache::put("companies:{$id}", $info, 3600); // Cache 1 tiếng
                        $cachedData[$id] = $info;
                    }
                }
            } catch (\Exception $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Enrichment Batch Failed: " . $e->getMessage()]);
            }
        }

        // 4. Gán dữ liệu vào từng Job trong Collection
        // Lưu ý: Gán thuộc tính động (không lưu DB)
        $collection->transform(function ($job) use ($cachedData) {
            $info = $cachedData[$job->CompanyID] ?? null;

            // Gán các trường snapshot (để Controller hoặc Resource dùng)
            $job->company_name = $info['CompanyName'] ?? 'Unknown Company';
            $job->company_logo = $info['PicturePath'] ?? null;
            $job->company_location_id = $info['LocationID'] ?? null;
            
            // Gán cả kiểu PascalCase nếu Controller cũ đang dùng
            $job->CompanyNameSnapshot = $info['CompanyName'] ?? 'Unknown Company';
            $job->CompanyLogoSnapshot = $info['PicturePath'] ?? null;

            return $job;
        });

        return $jobs;
    }

    /**
     * Hàm làm giàu cho 1 Job duy nhất
     * Dùng cho API Create/Detail
     */
    public function enrichOne($job)
    {
        if (!$job || empty($job->CompanyID)) return $job;

        // Tận dụng hàm enrich collection để đỡ viết lại logic
        $collection = collect([$job]);
        $this->enrich($collection);

        return $collection->first();
    }
}