<?php

namespace App\Services\External;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\Cache;

class WorkspaceInternalClient
{
    /**
     * Lấy thông tin công ty để lưu Snapshot (Tên, Logo, Địa chỉ).
     * Có Cache ngắn hạn (10 phút) để đỡ gọi nhiều.
     */
    public function getCompanySnapshot(string $workspaceId): array
    {
        return Cache::remember("snapshot:ws:{$workspaceId}", 600, function () use ($workspaceId) {
            $url = config('services.microservices.workspace') . "/api/internal/companies/batch-info";
            
            try {
                $response = Http::post($url, ['ids' => [$workspaceId]]);
                
                if ($response->successful()) {
                    $data = $response->json();
                    // API batch trả về map ['id' => data], nên cần lấy phần tử đầu tiên
                    $info = $data[$workspaceId] ?? null;
                    
                    if ($info) {
                        return [
                            'CompanyNameSnapshot' => $info['CompanyName'],
                            'CompanyLogoSnapshot' => $info['PicturePath'],
                            // Mapping thêm location nếu cần
                        ];
                    }
                }
            } catch (\Exception $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "WorkspaceInternalClient Error: " . $e->getMessage());
            }

            // Fallback nếu lỗi
            return [
                'CompanyNameSnapshot' => 'Unknown Company',
                'CompanyLogoSnapshot' => null,
            ];
        });
    }
}