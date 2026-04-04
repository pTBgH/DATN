<?php
namespace App\Http\Controllers\Job;

use App\Http\Controllers\Controller;
use App\Services\Job\JobService;
use App\Models\Job\JobSubJd;
use App\Models\Job\JobJd;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use App\Http\Controllers\Job\Traits\JobValidationRules;
use App\Http\Controllers\Job\Traits\HandlesJobUpdate;
use App\Http\Resources\JobSubJdResource;
use App\Http\Resources\JobJdResource;
use App\Services\CompanyDataEnricher;

class JobController extends Controller
{
    use JobValidationRules, HandlesJobUpdate;

    private JobService $jobService;
    private CompanyDataEnricher $enricher;
    
    public function __construct(JobService $jobService, CompanyDataEnricher $enricher)
    {
        $this->jobService = $jobService;
        $this->enricher = $enricher;
    }
    
    public function index(Request $request, string $workspaceId)
    {
        $recruiter = Auth::user();
        
        // Validate Filters (Giữ nguyên như đã làm)
        $filters = $request->validate([
            'q' => 'nullable|string|max:100',
            'status' => 'nullable|integer',
            'exp_years' => 'nullable|integer|min:0',
            'location_id' => 'nullable|integer',
            'job_types' => 'nullable|array',
            'job_types.*' => 'integer',
            'sectors' => 'nullable|array',
            'sectors.*' => 'integer',
            'sort_by' => 'nullable|string|in:highest_view,lowest_view,highest_application,lowest_application,newest,oldest,updated_time,name_az,name_za,deadline_earliest,deadline_latest',
        ]);

        $paginatedJobs = $this->jobService->getJobList($recruiter, $workspaceId, $filters);
        
        // Trả về Resource Collection
        return JobSubJdResource::collection($paginatedJobs);
    }

    public function show(string $workspaceId, string $jobId)
    {
        $job = $this->jobService->getJobDetail($jobId);
        
        if (!$job) {
            return response()->json(['message' => 'Job not found'], 404);
        }

        // Trả về Single Resource
        return new JobSubJdResource($job);
    }

    public function update(Request $request, string $workspaceId, string $jobId): JsonResponse
    {
        return $this->handleUpdate($request, $workspaceId, $jobId); 
    }

    public function publicSearch(Request $request)
    {
        // Query vào bảng job_jds (Bảng tối ưu cho đọc)
        $query = JobJd::with('company')->where('IsActive', 1); // Chỉ lấy tin đang bật

        // Filter cơ bản
        if ($request->filled('q')) {
            $query->where('Title', 'like', '%' . $request->q . '%');
        }
        
        if ($request->filled('location_id')) {
            $query->where('LocationID', $request->location_id);
        }

        // Sắp xếp mới nhất
        $jobs = $query->orderBy('CreatedAt', 'desc')
                      ->paginate($request->input('limit', 20));

        return JobJdResource::collection($jobs);
    }

    public function publicDetail($id)
    {
        $job = JobJd::with('company')->where('JobID', $id)->first();

        (new StructuredLogger('system', 'action'))->info(['message' => 'Public job detail requested.', ['identifier' => $id]);

        // Fallback slug
        if (!$job) {
            $job = JobJd::with('company')->where('slug', $id)->first();
        }

        if (!$job) {
            (new StructuredLogger('system', 'warning'))->warning(['message' => "Public job detail not found for identifier: {$id}");
            return response()->json(['message' => 'Job not found or closed'], 404);
        }

        // TRẢ VỀ RESOURCE (Để ra đúng snake_case company_id)
        return new JobJdResource($job);
    }
}