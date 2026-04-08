<?php

namespace App\Services\Job;

use App\Models\Job\JobJdChange;
use App\Models\Job\JobJdSnapshot;
use App\Models\Job\JobSubJd;
use App\Models\Recruiter\Recruiter;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class JobVersioningService
{
    const SNAPSHOT_EVERY_X_VERSIONS = 10;

    /**
     * Các trường không cần ghi lại lịch sử thay đổi
     */
    private array $ignoredFields = [
        'status', 'pending_data', 'ViewCount', 'ApplyCount', 'Version', 'UpdatedAt', 'CreatedAt'
    ];

    public function recordChanges(JobSubJd $job): void
    {
        // Lấy các trường đã thay đổi, loại bỏ các trường không cần thiết
        $changes = array_diff_key($job->getDirty(), array_flip($this->ignoredFields));

        if (empty($changes)) {
            return; // Không có gì thay đổi -> Không làm gì cả
        }

        $originalData = $job->getOriginal();
        $user = Auth::user();
        $currentVersion = (int)($originalData['Version'] ?? 0);

        // --- Logic tạo Snapshot ban đầu cho Version 1 ---
        // Chỉ chạy một lần duy nhất trong vòng đời của Job
        if ($currentVersion < 1) {
            $this->createInitialSnapshot($job->JobID, $originalData, $user);
            $currentVersion = 1;
            // Gán version 1 vào model nếu nó chưa có để save xuống DB
            if ($job->Version < 1) $job->Version = 1;
        }
        
        $newVersion = $currentVersion + 1;

        try {
            DB::transaction(function () use ($job, $changes, $originalData, $newVersion, $user) {
                
                $changeRecords = [];
                $now = now();
                foreach ($changes as $field => $newValue) {
                    $changeRecords[] = [
                        'ChangeID'  => \Ramsey\Uuid\Uuid::uuid7()->toString(), // Tự sinh UUID
                        'JobID'     => $job->JobID,
                        'Version'   => $newVersion,
                        'Field'     => $field,
                        'OldValue'  => $originalData[$field] ?? null,
                        'NewValue'  => $newValue,
                        'ChangedBy' => $user->RecruiterID ?? ($user->id ?? null),
                        'CreatedAt' => $now,
                    ];
                }
                
                // Tối ưu: Insert nhiều dòng 1 lúc thay vì từng dòng
                if (!empty($changeRecords)) {
                    JobJdChange::insert($changeRecords);
                }

                // Cập nhật version cho job
                $job->Version = $newVersion;

                // Tạo snapshot định kỳ
                if ($newVersion % self::SNAPSHOT_EVERY_X_VERSIONS === 0) {
                    $this->createSnapshot($job, 'auto', $user);
                }
            });

            Log::info("Job version recorded.", [
                'job_id' => $job->JobID, 'new_version' => $newVersion
            ]);

        } catch (\Throwable $e) {
            Log::error("Exception in JobVersioningService@recordChanges", [
                'job_id' => $job->JobID, 'error' => $e->getMessage()
            ]);
            // Ném lại lỗi để transaction bên ngoài (JobService) có thể rollback
            throw $e;
        }
    }
    
    /**
     * Tạo Snapshot đầu tiên (Version 1)
     */
    public function createInitialSnapshot(string $jobId, array $originalData, $user): void
    {
        // Bỏ qua nếu snapshot v1 đã tồn tại
        if (JobJdSnapshot::where('JobID', $jobId)->where('Version', 1)->exists()) {
            return;
        }

        $snapshotData = $originalData;
        $snapshotData['Version'] = 1;

        // Chỉ format date, không gán mặc định (để giữ nguyên giá trị null nếu user không nhập)
        $snapshotData['OpenDate'] = isset($snapshotData['OpenDate']) ? \Carbon\Carbon::parse($snapshotData['OpenDate'])->format('Y-m-d') : null;
        $snapshotData['EndDate'] = isset($snapshotData['EndDate']) ? \Carbon\Carbon::parse($snapshotData['EndDate'])->format('Y-m-d') : null;
        
        // Loại bỏ các trường không cần thiết khỏi snapshot data
        $snapshotData = array_diff_key($snapshotData, array_flip($this->ignoredFields));

        JobJdSnapshot::create([
            'JobID'         => $jobId,
            'Version'       => 1,
            'Data'          => $snapshotData,
            'SnapshotType'  => 'auto',
            'CreatedBy'     => $user->RecruiterID ?? ($user->id ?? null),
            'CreatedAt'     => now(),
        ]);
    }

    /**
     * Tạo Snapshot định kỳ hoặc thủ công
     */
    public function createSnapshot(JobSubJd $job, string $type = 'manual', $user = null): void
    {
        $user = $user ?? Auth::user();

        $snapshotData = array_merge($job->getOriginal(), $job->getDirty());
        
        $snapshotData['OpenDate'] = isset($snapshotData['OpenDate']) ? \Carbon\Carbon::parse($snapshotData['OpenDate'])->format('Y-m-d') : null;
        $snapshotData['EndDate'] = isset($snapshotData['EndDate']) ? \Carbon\Carbon::parse($snapshotData['EndDate'])->format('Y-m-d') : null;
        
        $snapshotData = array_diff_key($snapshotData, array_flip($this->ignoredFields));

        JobJdSnapshot::create([
            'JobID'         => $job->JobID,
            'Version'       => $job->getDirty()['Version'] ?? $job->Version,
            'Data'          => $snapshotData,
            'SnapshotType'  => $type,
            'CreatedBy'     => $user->RecruiterID ?? ($user->id ?? null),
            'CreatedAt'     => now(),
        ]);
    }

    public function reconstructVersion(string $jobId, int $targetVersion): ?array
    {
        Log::channel('daily_normal')->info('Version reconstruction started', ['job_id' => $jobId, 'target' => $targetVersion]);

        $snapshot = JobJdSnapshot::where('JobID', $jobId)
            ->where('Version', '<=', $targetVersion)
            ->orderBy('Version', 'desc')
            ->first();

        if (!$snapshot) {
            Log::channel('daily_error')->error('Rollback failed: No snapshot found.', ['job_id' => $jobId]);
            return null;
        }

        $reconstructedData = $snapshot->Data;
        $startVersion = $snapshot->Version;

        if ($startVersion === $targetVersion) {
            return $reconstructedData;
        }

        // Lấy các thay đổi từ version của snapshot đến version mục tiêu
        $changes = JobJdChange::where('JobID', $jobId)
            ->where('Version', '>', $startVersion)
            ->where('Version', '<=', $targetVersion)
            ->orderBy('Version', 'asc')
            ->get();

        foreach ($changes as $change) {
            $reconstructedData[$change->Field] = $change->NewValue;
        }

        Log::channel('daily_normal')->info('Version reconstruction successful', ['job_id' => $jobId]);

        return $reconstructedData;
    }
}