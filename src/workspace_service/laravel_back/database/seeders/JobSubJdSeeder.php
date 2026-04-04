<?php

namespace Database\Seeders;

use App\Enums\JobStatusEnum;
use App\Models\Job\JobSubJd;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use App\Events\JobStateChanged;

class JobSubJdSeeder extends Seeder
{
    public function run(): void
    {
        // ID Workspace (lấy từ log lỗi của bạn để tiện copy)
        $testCompanyId = '019b2171-f288-7280-8a10-da18adce4053'; 

        $this->command->info("Creating test jobs for CompanyID: {$testCompanyId}...");

        $commonData = ['CompanyID' => $testCompanyId];

        // 1. Tạo Published Jobs (Gán vào biến $publishedJobs)
        $publishedJobs = JobSubJd::factory()
            ->count(0)
            ->withRandomForeignKeys()
            ->create(array_merge($commonData, ['status' => JobStatusEnum::PUBLISHED]));

        // 2. Tạo Pending Update Jobs (QUAN TRỌNG: Gán vào biến $pendingUpdateJobs)
        $pendingUpdateJobs = JobSubJd::factory()
            ->count(0)
            ->withRandomForeignKeys()
            ->pendingUpdate()
            ->create(array_merge($commonData, ['status' => JobStatusEnum::PENDING]));

        // 3. Tạo các loại khác (Không cần gán biến vì không sync)
        JobSubJd::factory()->count(30)->withRandomForeignKeys()
            ->create(array_merge($commonData, ['status' => JobStatusEnum::PENDING]));

        JobSubJd::factory()->count(30)->withRandomForeignKeys()
            ->create(array_merge($commonData, ['status' => JobStatusEnum::DRAFT]));

        JobSubJd::factory()->count(0)->withRandomForeignKeys()
            ->create(array_merge($commonData, ['status' => JobStatusEnum::DRAFT]));

        // --- ĐỒNG BỘ SANG BẢNG PUBLIC ---
        $this->command->info("Syncing to job_jds...");
        
        // Gộp 2 collection lại để sync. Bây giờ biến $pendingUpdateJobs đã tồn tại nên sẽ không lỗi nữa.
        $jobsToSync = $publishedJobs->merge($pendingUpdateJobs);

        $this->command->withProgressBar($jobsToSync, function ($job) {
            // Trigger Event để Listener chạy logic sync sang bảng job_jds
            event(new JobStateChanged($job));
        });

        $this->command->newLine();
        $this->command->info('Done!');
    }
}