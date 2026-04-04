<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Models\Job\JobSubJd; // Hoặc JobJd nếu muốn lấy data public
use Illuminate\Http\Request;

class JobInternalController extends Controller
{
    // POST /api/internal/jobs/batch-info
    public function getBatchInfo(Request $request)
    {
        $ids = $request->input('ids', []);
        if (empty($ids)) return response()->json([]);

        // Lấy thông tin cơ bản để hiển thị lịch sử
        // Dùng JobSubJd để lấy cả những job đã đóng/hết hạn (để ứng viên vẫn xem được lịch sử)
        $jobs = JobSubJd::whereIn('JobID', $ids)
            ->select(['JobID', 'Title', 'CompanyID', 'status', 'Slug', 'PictureUrl']) 
            ->get();
            
        // Enrich thêm tên công ty nếu cần thiết (Gọi service Enricher trong Job Service)
        // Nhưng để nhanh, ta trả về raw, Candidate Service tự lo hoặc FE tự lo phần tên cty nếu đã có snapshot.
        // Ở bài trước, ta đã làm Enricher cho Job Service rồi, có thể tái sử dụng.
        
        $enricher = app(\App\Services\CompanyDataEnricher::class);
        $enricher->enrich($jobs);

        return response()->json($jobs->keyBy('JobID'));
    }
}