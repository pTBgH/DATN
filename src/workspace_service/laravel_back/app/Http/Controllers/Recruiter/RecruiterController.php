<?php

namespace App\Http\Controllers\Recruiter;

use App\Http\Controllers\Controller;
use App\Services\Recruiter\RecruiterService;
use App\Http\Resources\RecruiterResource;
use App\Models\Recruiter\Recruiter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class RecruiterController extends Controller
{
    private $recruiterService;

    public function __construct(RecruiterService $recruiterService)
    {
        $this->recruiterService = $recruiterService;
    }

    public function store(Request $request)
    {
        $recruiter = Recruiter::find(Auth::id());
        if (!$recruiter) {
            return response()->json(['message' => 'Authentication failed.'], 401);
        }

        $validatedData = $request->validate([
            'company_id' => 'nullable|string|max:64',
            'job_title' => 'nullable|string|max:255',
        ]);

        $recruiter->update($validatedData);

        return new RecruiterResource($recruiter);
    }

    public function update(Request $request)
    {
        $recruiter = Recruiter::find(Auth::id());

        // Validate với các key snake_case
        $validatedData = $request->validate([
            'user_name' => 'sometimes|nullable|string|max:255',
            'phone_number' => 'sometimes|nullable|string|max:20',
            'first_name' => 'sometimes|nullable|string|max:100',
            'last_name' => 'sometimes|nullable|string|max:100',
        ]);
        
        Log::channel('daily_normal')->info('Updating recruiter profile.', ['recruiter_id' => $recruiter->RecruiterID, 'data' => $validatedData]);

        // Cứ truyền thẳng dữ liệu snake_case vào service
        $updatedRecruiter = $this->recruiterService->updateProfile($recruiter, $validatedData);

        return new RecruiterResource($updatedRecruiter);
    }

    public function getMyProfile()
    {
        $recruiter = Recruiter::find(Auth::id());
        // ->load('workspaces');

        if (!$recruiter) {
            return response()->json(['message' => 'Recruiter profile not found for this user.'], 404);
        }

        $recruiter->load(['workspaces']); 

        return new RecruiterResource($recruiter);
    }

    public function requestApproval()
    {
        $recruiter = Recruiter::find(Auth::id());
        $updatedRecruiter = $this->recruiterService->requestApproval($recruiter);

        if (!$updatedRecruiter) {
            return response()->json(['message' => 'Invalid state to request approval.'], 409);
        }

        return new RecruiterResource($updatedRecruiter);
    }

    public function updateInterestedSectors(Request $request)
    {
        $recruiter = Recruiter::find(Auth::id());
        
        $validated = $request->validate([
            'sectors' => 'required|array',
            'sectors.*' => 'integer|exists:job_sectors,JobSectorID',
        ]);
        
        $updatedRecruiter = $this->recruiterService->updateInterestedSectors($recruiter, $validated['sectors']);

        // if (!$updatedRecruiter) {
        //     return response()->json(['message' => 'Your account must be approved to perform this action.'], 403);
        // }

        return new RecruiterResource($updatedRecruiter);
    }

    // Hàm tạo profile sẽ được gọi ở đâu đó sau khi user đăng ký trên Keycloak
    // hoặc có thể tạo một endpoint riêng.
}