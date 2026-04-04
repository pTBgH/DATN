<?php

namespace App\Services\Workspace;

use App\Enums\CandidatePermission;
use App\Enums\JobPermission;
use App\Enums\PipelinePermission;
use App\Enums\WorkspacePermission;
use App\Models\Job\JobCompany;
use App\Models\RctPlan;
use App\Models\Recruiter\Recruiter;
use App\Models\Sys\SysLocation;
use App\Models\Workspace;
use App\Services\Job\JobService;
use App\Enums\JobStatusEnum;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Ramsey\Uuid\Uuid;
use Throwable;

class WorkspaceService
{
    protected JobService $jobService;

    public function __construct(JobService $jobService)
    {
        $this->jobService = $jobService;
    }

    public function createNewWorkspace(array $data, Recruiter $creator): Workspace
    {
        return DB::transaction(function () use ($data, $creator) {
            
            // 1. Xử lý Location
            $locationId = null;
            if (!empty($data['location'])) {
                $location = SysLocation::create(['DetailLocation' => $data['location']]);
                $locationId = $location->LocationID;
            }

            // 2. Lấy Plan mặc định (Standard)
            $defaultPlan = RctPlan::where('PlanCode', 'standard')->first();

            // 3. Tạo Workspace
            // Lưu ý: WorkspaceID được tạo mới tại đây
            $workspace = Workspace::create([
                'WorkspaceID' => Uuid::uuid7()->toString(),
                'Email' => $data['email'] ?? null,
                'PlanID' => $defaultPlan ? $defaultPlan->PlanID : 1,
            ]);

            // 4. Tạo Company Profile
            JobCompany::create([
                'CompanyID' => $workspace->WorkspaceID,
                'CompanyName' => $data['name'],
                'LocationID' => $locationId,
                'SizeID' => $data['size_id'] ?? null,
                'IndustryID' => $data['industry_id'] ?? null,
                'IsActive' => true,
            ]);

            // 5. Gán quyền cho người tạo (Owner)
            // QUAN TRỌNG: Chỉ gán quyền STANDARD, không gán quyền SYSTEM.
            $workspace->members()->attach($creator->RecruiterID, [
                // Các cột mới theo chuẩn snake_case
                'workspace_permissions' => WorkspacePermission::getStandardMask(),
                'job_permissions'       => JobPermission::getStandardMask(),
                
                // Giả định Candidate và Pipeline cũng có logic tương tự
                'candidate_permissions' => CandidatePermission::getStandardMask() ?? -1, 
                'pipeline_permissions'  => PipelinePermission::getStandardMask() ?? -1,
                
                'status_id'             => 1, // Active
                // created_at, updated_at tự động
            ]);

            Log::channel('daily_normal')->info('Workspace created successfully.', [
                'workspace_id' => $workspace->WorkspaceID,
                'creator_id' => $creator->RecruiterID
            ]);
            
            return $workspace->load([
                'plan', 
                'companyProfile.size', 
                'companyProfile.industry',
                'companyProfile.location.city',
                'companyProfile.location.district'
            ]);
        });
    }

    /**
     * Cập nhật thông tin Workspace/Company.
     */
    public function updateWorkspaceAndCompany(Workspace $workspace, array $data): Workspace
    {
        $company = $workspace->companyProfile;

        if (!$company) {
            $company = JobCompany::create([
                'CompanyID' => $workspace->WorkspaceID,
                'CompanyName' => $data['name'] ?? 'Untitled Company',
                'IsActive' => true,
            ]);
        }

        DB::transaction(function () use ($company, $data) {
            $companyUpdateData = [];

            if (isset($data['name'])) $companyUpdateData['CompanyName'] = $data['name'];
            if (isset($data['logo'])) $companyUpdateData['PicturePath'] = $data['logo'];
            if (isset($data['size_id'])) $companyUpdateData['SizeID'] = $data['size_id'];
            if (isset($data['industry_id'])) $companyUpdateData['IndustryID'] = $data['industry_id'];

            if (isset($data['location'])) {
                if ($company->LocationID) {
                    SysLocation::where('LocationID', $company->LocationID)
                        ->update(['DetailLocation' => $data['location']]);
                } else {
                    $newLocation = SysLocation::create(['DetailLocation' => $data['location']]);
                    $companyUpdateData['LocationID'] = $newLocation->LocationID;
                }
            }

            if (!empty($companyUpdateData)) {
                $company->update($companyUpdateData);
            }
        });

        Log::channel('daily_normal')->info('Workspace updated.', ['workspace_id' => $workspace->WorkspaceID]);

        return $workspace->fresh([
            'plan', 'companyProfile.size', 'companyProfile.industry', 
            'companyProfile.location.city', 'companyProfile.location.district'
        ]);
    }

