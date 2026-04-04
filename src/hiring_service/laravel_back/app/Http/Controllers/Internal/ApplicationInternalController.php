<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Models\Job\JobApplication;
use App\Models\Hiring\HiringPipeline;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ApplicationInternalController extends Controller
{
    public function store(Request $request)
    {
        // 1. Validate dữ liệu đầu vào (Payload từ Candidate Service gửi sang)
        $validated = $request->validate([
            'job_id'       => 'required|string',
            'candidate_id' => 'required|string',
            'cv_id'        => 'required|string',
            'workspace_id' => 'required|string',
            
            // --- QUAN TRỌNG: Phải nhận các trường Snapshot này ---
            'name'         => 'required|string',
            'email'        => 'required|email',
            'cv_url'       => 'required|string', // URL file CV
            'phone'        => 'nullable|string',
            // ----------------------------------------------------
        ]);

        try {
            // 2. Tìm Pipeline mặc định của Workspace để lấy Stage đầu tiên
            $pipeline = HiringPipeline::where('WorkspaceID', $validated['workspace_id'])
                ->where('IsDefault', true)
                ->first();

            if (!$pipeline) {
                // Fallback nếu ko có default
                $pipeline = HiringPipeline::where('WorkspaceID', $validated['workspace_id'])->first();
            }

            if (!$pipeline) {
                return response()->json(['message' => 'No pipeline found for this workspace'], 400);
            }

            // Lấy Stage đầu tiên (thường là Applied/New)
            $firstStage = $pipeline->stages()->orderBy('StageOrder', 'asc')->first();
            
            if (!$firstStage) {
                return response()->json(['message' => 'Pipeline has no stages'], 400);
            }

            // 3. Tạo Application với thông tin Snapshot
            $application = JobApplication::create([
                'JobID'        => $validated['job_id'],
                'WorkspaceID'  => $validated['workspace_id'],
                'ApplicantID'  => $validated['candidate_id'],
                'CVID'         => $validated['cv_id'],
                'StageID'      => $firstStage->StageID,
                'StatusID'     => 1, // Active
                
                // --- LƯU SNAPSHOT VÀO DB ---
                'Name'         => $validated['name'],
                'Email'        => $validated['email'],
                'Phone'        => $validated['phone'] ?? null,
                'CvUrl'        => $validated['cv_url'],
                // ---------------------------
                
                'AppliedAt'    => now(),
            ]);

            return response()->json([
                'message' => 'Application created successfully',
                'application_id' => $application->ApplicationID
            ], 201);

        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Internal Apply Error: " . $e->getMessage());
            return response()->json(['message' => 'Internal Error', 'error' => $e->getMessage()], 500);
        }
    }

    public function getByCandidate($applicantId)
    {
        $apps = JobApplication::where('ApplicantID', $applicantId)
            ->with(['stage']) 
            ->orderBy('AppliedAt', 'desc')
            ->get();

        return response()->json($apps);
    }
}