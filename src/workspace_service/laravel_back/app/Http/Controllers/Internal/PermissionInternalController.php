<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

class PermissionInternalController extends Controller
{
    public function getUserPermissions($workspaceId, $userId)
    {
        // Query trực tiếp bảng trung gian workspace_members
        $member = DB::table('workspace_members')
            ->where('WorkspaceID', $workspaceId)
            ->where('RecruiterID', $userId)
            ->first();

        if (!$member) {
            // Trả về full 0 (Không có quyền)
            return response()->json(['workspace' => 0, 'job' => 0, 'candidate' => 0, 'pipeline' => 0]);
        }

        return response()->json([
            'workspace' => (int)$member->workspace_permissions,
            'job'       => (int)$member->job_permissions,
            'candidate' => (int)$member->candidate_permissions,
            'pipeline'  => (int)$member->pipeline_permissions,
        ]);
    }
}