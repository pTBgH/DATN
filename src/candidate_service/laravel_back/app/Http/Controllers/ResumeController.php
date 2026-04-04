<?php

namespace App\Http\Controllers;

use App\Models\Cv;
use App\Http\Resources\CvResource; // Import Resource
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB; 

class ResumeController extends Controller
{
    public function index()
    {
        $cvs = Cv::where('UserID', Auth::id())->orderBy('CreatedAt', 'desc')->get();

        // Enrich URL xem file
        $cvs->transform(function ($cv) {
            $cv->view_url = $this->getStorageUrl($cv->CVPath);
            return $cv;
        });

        // Trả về Resource Collection (Tự động snake_case)
        return CvResource::collection($cvs);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'cv_path' => 'required|string', // Path nhận từ Storage Service
            // Các trường khác (experience, skills...) nếu có trích xuất CV
        ]);

        $cv = Cv::create([
            'UserID' => Auth::id(),
            'Title' => $data['title'],
            'CVPath' => $data['cv_path'],
            'IsDefault' => 1,
        ]);

        return new CvResource($cv);
    }

    public function setDefault($id)
    {
        $userId = Auth::id();

        $cv = Cv::where('CVID', $id)->where('UserID', $userId)->first();
        if (!$cv) {
            return response()->json(['message' => 'CV not found'], 404);
        }

        DB::transaction(function () use ($cv, $userId) {
            Cv::where('UserID', $userId)->update(['IsDefault' => 0]);
            $cv->update(['IsDefault' => 1]);
        });

        return response()->json(['message' => 'Set as default successfully', 'data' => new CvResource($cv)]);
    }

    private function getStorageUrl($path)
    {
        if (!$path) return null;

        return Cache::remember("cv_url:{$path}", 3000, function () use ($path) {
            try {
                $storageUrl = config('services.microservices.storage'); // http://storage-service
                $response = Http::post("{$storageUrl}/api/internal/files/view-url", [
                    'path' => $path
                ]);
                return $response->json('url');
            } catch (\Exception $e) {
                return null;
            }
        });
    }
}