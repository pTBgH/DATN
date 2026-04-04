<?php
use Illuminate\Support\Facades\Route;

Route::prefix('internal')->group(function () {
    // API tạo link xem file (Get Presigned URL for Download/View)
    Route::post('/files/view-url', [\App\Http\Controllers\Internal\StorageInternalController::class, 'getViewUrl']);
});

Route::get('presigned-url', [\App\Http\Controllers\PresignedUrlController::class, 'getUploadUrl']);