<?php

namespace App\Http\Controllers\Hiring;

use App\Http\Controllers\Controller;
use App\Models\Job\JobApplication;
use App\Models\Hiring\Interview; // Bạn cần tạo Model này (đã có trong DB)
use App\Http\Resources\Hiring\InterviewResource;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;



class InterviewController extends Controller
{
    // GET /api/interviews?application_id=...
    public function index(Request $request)
    {
        $query = Interview::query();
        if ($request->has('application_id')) {
            $query->where('ApplicationID', $request->application_id);
        }
        return InterviewResource::collection($query->orderBy('StartTime')->get());
    }

    // POST /api/interviews
    public function store(Request $request, string $applicationId)
    {
        try {
        $data = $request->validate([
            'start_time'     => 'required|date|after:now',
            'end_time'       => 'required|date|after:start_time',
            'location'       => 'nullable|string|max:255', // Link meeting
            'note'           => 'nullable|string'
        ]);
        $app = JobApplication::where('ApplicationID', $applicationId)->firstOrFail();
        $interview = Interview::create([
            'ApplicationID' => $data['application_id'],
            'StartTime'     => $data['start_time'],
            'EndTime'       => $data['end_time'],
            'Status'        => 'Scheduled',
            'Location'      => $data['location'],
            'CreatedAt'     => now()
        ]);

        // TODO: Bắn Kafka để Communication Service gửi mail mời họp (ICS file)
        // $this->kafka->produce('job7189.communication', [...]);

        return response()->json(new InterviewResource($interview), 201);
        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => 'Error scheduling interview: ' . $e->getMessage());
            return response()->json(['message' => 'Error scheduling interview', 'error' => $e->getMessage()], 500);
        }
    }

    // PUT /api/interviews/{id} (Dời lịch / Hủy)
    public function update(Request $request, string $id)
    {
        $interview = Interview::findOrFail($id);

        $data = $request->validate([
            'start_time' => 'sometimes|date',
            'end_time'   => 'sometimes|date|after:start_time',
            'status'     => 'sometimes|string|in:Scheduled,Completed,Cancelled',
            'location'   => 'nullable|string'
        ]);

        $interview->update($data);

        return new InterviewResource($interview);
    }

    // DELETE /api/interviews/{id}
    public function destroy(string $id)
    {
        $interview = Interview::findOrFail($id);
        $interview->delete();
        return response()->json(['message' => 'Interview deleted successfully.']);
    }

    // POST /api/interviews/{id}/feedback
    public function submitFeedback(Request $request, string $id)
    {
        $interview = Interview::findOrFail($id);
        $data = $request->validate([
            'feedback' => 'required|string'
        ]);
        // Lưu feedback vào một trường mới trong bảng interviews hoặc bảng liên quan
        // Hiện tại giả sử có trường Feedback trong bảng interviews
        $interview->Feedback = $data['feedback'];
        $interview->save();

        return response()->json(['message' => 'Feedback submitted successfully.']);
    }

    // GET /api/interviews/{id}
    public function show(string $id)
    {
        $interview = Interview::findOrFail($id);
        return new InterviewResource($interview);
    }


}