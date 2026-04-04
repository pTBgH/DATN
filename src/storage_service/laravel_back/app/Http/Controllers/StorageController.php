<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class StorageController extends Controller
{
    // GET /api/presigned-url?filename=mycv.pdf&type=cv
    public function getPresignedUrl(Request $request)
    {
        $request->validate([
            'filename' => 'required|string',
            'type' => 'required|string|in:cv,avatar,logo',
        ]);

        $type = $request->type;
        $extension = pathinfo($request->filename, PATHINFO_EXTENSION);
        // Tạo tên file ngẫu nhiên để tránh trùng: cvs/UUID.pdf
        $path = "{$type}s/" . Str::uuid() . ".{$extension}";

        $client = Storage::disk('minio')->getClient();
        $expiry = "+20 minutes";

        // Tạo lệnh PUT (Upload)
        $command = $client->getCommand('PutObject', [
            'Bucket' => config('filesystems.disks.minio.bucket'),
            'Key'    => $path,
            'ACL'    => 'public-read', // Hoặc private tùy nhu cầu
        ]);

        $presignedRequest = $client->createPresignedRequest($command, $expiry);

        return response()->json([
            'upload_url' => (string) $presignedRequest->getUri(),
            'file_path'  => $path, // Frontend sẽ gửi lại path này cho Candidate Service
            'file_url'   => Storage::disk('minio')->url($path) // Link xem file
        ]);
    }
}