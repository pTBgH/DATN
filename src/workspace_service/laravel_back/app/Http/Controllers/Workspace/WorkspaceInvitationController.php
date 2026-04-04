<?php

namespace App\Http\Controllers\Workspace;

use App\Http\Controllers\Controller;
use App\Models\WorkspaceInvitation;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class WorkspaceInvitationController extends Controller
{
    public function index(): JsonResponse
    {
        $userEmail = Auth::user()->Email;

        if (!$userEmail) {
            return response()->json(['data' => []]);
        }

        $invitations = WorkspaceInvitation::where('email', $userEmail)
            ->where('expires_at', '>', now())
            ->with([
                'workspace.companyProfile', 
                'inviter:RecruiterID,UserName,FirstName,LastName'
            ])
            ->latest('created_at')
            ->get();

        $formatted = $invitations->map(function ($invite) {
            return [
                'invitation_id' => $invite->InvitationID,
                'token'         => $invite->token,
                'expires_at'    => $invite->expires_at,
                'workspace'     => [
                    'workspace_id'   => $invite->workspace->WorkspaceID,
                    'name' => $invite->workspace->companyProfile->CompanyName ?? 'N/A',
                    'logo' => $invite->workspace->companyProfile->PicturePath ?? null,
                ],
                'inviter' => [
                    'inviter_id'   => $invite->inviter->RecruiterID,
                    'name' => $invite->inviter->UserName,
                ],
            ];
        });

        return response()->json($formatted);
    }

    public function reject(string $invitationToken): JsonResponse
    {
        $userEmail = Auth::user()->Email;

        $invitation = WorkspaceInvitation::where('token', $invitationToken)
            ->where('email', $userEmail)
            ->first();

        if (!$invitation) {
            return response()->json(['message' => 'Invitation not found or not for you.'], 404);
        }

        $invitation->delete();

        return response()->json(null, 204); // No Content
    }
}