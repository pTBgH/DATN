<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Enums\SystemRole;

class RecruiterResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // 1. Dữ liệu cơ bản (Luôn có)
        $data = [
            'recruiter_id' => $this->RecruiterID,
            'email'        => $this->Email,
            'phone_number' => $this->PhoneNumber,
            'user_name'    => $this->UserName,
            'first_name'   => $this->FirstName,
            'last_name'    => $this->LastName,
        ];

        // 2. TRƯỜNG HỢP A: Đang xem danh sách thành viên trong 1 Workspace
        // (Dữ liệu quyền hạn nằm ở $this->pivot)
        if ($this->pivot) {
            $roleData = $this->calculateRoleData($this->pivot);
            
            // Merge thông tin Role vào root của JSON
            $data = array_merge($data, [
                'role_keys'   => $roleData['role_keys'],
                'role_label'  => $roleData['role_label'],
                'permissions' => $roleData['permissions'],
                'status_id'   => $this->pivot->status_id,
                'joined_at'   => $this->pivot->created_at,
            ]);
        }

        // 3. TRƯỜNG HỢP B: Đang xem Profile cá nhân (User -> Many Workspaces)
        // (Dữ liệu quyền hạn nằm trong relation workspaces)
        $data['workspaces'] = $this->whenLoaded('workspaces', function () {
            return $this->workspaces->map(function ($workspace) {
                
                $pivot = $workspace->pivot;
                $roleData = $this->calculateRoleData($pivot);

                return [
                    'workspace_id' => $workspace->WorkspaceID,
                    'name'         => $workspace->Name,
                    'logo'         => $workspace->Logo,
                    
                    'role_keys'    => $roleData['role_keys'],
                    'role_label'   => $roleData['role_label'],
                    'permissions'  => $roleData['permissions'],
                    
                    'status_id'    => $pivot->status_id,
                    'joined_at'    => $pivot->created_at,
                ];
            });
        });

        return $data;
    }

    /**
     * Helper tách biệt logic tính toán Role để tái sử dụng
     */
    private function calculateRoleData($pivot): array
    {
        // Lấy dữ liệu thô từ DB
        $perms = [
            'workspace' => (int) $pivot->workspace_permissions,
            'job'       => (int) $pivot->job_permissions,
            'candidate' => (int) $pivot->candidate_permissions,
            'pipeline'  => (int) $pivot->pipeline_permissions,
        ];

        // Logic suy diễn
        $inference = SystemRole::inferRoles($perms);

        // Tạo Label
        $roleKeys = [];
        $roleLabels = [];

        foreach ($inference['roles'] as $roleEnum) {
            $roleKeys[] = $roleEnum->value;
            $roleLabels[] = $roleEnum->label();
        }

        if (empty($roleLabels)) {
            $displayLabel = 'Custom';
        } else {
            $displayLabel = implode(', ', $roleLabels);
            if ($inference['is_custom']) {
                $displayLabel .= ' (+Custom)';
            }
        }

        return [
            'role_keys'   => $roleKeys,
            'role_label'  => $displayLabel,
            'permissions' => $perms,
        ];
    }
}