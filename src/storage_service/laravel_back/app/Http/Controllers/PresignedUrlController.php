<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class PresignedUrlController extends Controller
{
    /**
     * Tạo URL Upload (PUT)
     * Frontend gọi API này -> Nhận URL -> Tự PUT file lên MinIO
     */
    public function getUploadUrl(Request $request)
    {
        // 1. Validate dữ liệu đầu vào
        $validated = $request->validate([
            'filename' => 'required|string',
            'type'     => 'required|string|in:cv,avatar,logo', // Giới hạn các loại file cho phép
        ]);

        try {
            $type = $validated['type'];
            
            // 2. Tạo tên file duy nhất (UUIDv7 hoặc v4) để tránh trùng lặp
            $extension = pathinfo($validated['filename'], PATHINFO_EXTENSION);
            if (empty($extension)) $extension = 'bin'; // Fallback nếu không có đuôi
            
            $newFileName = Str::uuid()->toString() . '.' . $extension;
            
            // Tạo đường dẫn: ví dụ "cvs/uuid-1234.pdf" hoặc "avatars/uuid-5678.png"
            $filePath = "{$type}s/{$newFileName}";

            // 3. Lấy Client S3 từ Driver MinIO
            $disk = Storage::disk('minio');
            $client = $disk->getClient();
            $bucket = config('filesystems.disks.minio.bucket');

            // 4. Tạo lệnh "PutObject" (Lệnh Upload)
            $command = $client->getCommand('PutObject', [
                'Bucket' => $bucket,
                'Key'    => $filePath,
                // 'ACL'    => 'public-read', // Bỏ comment nếu muốn file này public ngay lập tức
                // 'ContentType' => ... // Có thể thêm nếu muốn strict mime type
            ]);

            // 5. Ký tên vào URL (Link sống trong 20 phút)
            $expiry = "+20 minutes";
            $presignedRequest = $client->createPresignedRequest($command, $expiry);
            $presignedUrl = (string) $presignedRequest->getUri();

            // 6. Trả về cho Frontend
            return response()->json([
                'success'    => true,
                'upload_url' => $presignedUrl, // Link để FE upload (PUT)
                'file_path'  => $filePath,     // FE giữ cái này để gửi cho Candidate/Identity Service lưu vào DB
                'file_url'   => $disk->url($filePath) // Link truy cập (nếu bucket public)
            ]);

        } catch (\Exception $e) {
            Log::error("Presigned URL Generate Failed: " . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Could not generate upload link. Check storage configuration.'
            ], 500);
        }
    }
}