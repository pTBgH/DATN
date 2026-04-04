<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Support\Logging\StructuredLogger;
use Illuminate\Support\Str;

class PresignedUrlController extends Controller
{
    public function getUploadUrl(Request $request)
    {
        $validated = $request->validate([
            'filename' => 'required|string',
            'type'     => 'required|string|in:cv,avatar,logo',
        ]);

        try {
            $type = $validated['type'];
            $extension = pathinfo($validated['filename'], PATHINFO_EXTENSION);
            if (empty($extension)) $extension = 'bin';
            $newFileName = Str::uuid()->toString() . '.' . $extension;
            $filePath = "{$type}s/{$newFileName}";

            // Bắt buộc S3Client dùng Endpoint Public của Minio để thuật toán HMAC tạo Signature khớp với lúc Upload
            $minioPort = env('MINIO_EXTERNAL_PORT', '8080'); // Port Public bạn đang map
            $minioHost = env('MINIO_EXTERNAL_HOST', 's3.job7189.local');
            config(['filesystems.disks.minio.endpoint' => "http://{$minioHost}:{$minioPort}"]);
            Storage::forgetDisk('minio'); // 🔥 QUAN TRỌNG
            $disk = Storage::disk('minio');
            $client = $disk->getClient();
            $bucket = config('filesystems.disks.minio.bucket');

            $command = $client->getCommand('PutObject', [
                'Bucket' => $bucket,
                'Key'    => $filePath,
            ]);

            $expiry = "+20 minutes";
            $presignedRequest = $client->createPresignedRequest($command, $expiry);
            $presignedUrl = (string) $presignedRequest->getUri();

            return response()->json([
                'success'    => true,
                'upload_url' => $presignedUrl,
                'file_path'  => $filePath,
                'file_url'   => "http://{$minioHost}/{$filePath}"
            ]);

        } catch (\Exception $e) {
            (new StructuredLogger('system', 'error'))->error(['message' => "Presigned URL Generate Failed: " . $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'Could not generate upload link. Check storage configuration.'
            ], 500);
        }
    }
}
