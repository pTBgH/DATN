<?php

namespace App\Http\Controllers\Hiring;

use App\Http\Controllers\Controller;
use App\Models\Job\JobApplication;
use App\Models\Hiring\Scorecard;
use App\Http\Resources\Hiring\ScorecardResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;

class ScorecardController extends Controller
{
    public function store(Request $request, string $applicationId)
    {
        $validated = $request->validate([
            'score_data' => 'required|array',
            'comment'    => 'nullable|string',
        ]);

        $app = JobApplication::where('ApplicationID', $applicationId)->firstOrFail();
        
        // Lấy thông tin người đang login
        $user = Auth::user(); 

        $scorecard = Scorecard::create([
            'ApplicationID' => $app->ApplicationID,
            
            // Snapshot thông tin người chấm
            'InterviewerID'   => $user->getAuthIdentifier(), // hoặc $user->id
            'InterviewerName' => $user->name ?? $user->email ?? 'Unknown', // Lấy tên từ Token
            
            'ScoreJson'     => $validated['score_data'],
            'Comment'       => $validated['comment'] ?? null,
            'CreatedAt'     => now(),
        ]);

        return response()->json(new ScorecardResource($scorecard), 201);
    }

    public function index(string $applicationId)
    {
        $scorecards = Scorecard::where('ApplicationID', $applicationId)
            ->orderBy('CreatedAt', 'desc')
            ->get();

        return ScorecardResource::collection($scorecards);
    }
}