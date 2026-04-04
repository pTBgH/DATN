<?php

namespace App\Services\Job;
    
use App\Enums\JobStatusEnum;
use App\Events\JobStateChanged;
use App\Models\Job\JobSubJd;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;

use Illuminate\Support\Arr;
use Mews\Purifier\Purifier;
use Illuminate\Database\Query\Builder;
use App\Services\Job\JobVersioningService;
use Illuminate\Contracts\Auth\Authenticatable;
use App\Models\Job\JobPipeline;
use Throwable; 

class JobService
{
    protected Purifier $purifier;
    private string $masterTable = 'job_sub_jds';
    private string $detailTable = 'job_jds';
    protected JobVersioningService $versioningService;

    public function __construct(Purifier $purifier, JobVersioningService $versioningService)
    {
        $this->purifier = $purifier;
        $this->versioningService = $versioningService;
    }

    public function getJobList(Authenticatable $recruiter, string $workspaceId, array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        // Sử dụng Eloquent Builder
        $query = JobSubJd::query()
            // Join vào bảng stats để có thể sort và select
            ->leftJoin('job_stats', 'job_sub_jds.JobID', '=', 'job_stats.job_id')
            ->where('job_sub_jds.CompanyID', $workspaceId)
            // Lấy tất cả cột từ job_sub_jds và 2 cột từ job_stats
            ->leftJoin('job_pipelines', 'job_sub_jds.PipelineID', '=', 'job_pipelines.PipelineID')
            ->select('job_sub_jds.*', 
                     DB::raw('IFNULL(job_stats.view_count, 0) as view_count'), 
                     DB::raw('IFNULL(job_stats.apply_count, 0) as apply_count'));

        // ->->-> FILTER ->->->
        if (!empty($filters['q'])) $query->where('job_sub_jds.Title', 'like', '%' . $filters['q'] . '%');
        if (isset($filters['status'])) $query->where('job_sub_jds.status', (int)$filters['status']);
        if (isset($filters['exp_years'])) $query->where('job_sub_jds.ExperienceYear', '>=', (int)$filters['exp_years']);
        // if (!empty($filters['location_id'])) $query->where('job_sub_jds.LocationID', (int)$filters['location_id']);
        if (!empty($filters['job_types'])) $query->whereIn('job_sub_jds.WorkingTypeID', $filters['job_types']);
        if (!empty($filters['sectors'])) $query->whereIn('job_sub_jds.JobSectorID', $filters['sectors']);

        // ->->-> SORT ->->->
        $sortBy = $filters['sort_by'] ?? 'newest';
        
        // Tất cả các cột sort đều đã có sẵn trong query
        switch ($sortBy) {
            case 'highest_view': $query->orderBy('view_count', 'desc'); break;
            case 'lowest_view':  $query->orderBy('view_count', 'asc'); break;
            case 'highest_application': $query->orderBy('apply_count', 'desc'); break;
            case 'lowest_application':  $query->orderBy('apply_count', 'asc'); break;
            case 'name_az': $query->orderBy('job_sub_jds.Title', 'asc'); break;
            case 'name_za': $query->orderBy('job_sub_jds.Title', 'desc'); break;
            case 'deadline_earliest': $query->orderBy('job_sub_jds.EndDate', 'asc'); break;
            case 'deadline_latest': $query->orderBy('job_sub_jds.EndDate', 'desc'); break;
            case 'oldest':  $query->orderBy('job_sub_jds.CreatedAt', 'asc'); break;
            case 'updated_time': $query->orderBy('job_sub_jds.UpdatedAt', 'desc'); break;
            default: $query->orderBy('job_sub_jds.CreatedAt', 'desc'); break;
        }

        return $query->paginate($perPage);
    }

    public function getJobDetail(string $jobId): ?JobSubJd
    {
        return JobSubJd::with(['jobStat', 'pipeline'])
            ->where('JobID', $jobId)
            ->first();
    }