    /**
     * Xóa Workspace.
     */
    public function deleteWorkspaceAndCompany(Workspace $workspace)
    {
        $workspaceId = $workspace->WorkspaceID;

        try {
            DB::transaction(function () use ($workspace, $workspaceId) {
                $company = JobCompany::find($workspaceId);

                if ($company) {
                    $locationId = $company->LocationID;
                    $company->delete();
                    if ($locationId) {
                        SysLocation::destroy($locationId);
                    }
                }
                
                $workspace->delete(); // Cascade xóa members, permissions
            });

            Log::channel('daily_normal')->info("Workspace deleted.", [
                'workspace_id' => $workspaceId,
                'user_id' => Auth::id()
            ]);

        } catch (Throwable $e) {
            Log::channel('daily_error')->error('Failed to delete workspace.', [
                'workspace_id' => $workspaceId,
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    public function getWorkspacesFor(Recruiter $recruiter): Collection
    {
        // 1. Chỉ cần lấy các workspace user thuộc về, kèm các quan hệ cơ bản
        $workspaces = $recruiter->workspaces()
            ->with([
                'plan',
                'companyProfile', // Chỉ cần companyProfile, không cần join sâu
            ])
            ->get();

        // Nếu user không thuộc workspace nào, trả về collection rỗng
        if ($workspaces->isEmpty()) {
            return $workspaces;
        }

        // 2. Gán các thuộc tính cần thiết từ BẢNG TRUNG GIAN (PIVOT)
        // Không cần query SQL phức tạp để lấy stats nữa
        $workspaces->each(function (Workspace $workspace) {
            
            // Lấy dữ liệu từ pivot
            $pivot = $workspace->pivot;

            // Gán object permissions
            $workspace->permissions = [
                'workspace' => (int) $pivot->workspace_permissions,
                'job'       => (int) $pivot->job_permissions,
                'candidate' => (int) $pivot->candidate_permissions,
                'pipeline'  => (int) $pivot->pipeline_permissions,
            ];
            
            // Gán trạng thái của thành viên
            $workspace->member_status = (int) $pivot->status_id;

            // Các thuộc tính stats sẽ để mặc định là null hoặc 0
            // Resource sẽ xử lý việc này
            $workspace->active_jobs = null;
            $workspace->views = null;
            $workspace->applications = null;
        });

        return $workspaces;
    }

    public function getWorkspaceDetails(Workspace $workspace, Recruiter $recruiter): Workspace
    {
        $workspace->load([
            'plan',
            'companyProfile.size',
            'companyProfile.industry',
            'companyProfile.location.city', 
            'companyProfile.location.district', 
        ]);

        $workspaceId = $workspace->WorkspaceID;
        
        // Lấy quyền cụ thể của user này trong workspace này từ bảng members
        // Lưu ý: Cần lấy 4 cột mới
        $member = DB::table('workspace_members')
            ->where('WorkspaceID', $workspaceId)
            ->where('RecruiterID', $recruiter->RecruiterID)
            ->first();

        // Map vào object permissions để Resource trả về FE
        $workspace->permissions = $member ? [
            'workspace' => (int)$member->workspace_permissions,
            'job'       => (int)$member->job_permissions,
            'candidate' => (int)$member->candidate_permissions,
            'pipeline'  => (int)$member->pipeline_permissions,
        ] : null;

        // (Thêm logic thống kê view/apply count vào đây nếu cần)
        
        return $workspace;
    }
}