<?php

namespace App\Services\Workspace;

use Illuminate\Contracts\Auth\Authenticatable;
use App\Enums\CandidatePermission;
use App\Enums\JobPermission;
use App\Enums\PipelinePermission;
use App\Enums\WorkspacePermission;
use App\Services\Kafka\KafkaHelper;
use App\Models\Recruiter\Recruiter;
use App\Models\Workspace;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Ramsey\Uuid\Uuid;
use Throwable;

class WorkspaceService
{
    protected KafkaHelper $kafkaHelper;

    public function __construct(KafkaHelper $kafkaHelper)
    {
        $this->kafkaHelper = $kafkaHelper;
    }

    public function createNewWorkspace(array $data, Authenticatable $creator): Workspace
    {
        return DB::transaction(function () use ($data, $creator) {
            
            // 1. Tạo UUID
            $workspaceId = Uuid::uuid7()->toString();
            
            // 2. Tạo Workspace Local
            // Lưu ý: Bỏ PlanID logic (hoặc gán mặc định 1) và không query bảng rct_plans
            $workspace = Workspace::create([
                'WorkspaceID' => $workspaceId,
                'Name'        => $data['name'],
                'Logo'        => $data['logo'] ?? null,
                'Email'       => $data['email'] ?? $creator->email ?? null,
            ]);

            // 3. Chuẩn bị Payload Kafka -> Gửi sang Job Service
            $kafkaPayload = [
                'event_type' => 'workspace.created',
                'timestamp'  => now()->toIso8601String(),
                'data' => [
                    'workspace_id' => $workspaceId,
                    'name'         => $data['name'],
                    'logo'         => $data['logo'] ?? null,
                    'email'        => $workspace->Email,
                    'city'         => $data['city'] ?? null,
                    'district'     => $data['district'] ?? null,
                    'location'     => $data['location'] ?? null,    // String địa chỉ
                    'size'         => $data['size'] ?? null,        // ID
                    'industry'     => $data['industry'] ?? null,    // ID
                    'website'      => $data['website'] ?? null,
                    'created_by'   => $creator->internal_id ?? $creator->id
                ]
            ];

            try {
                $this->kafkaHelper->produce('job7189.workspace', $kafkaPayload);
                (new StructuredLogger('system', 'action'))->info(['message' => "Kafka [workspace.created] sent", ['ws_id' => $workspaceId]);
            } catch (Throwable $e) {
                // Log lỗi nhưng không rollback DB để tránh chặn user
                (new StructuredLogger('system', 'error'))->error(['message' => "Kafka Publish Failed: " . $e->getMessage());
            }
            DB::table('workspace_members')->insert([
                'WorkspaceID' => $workspaceId,
                'RecruiterID' => $creator->internal_id ?? $creator->id,
                'workspace_permissions' => WorkspacePermission::getStandardMask(),
                'job_permissions'       => JobPermission::getStandardMask(),
                'candidate_permissions' => CandidatePermission::getStandardMask(),
                'pipeline_permissions'  => PipelinePermission::getStandardMask(),
                'status_id'  => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            // --- BỔ SUNG ĐOẠN NÀY ĐỂ API TRẢ VỀ KHÔNG BỊ NULL ---
            $workspace->permissions = [
                'workspace' => WorkspacePermission::getStandardMask(),
                'job'       => JobPermission::getStandardMask(),
                'candidate' => CandidatePermission::getStandardMask(),
                'pipeline'  => PipelinePermission::getStandardMask(),
            ];
            $workspace->member_status = 1; 
            // ---------------------------------------------------

            (new StructuredLogger('system', 'action'))->info(['message' => 'Workspace created.', ['ws_id' => $workspaceId]);
            
            return $workspace;
        });
    }

    public function updateWorkspace(Workspace $workspace, array $data): Workspace
    {
        return DB::transaction(function () use ($workspace, $data) {
            
            // 1. Cập nhật Local (Chỉ Name, Logo)
            $localUpdate = [];
            if (isset($data['name'])) $localUpdate['Name'] = $data['name'];
            if (isset($data['logo'])) $localUpdate['Logo'] = $data['logo'];
            
            if (!empty($localUpdate)) {
                $workspace->update($localUpdate);
            }

            // 2. Bắn Kafka sang Job Service (Update Company Info)
            $kafkaPayload = [
                'event_type' => 'workspace.updated',
                'timestamp'  => now()->toIso8601String(),
                'data' => array_merge(['workspace_id' => $workspace->WorkspaceID], $data)
            ];

            try {
                $this->kafkaHelper->produce('job7189.workspace', $kafkaPayload);
            } catch (Throwable $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Kafka Update Failed: " . $e->getMessage());
            }

            return $workspace;
        });
    }

    public function deleteWorkspace(Workspace $workspace)
    {
        $workspaceId = $workspace->WorkspaceID;

        try {
            // 1. Xóa Local (Cascade xóa members)
            $workspace->delete();

            // 2. Bắn Kafka (Optional: để Job Service xóa/ẩn Company)
            // $this->kafkaHelper->produce...

            (new StructuredLogger('system', 'action'))->info(['message' => "Workspace deleted.", ['ws_id' => $workspaceId]);

        } catch (Throwable $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => 'Failed to delete workspace.', [
                'ws_id' => $workspaceId,
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    public function getWorkspacesFor(Authenticatable $recruiter): Collection
    {
        $workspaces = $recruiter->workspaces()->get();

        if ($workspaces->isEmpty()) return $workspaces;

        $workspaces->each(function (Workspace $workspace) {
            $pivot = $workspace->pivot;
            $workspace->permissions = [
                'workspace' => (int) $pivot->workspace_permissions,
                'job'       => (int) $pivot->job_permissions,
                'candidate' => (int) $pivot->candidate_permissions,
                'pipeline'  => (int) $pivot->pipeline_permissions,
            ];
            $workspace->member_status = (int) $pivot->status_id;
        });

        return $workspaces;
    }

    public function getWorkspaceDetails(Workspace $workspace, Authenticatable $recruiter): Workspace
    {
        // Vì bảng job_companies không còn ở đây, ta không load relationship companyProfile nữa
        // Frontend sẽ dùng Name/Logo từ bảng workspaces
        
        $member = DB::table('workspace_members')
            ->where('WorkspaceID', $workspace->WorkspaceID)
            ->where('RecruiterID', $recruiter->internal_id ?? $recruiter->id)
            ->first();

        $workspace->permissions = $member ? [
            'workspace' => (int)$member->workspace_permissions,
            'job'       => (int)$member->job_permissions,
            'candidate' => (int)$member->candidate_permissions,
            'pipeline'  => (int)$member->pipeline_permissions,
        ] : null;

        return $workspace;
    }
}