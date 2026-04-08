<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class StorageInternalController extends Controller
{
public function getViewUrl(Request $request)
    {
        $path = $request->input('path');
        if (!$path) return response()->json(['url' => null]);

        $disk = Storage::disk('minio');
        $client = $disk->getClient();
        $bucket = config('filesystems.disks.minio.bucket');
        
        $command = $client->getCommand('GetObject', [
            'Bucket' => $bucket,
            'Key'    => $path,
        ]);

        $expiry = "+60 minutes";
        $presignedRequest = $client->createPresignedRequest($command, $expiry);
        
        $internalUri = (string) $presignedRequest->getUri();
        
        $publicBase = config('filesystems.disks.minio.url'); // Đọc từ MINIO_URL
        
        $parsedInternal = parse_url($internalUri);
        $pathQuery = ($parsedInternal['path'] ?? '') . '?' . ($parsedInternal['query'] ?? '');
        
        $finalUrl = str_replace('minio:9000', 'localhost:9000', $internalUri);

        return response()->json(['url' => $finalUrl]);
    }
}