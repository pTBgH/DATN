#!/bin/bash

# Khôi phục file gốc trước
git checkout src/storage_service/laravel_back/app/Http/Controllers/PresignedUrlController.php

# Viết script thay thế để inject cấu hình động
cat << 'PHP' > src/storage_service/laravel_back/app/Http/Controllers/PresignedUrlController.php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;
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

            // QUAN TRỌNG: Để chữ ký (Signature) hợp lệ, AWS SDK phải biết chính xác domain public sẽ sử dụng
            // Thay vì dùng minio:9000 nội bộ, ta ép nó dùng URL bên ngoài (s3.job7189.local:8080)
            config(['filesystems.disks.minio.endpoint' => 'http://s3.job7189.local:8080']);
            app('filesystem')->purge('minio'); // Xoá cache của disk minio nội bộ (nếu có)
            
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

            // Lúc này presignedUrl sẽ tự động là http://s3.job7189.local:8080/... kèm chữ ký hmac auth hợp lệ
            
            return response()->json([
                'success'    => true,
                'upload_url' => $presignedUrl,
                'file_path'  => $filePath,
                'file_url'   => $disk->url($filePath)
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
PHP

echo "Đã patch xong file PHP."
