<?php

namespace App\Http\Controllers\Recruiter;

use App\Http\Controllers\Controller;
use App\Services\Recruiter\InteractionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use App\Services\Cv\CvQueryService;
use Illuminate\Http\JsonResponse;

class InteractionController extends Controller
{
    private $interactionService;
    private $cvQueryService;

    public function __construct(
        InteractionService $interactionService, 
        CvQueryService $cvQueryService)
    {
        $this->interactionService = $interactionService;
        $this->cvQueryService = $cvQueryService;
    }

    public function setSaved(Request $request)
    {
        $validated = $request->validate([
            'job_id'   => 'required|string|max:24',
            'is_saved' => 'required|boolean',
        ]);

        try {
            $interactedJob = $this->interactionService->setJobSaved(
                Auth::id(),
                $validated['job_id'],
                $validated['is_saved']
            );

            $job = $this->cvQueryService->getOneJobById($validated['job_id'], Auth::id());
            $action = $validated['is_saved'] ? 'save' : 'unsave';
            $this->cvQueryService->trackJobInteraction($validated['job_id'], $action);

            return response()->json([
                'data' => $job
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'An error occurred while updating status.',
                $e->getMessage()
            ], 500);
        }
    }

    public function setHidden(Request $request)
    {
        $validated = $request->validate([
            'job_id'   => 'required|string|max:24',
            'is_hidden' => 'required|boolean',
        ]);

        try {
            $interaction = $this->interactionService->setJobHidden(
                Auth::id(),
                $validated['job_id'],
                $validated['is_hidden']
            );

            return response()->json([
                'message' => 'Hidden status updated successfully.',
                'data' => $interaction
            ], 200);

        } catch (\Exception $e) {
            return response()->json(['message' => 'An error occurred while updating status.'], 500);
        }
    }

    public function getSavedJobIds(): JsonResponse
    {
        $user = Auth::user();

        $savedJobIds = $this->interactionService->getSavedJobIds($user->id);

        return response()->json([
            'job_saved' => $savedJobIds
        ]);
    }

}