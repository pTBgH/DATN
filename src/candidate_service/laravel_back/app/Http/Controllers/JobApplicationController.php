<?php

namespace App\Http\Controllers;

use App\Models\Cv;
use App\Services\Kafka\KafkaHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Str;
use Ramsey\Uuid\Uuid;

class JobApplicationController extends Controller
{
    protected KafkaHelper $kafka;

    public function __construct(KafkaHelper $kafka)
    {
        $this->kafka = $kafka;
    }

    public function apply(Request $request, string $jobId)
    {
        (new StructuredLogger('system', 'action'))->info(['message' => "User " . Auth::id() . " is applying to Job ID: {$jobId}");
        
        $request->validate(['cv_id' => 'required|exists:usr_cvs,CVID']);

        $user = Auth::user();
        $cvId = $request->cv_id;

        $cv = Cv::where('CVID', $cvId)->where('UserID', $user->id)->first();
        if (!$cv) {
            return response()->json(['message' => 'Invalid CV or Access Denied'], 403);
        }

        $workspaceId = null;
        $jobTitle = 'Unknown Job';
        $companyName = 'Unknown Company'; 

        try {
            $jobUrl = config('services.microservices.job');
            $response = Http::timeout(2)->get("{$jobUrl}/api/public/jobs/{$jobId}");
            
            if (!$response->successful()) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Job Not Found. Status: " . $response->status()]);
                return response()->json(['message' => 'Job not found or closed'], 404);
            }
            
            $jobData = $response->json();
            
            // Xử lý key đa dạng (Resource trả về snake_case, Raw trả về PascalCase)
            $workspaceId = $jobData['company_id'] ?? $jobData['CompanyID'] ?? null;
            $jobTitle    = $jobData['title'] ?? $jobData['Title'] ?? 'Unknown Job';
            
            // <--- LẤY TÊN CÔNG TY (Đã được Job Service Enrich từ trước) ---
            $companyName = $jobData['company_name'] ?? $jobData['CompanyNameSnapshot'] ?? 'Unknown Company';
            
            if (!$workspaceId) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Missing Company ID in Job Response", (array)$jobData]);
                return response()->json(['message' => 'Invalid Job Data (Missing WorkspaceID)'], 500);
            }

        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Call Job Service Failed: " . $e->getMessage()]);
            return response()->json(['message' => 'Cannot verify job details'], 500);
        }

        try {
            $applicationId = Uuid::uuid7()->toString(); 

            $eventData = [
                'event_type' => 'candidate.applied',
                'timestamp' => microtime(true),
                'data' => [
                    'application_id' => $applicationId,
                    'job_id'         => $jobId,
                    'job_title'      => $jobTitle,
                    'company_name'   => $companyName,
                    'cv_id'          => $cvId,
                    'cv_title'       => $cv->Title,
                    'cv_path'        => $cv->CVPath,
                    'applicant_id'   => $user->id,
                    'applicant_email'=> $user->email,
                    'applicant_name' => $user->name,
                    'workspace_id'   => $workspaceId,
                    'applied_at'     => now()->toIso8601String(),
                ]
            ];

            try {
                $this->kafka->produce('job7189.applications', $eventData);
            } catch (\Exception $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Kafka Produce Failed: " . $e->getMessage()]);
            }

            (new StructuredLogger('system', 'action'))->info(['message' => "Kafka event sent.", ['app_id' => $applicationId]);

            return response()->json([
                'application_id' => $applicationId,
                'message'        => 'Application submitted successfully (Processing)'
            ], 202);

        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Kafka Produce Failed: " . $e->getMessage()]);
            return response()->json(['message' => 'Application failed due to system error'], 500);
        }
    }

    public function myHistory()
    {
        $userId = Auth::id();
        (new StructuredLogger('system', 'action'))->info(['message' => "Fetching history for User: {$userId}");

        // 1. Gọi Hiring Service lấy danh sách đơn
        $applications = [];
        try {
            $hiringUrl = config('services.microservices.hiring');
            $response = Http::timeout(2)->get("{$hiringUrl}/api/internal/applications/candidate/{$userId}");
            
            if ($response->successful()) {
                $applications = $response->json();
            } else {
                (new StructuredLogger('system', 'error'))->error(['message' => "Hiring Service Error: " . $response->status() . " Body: " . $response->body()]);
            }
        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Call Hiring Failed: " . $e->getMessage()]);
            return response()->json(['data' => []]);
        }

        if (empty($applications)) {
            return response()->json(['data' => []]);
        }

        // 2. Lấy danh sách Job ID
        $jobIds = collect($applications)->pluck('JobID')->unique()->values()->toArray();

        // 3. Gọi Job Service (Batch Info)
        $jobsMap = [];
        if (!empty($jobIds)) {
            try {
                $jobUrl = config('services.microservices.job');
                $jobResponse = Http::timeout(3)->post("{$jobUrl}/api/internal/jobs/batch-info", [
                    'ids' => $jobIds
                ]);

                if ($jobResponse->successful()) {
                    $jobsMap = $jobResponse->json();
                    (new StructuredLogger('system', 'action'))->info(['message' => "Job Batch Info:", $jobsMap); // Uncomment để debug
                } else {
                    (new StructuredLogger('system', 'error'))->error(['message' => "Job Batch Failed: " . $jobResponse->status()]);
                }
            } catch (\Exception $e) {
                (new StructuredLogger('system', 'error'))->error(['message' => "Call Job Batch Failed: " . $e->getMessage()]);
            }
        }

        // 4. Ghép dữ liệu (Có check lỗi)
        $result = collect($applications)->map(function ($app) use ($jobsMap) {
            
            // Tìm Job trong Map
            // Lưu ý: Key của Map có thể là String UUID, cần đảm bảo khớp
            $jobInfo = $jobsMap[$app['JobID']] ?? null;

            // Xử lý key đa dạng từ Job Service (PascalCase hoặc snake_case)
            $jobTitle    = $jobInfo['Title'] ?? $jobInfo['title'] ?? 'Job Unavailable';
            $companyName = $jobInfo['company_name'] ?? $jobInfo['CompanyName'] ?? 'Unknown Company'; // Do Enricher bơm vào
            $logo        = $jobInfo['company_logo'] ?? $jobInfo['PictureUrl'] ?? null;
            $status      = $jobInfo['status'] ?? 'Unknown'; // Thường là số (20) hoặc string ("Published")
            $slug        = $jobInfo['slug'] ?? $jobInfo['Slug'] ?? null;

            // Xử lý Stage (Hiring Service trả về relation 'stage')
            // Kiểm tra kỹ cấu trúc mảng 'stage' từ response Hiring
            $stageData = $app['stage'] ?? [];
            
            return [
                'application_id' => $app['ApplicationID'],
                'applied_at'     => $app['AppliedAt'],
                'status'         => $app['StatusID'] ?? 1,
                
                'stage'          => [
                    'id'   => $stageData['StageID'] ?? null,
                    'name' => $stageData['Name'] ?? 'Pending Review', // Default text nếu null
                    'color'=> $stageData['Color'] ?? '#ccc',
                ],

                'job'            => [
                    'id'           => $app['JobID'],
                    'title'        => $jobTitle,
                    'company_name' => $companyName,
                    'logo'         => $logo,
                    'status'       => $status,
                    'slug'         => $slug,
                ]
            ];
        });

        return response()->json(['data' => $result]);
    }
}