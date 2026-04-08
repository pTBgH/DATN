<?php

namespace App\Http\Controllers\Workspace;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Traits\HasPermissionValidation;
use App\Models\Recruiter\Recruiter;
use App\Http\Resources\RecruiterResource;
use App\Models\Workspace;
use App\Services\Workspace\WorkspaceMemberService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;

class WorkspaceMemberController extends Controller
{
    use HasPermissionValidation; 

    private WorkspaceMemberService $memberService;

    public function __construct(WorkspaceMemberService $memberService)
    {
        $this->memberService = $memberService;
    }

    public function index(Workspace $workspace): JsonResponse
    {
        $members = $this->memberService->getMembers($workspace);
        return RecruiterResource::collection($members)->response();
    }

    public function indexPending(Workspace $workspace): JsonResponse
    {
        $members = $this->memberService->getPendingMembers($workspace);
        return RecruiterResource::collection($members)->response();
    }

    public function createInviteCode(Request $request, Workspace $workspace): JsonResponse
    {
        $validated = $request->validate([
            'expires_in_hours' => 'nullable|integer|min:1',
        ]);

        $invitation = $this->memberService->createInvitationCode(
            $workspace,
            Auth::user(),
            $validated['expires_in_hours'] ?? 48
        );

        return response()->json([
            'ivitetation_id'         => $invitation->InvitationID,
            'code'       => $invitation->code,
            'expires_at' => $invitation->expires_at,
        ], 201);
    }

    public function inviteViaMail(Request $request, Workspace $workspace): JsonResponse
    {
        $invitations = $request->all();
        if (!is_array($invitations)) return response()->json(['message' => 'Must be array'], 400);

        $rules = array_merge(
            ['*.email' => 'required|email|max:255'],
            $this->getPermissionRules('*.') 
        );

        $validator = Validator::make($invitations, $rules);
        if ($validator->fails()) return response()->json(['errors' => $validator->errors()], 422);

        $this->memberService->inviteMembers($workspace, Auth::user(), $validator->validated());

        return response()->json(['message' => 'Invitations sent.']);
    }

    public function updateMember(Request $request, Workspace $workspace, string $recruiterId): JsonResponse
    {
        Log::channel('daily_normal')->info('Updating permission for a single member.', [
            'workspace_id' => $workspace->WorkspaceID,
            'admin_id'     => Auth::id(),
            'target_id'    => $recruiterId
        ]);
        
        $rules = $this->getPermissionRules();
        $validator = Validator::make($request->all(), $rules);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $memberData = [
            array_merge(
                ['recruiter_id' => $recruiterId], 
                $validator->validated()
            )
        ];

        $result = $this->memberService->updateMembersPermissions($workspace, Auth::user(), $memberData);
        if ($result['success']) {
            return response()->json(['message' => $result['message']]);
        }
        return response()->json(['message' => $result['message']], 500);
    }

    public function removeMember(Workspace $workspace, Recruiter $recruiter): JsonResponse
    {
        $result = $this->memberService->removeMember($workspace, Auth::user(), $recruiter);
        if ($result['success']) return response()->json(null, 204);
        return response()->json(['message' => $result['message']], 500);
    }

    public function joinByCode(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|string|size:6',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        // Gọi Service
        $result = $this->memberService->joinWithCode(
            strtoupper($request->input('code')), 
            Auth::user()
        );

        if (!$result['success']) {
            return response()->json([
                'success' => false,
                'message' => $result['message']
            ], $result['code']);
        }
        $responseData = [
            'success' => true,
            'message' => $result['message'],
            'workspace' => isset($result['workspace']) 
                ? new \App\Http\Resources\WorkspaceResource($result['workspace']) 
                : null
        ];
        
        return response()->json($responseData, 200);
    }

    public function accept(Request $request): JsonResponse
    {
        $validated = $request->validate(['token' => 'required|string|size:40']);
        $result = $this->memberService->acceptInvitation($validated['token'], Auth::user());

        if ($result['success']) {
            return response()->json([
                'success' => true,
                'message' => $result['message'],
                'workspace' => new \App\Http\Resources\WorkspaceResource($result['workspace'])
            ]);
        }
        return response()->json(['message' => $result['message']], 422);
    }
}