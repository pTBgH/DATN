<?php

namespace App\Services\Job;

use App\Enums\JobStatusEnum;
use App\Events\JobStateChanged;
use App\Models\Job\JobSubJd;
use App\Services\CompanyDataEnricher; // <--- Dùng cái này để lấy tên công ty
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class JobStatusServicev2
{
    protected CompanyDataEnricher $enricher;

    // Inject Enricher thay vì ActivityLogService (để tránh lỗi dependency)
    public function __construct(CompanyDataEnricher $enricher)
    {
        $this->enricher = $enricher;
    }

    private function handleAction(string $actionName, string $jobId, ?string $companyId, callable $logic, bool $isAdmin = false): array
    {
        try {
            $query = JobSubJd::where('JobID', $jobId);

            // Nếu không phải Admin, bắt buộc check CompanyID
            if (!$isAdmin) {
                if (empty($companyId)) {
                     return ['success' => false, 'message' => 'Workspace context is required.', 'code' => 400];
                }
                $query->where('CompanyID', $companyId);
            }
            
            $job = $query->first();

            if (!$job) {
                return ['success' => false, 'message' => 'Job not found or unauthorized.', 'code' => 404];
            }

            return DB::transaction(function () use ($job, $logic) {
                // 1. Thực thi logic chuyển trạng thái
                $message = $logic($job);
                
                // 2. Nếu có thay đổi -> Lưu và bắn Event (để sync sang job_jds)
                if ($job->isDirty()) {
                    $job->save();
                    event(new JobStateChanged($job));
                }

                // 3. [QUAN TRỌNG] Thay thế $job->load('companyInfo') bằng Enricher
                // Vì Job Service không có bảng companies
                $this->enricher->enrichOne($job);
                
                // Load quan hệ nội bộ (jobStat vẫn nằm trong Job Service nên load được)
                $job->load(['jobStat']);

                return ['success' => true, 'message' => $message, 'job' => $job];
            });

        } catch (Throwable $e) {
            Log::channel('daily_error')->error("[JobStatusService] @{$actionName} Failed", [
                'job_id' => $jobId, 
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            return ['success' => false, 'message' => 'Error: ' . $e->getMessage(), 'code' => 500];
        }
    }

    // =================================================================
    // ===== USER ACTIONS (Recruiter) =====
    // =================================================================

    public function submit(string $jobId, string $companyId): array
    {
        return $this->handleAction('submit', $jobId, $companyId, function (JobSubJd $job) {
            // Chỉ được submit từ: Draft, Rejected, Expired
            $allowed = [JobStatusEnum::DRAFT, JobStatusEnum::REJECTED, JobStatusEnum::EXPIRED];
            
            if (!in_array($job->status, $allowed)) {
                throw new \Exception('Job cannot be submitted from status: ' . $job->status->label());
            }

            $job->status = JobStatusEnum::PENDING; // <-- Enum mới
            
            return 'Job submitted for approval.';
        });
    }

    public function unpublish(string $jobId, string $companyId): array
    {
        return $this->handleAction('unpublish', $jobId, $companyId, function (JobSubJd $job) {
            if ($job->status !== JobStatusEnum::PUBLISHED) {
                throw new \Exception('Only published jobs can be unpublished.');
            }
            $job->status = JobStatusEnum::DRAFT; 
            return 'Job unpublished and moved to drafts.';
        });
    }

    public function archive(string $jobId, string $companyId): array
    {
        return $this->handleAction('archive', $jobId, $companyId, function (JobSubJd $job) {
            $job->status = JobStatusEnum::ARCHIVED;
            return 'Job archived.';
        });
    }

    public function restore(string $jobId, string $companyId): array
    {
        return $this->handleAction('restore', $jobId, $companyId, function (JobSubJd $job) {
            if ($job->status !== JobStatusEnum::ARCHIVED) {
                throw new \Exception('Only archived jobs can be restored.');
            }
            $job->status = JobStatusEnum::DRAFT;
            return 'Job restored to drafts.';
        });
    }

    public function close(string $jobId, string $companyId): array
    {
        // Thêm hàm này vì route api có gọi
        return $this->handleAction('close', $jobId, $companyId, function (JobSubJd $job) {
             if ($job->status === JobStatusEnum::EXPIRED) {
                throw new \Exception('Job is already expired/closed.');
            }
            $job->status = JobStatusEnum::EXPIRED;
            return 'Job closed/expired.';
        });
    }

    // =================================================================
    // ===== ADMIN ACTIONS (Không cần CompanyID) =====
    // =================================================================

    public function approve(string $jobId): array
    {
        return $this->handleAction('approve', $jobId, null, function (JobSubJd $job) {
            
            if ($job->status !== JobStatusEnum::PENDING) {
                throw new \Exception('Job is not in Pending state.');
            }

            // Sinh Slug nếu chưa có
            if (empty($job->slug)) {
                $baseSlug = Str::slug($job->Title);
                $randomSuffix = Str::lower(Str::random(6));
                $slug = "{$baseSlug}-{$randomSuffix}";
                
                // Retry nếu trùng
                while (JobSubJd::where('slug', $slug)->exists()) {
                    $randomSuffix = Str::lower(Str::random(6));
                    $slug = "{$baseSlug}-{$randomSuffix}";
                }
                $job->slug = $slug;
            }
            
            // Set ngày đăng nếu chưa có
            if (!$job->OpenDate) {
                $job->OpenDate = now();
            }
            
            $job->status = JobStatusEnum::PUBLISHED;

            // Thay ActivityLog bằng Log thường để tránh crash
            Log::info("Admin approved Job {$job->JobID}");

            return 'Job approved and published.';

        }, true); // true = isAdmin
    }

    public function reject(string $jobId, ?string $reason): array
    {
        return $this->handleAction('reject', $jobId, null, function (JobSubJd $job) use ($reason) {
            
            // Admin có thể reject khi đang Pending hoặc thậm chí đang Published (gỡ bài)
            $allowed = [JobStatusEnum::PENDING, JobStatusEnum::PUBLISHED];
            
            if (!in_array($job->status, $allowed)) {
                throw new \Exception('Job cannot be rejected from status: ' . $job->status->label());
            }
            
            $job->status = JobStatusEnum::REJECTED;
            
            // Log lý do
            Log::info("Admin rejected Job {$job->JobID}. Reason: {$reason}");

            return 'Job has been rejected.';

        }, true);
    }    
}