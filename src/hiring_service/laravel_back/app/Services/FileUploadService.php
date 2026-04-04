<?php

namespace App\Services;

use App\Jobs\FinalizeFileUpload;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use Illuminate\Support\Facades\Storage;
use Ramsey\Uuid\Uuid;
use Exception;

class FileUploadService
{
    // public function queueUpload(UploadedFile $file, string $directory): ?string
    // {
    //     $tempLocalPath = $file->store('temp_cvs', 'local');
    //     if (!$tempLocalPath) {
    //         return null;
    //     }

    //     $fileName = Uuid::uuid7()->toString() . '.' . $file->getClientOriginalExtension();
    //     $filePathInBucket = $directory . '/' . $fileName;

    //     FinalizeFileUpload::dispatch($tempLocalPath, $filePathInBucket);
    //     return $filePathInBucket;
    // }
    public function queueUpload(UploadedFile $file, string $directory): ?string
    {
        try {
            // 1. Generate a unique, time-sortable filename to prevent collisions.
            $fileName = Uuid::uuid7()->toString() . '.' . $file->getClientOriginalExtension();
            $filePathInBucket = $directory . '/' . $fileName;

            // 2. Get the raw contents of the uploaded file.
            $fileContents = $file->get();
            if ($fileContents === false) {
                Log::channel('daily_error')->error('Could not read the contents of the uploaded file.', [
                    'original_name' => $file->getClientOriginalName()
                ]);
                return null;
            }

            // 3. Upload the file contents directly to the 'minio' disk.
            $success = Storage::disk('minio')->put($filePathInBucket, $fileContents);

            if ($success) {
                Log::channel('daily_normal')->info('File uploaded directly to MinIO successfully.', [
                    'path' => $filePathInBucket
                ]);
                return $filePathInBucket;
            } else {
                Log::channel('daily_error')->error('Storage::put returned false, indicating a direct MinIO upload failure.', [
                    'path' => $filePathInBucket
                ]);
                return null;
            }

        } catch (Exception $e) {
            Log::channel('daily_error')->error('An exception occurred during direct file upload to MinIO.', [
                'message'   => $e->getMessage(),
                'exception' => get_class($e),
                'file'      => $e->getFile(),
                'line'      => $e->getLine(),
                'trace'     => $e->getTraceAsString()
            ]);
            return null;
        }
    }

}