    public function updateJob(string $jobId, array $validatedData, Authenticatable $recruiter, string $workspaceId): ?JobSubJd
    {
        Log::channel('daily_normal')->info('Job update started.', ['job_id' => $jobId]);

        try {
            $job = JobSubJd::where('JobID', $jobId)
                            ->where('CompanyID', $workspaceId)
                            ->first();

            if (!$job) {
                Log::channel('daily_error')->error('Update failed: Job not found.', ['job_id' => $jobId]);
                return null;
            }

            $editableStatuses = [
                JobStatusEnum::DRAFT,
                JobStatusEnum::REJECTED,
                JobStatusEnum::EXPIRED,
            ];

            if (!in_array($job->status, $editableStatuses)) {
                $errorMessage = "Cannot edit job in '{$job->status->name}' state. Please unpublish it first.";
                Log::channel('daily_normal')->warning('Update blocked: Job not editable.', [
                    'job_id' => $jobId, 'status' => $job->status->name
                ]);
                throw new \Exception($errorMessage);
            }

            $payload = $this->mapRequestToDbFields($validatedData);

            DB::transaction(function () use ($job, $payload) {
                $job->fill($payload);
                if ($job->isDirty()) {
                    $this->versioningService->recordChanges($job);
                    $job->save();
                }
            });
            
            Log::channel('daily_normal')->info('Job updated successfully.', ['job_id' => $jobId]);
            
            return $this->getJobDetail($jobId);

        } catch (Throwable $e) {
            Log::channel('daily_error')->error("Exception during job update.", [
                'job_id' => $jobId, 'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    public function mapRequestToDbFields(array $requestData): array
    {
        $mappedData = [];
        $map = [
            'company_id'       => 'CompanyID',
            'title'            => 'Title',
            
            // --- SỬA ĐỔI TẠI ĐÂY ---
            'description'      => 'Description',  // DB mới dùng 'Description'
            'requirements'     => 'Requirements', // DB mới dùng 'Requirements'
            'benefits'         => 'Benefits',     // DB mới dùng 'Benefits'
            // -----------------------
            
            'keywords'         => 'Keywords',
            'deadline'         => 'EndDate',
            'open_date'          => 'OpenDate',
            'job_link'         => 'JobLink',
            'salary_max'       => 'MaxSalary',
            'salary_min'       => 'MinSalary',
            'currency'         => 'CurrencyID',
            'min_age'          => 'MinAge',
            'max_age'          => 'MaxAge',
            'exp_years'        => 'ExperienceYear',
            'job_type'         => 'JobTypeID',
            'job_sector'       => 'JobSectorID',
            'degree_level'     => 'DegreeLevelID',
            'working_type'     => 'WorkingTypeID',
            'contract_type'    => 'ContractTypeID',
            'detail_address'   => 'detail_address',
            // 'location_id'      => 'LocationID',
            'sex'              => 'SexID',
        ];

        foreach ($map as $requestKey => $dbColumn) {
            if (array_key_exists($requestKey, $requestData)) {
                $value = $requestData[$requestKey];

                // Clean HTML (Tên cột đã đổi)
                if (in_array($dbColumn, ['Description', 'Requirements', 'Benefits'])) {
                    $value = $this->purifier->clean($value ?? '');
                }

                $mappedData[$dbColumn] = $value;
            }
        }
        unset($mappedData['CompanyID']); // Bảo mật

        return $mappedData;
    }

    public function rollbackJob(string $jobId, int $targetVersion, Authenticatable $recruiter, string $workspaceId): ?JobSubJd
    {
        Log::channel('daily_normal')->info('Job rollback started.', [
            'job_id' => $jobId, 'target_version' => $targetVersion, 'user_id' => $recruiter->RecruiterID
        ]);

        // 1. TÌM JOB VÀ KIỂM TRA QUYỀN SỞ HỮU
        $jobToUpdate = JobSubJd::where('JobID', $jobId)
                               ->where('CompanyID', $workspaceId) // <-- THÊM ĐIỀU KIỆN NÀY
                               ->first();
        
        if (!$jobToUpdate) {
            // Log lỗi để biết ai đang cố rollback job không thuộc quyền
            Log::channel('daily_error')->warning('Rollback failed: Job not found or unauthorized.', [
                'job_id' => $jobId, 'workspace_id' => $workspaceId, 'user_id' => $recruiter->RecruiterID
            ]);
            return null; // Controller sẽ trả 404
        }
        
        // 2. PHỤC HỒI DỮ LIỆU
        $reconstructedData = $this->versioningService->reconstructVersion($jobId, $targetVersion);

        if (is_null($reconstructedData)) {
            Log::channel('daily_error')->error('Rollback failed: Cannot reconstruct version.', [
                'job_id' => $jobId, 'target_version' => $targetVersion
            ]);
            return null;
        }

        // 3. LƯU THAY ĐỔI
        try {
            DB::transaction(function () use ($jobToUpdate, $reconstructedData, $recruiter) {
                // Chỉ lấy các trường được phép gán
                $fillableData = Arr::only($reconstructedData, $jobToUpdate->getFillable());        
                $jobToUpdate->fill($fillableData);
                
                // Ghi lại thay đổi (tạo version mới)
                // Lưu ý: Rollback cũng là một hành động "thay đổi", nên cần tạo version mới
                if ($jobToUpdate->isDirty()) {
                    $this->versioningService->recordChanges($jobToUpdate);
                    $jobToUpdate->save();
                }
            });

            // Trigger event để sync (nếu cần)
            event(new JobStateChanged($jobToUpdate));

            return $this->getJobDetail($jobId);

        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Rollback DB transaction failed.', [
                'job_id' => $jobId, 'error' => $e->getMessage()
            ]);
            return null;
        }
    }
}