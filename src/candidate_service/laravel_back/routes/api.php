<?php

use Illuminate\Support\Facades\Route;
use App\Http\Middleware\IdentifyUserContext;
use App\Http\Controllers\ResumeController;
use App\Http\Controllers\JobApplicationController;
use App\Http\Controllers\InteractionController;
use App\Http\Controllers\Internal\ResumeInternalController;

// =================================================================
// 1. PUBLIC ROUTES
// =================================================================
Route::get('/health', function () {
    return response()->json(['status' => 'ok', 'service' => 'candidate-service']);
});

// =================================================================
// 2. INTERNAL ROUTES (Dành cho các Microservice khác gọi)
// =================================================================
Route::prefix('internal')->group(function () {
    // Route::get('/cvs/{cvId}', [ResumeInternalController::class, 'show']);
    
    // Job Service gọi để check xem User đã lưu Job này chưa (Optional)
    // Route::get('/interactions/check/{jobId}/{userId}', [InteractionController::class, 'internalCheck']);
});

// =================================================================
// 3. AUTHENTICATED ROUTES (Ứng viên thao tác)
// =================================================================
Route::middleware([IdentifyUserContext::class, 'role:candidate'])->group(function () {

    // --- A. QUẢN LÝ CV (Resumes) ---
    Route::prefix('resumes')->group(function () {
        // Lấy danh sách CV của tôi
        Route::get('/', [ResumeController::class, 'index']);
        
        // Lưu metadata CV mới (Sau khi upload file qua Storage Service)
        Route::post('/', [ResumeController::class, 'store']);
        
        Route::patch('/{id}/default', [ResumeController::class, 'setDefault']);
        
        // Xem chi tiết CV
        Route::get('/{id}', [ResumeController::class, 'show']);
        
        // Cập nhật tên CV / Set Default
        Route::put('/{id}', [ResumeController::class, 'update']);
        
        // Xóa CV
        Route::delete('/{id}', [ResumeController::class, 'destroy']);
    });

    // --- B. ỨNG TUYỂN (Applications) ---
    // Nộp đơn vào một Job
    Route::post('/jobs/{jobId}/apply', [JobApplicationController::class, 'apply']);
    
    // Xem lịch sử ứng tuyển của tôi
    Route::get('/my-applications', [JobApplicationController::class, 'myHistory']);

    // --- C. TƯƠNG TÁC (Interactions) ---
    Route::prefix('interactions')->group(function () {
        // Lưu / Bỏ lưu việc làm
        // Body: { "job_id": "...", "is_saved": true/false }
        Route::post('/saved-jobs', [InteractionController::class, 'toggleSavedJob']);
        
        // Lấy danh sách việc làm đã lưu
        Route::get('/saved-jobs', [InteractionController::class, 'getSavedJobs']);
    });

});

Route::post('/test-kafka-apply/{jobId}', function (\Illuminate\Http\Request $request, $jobId) {
    
    // 1. Fake User (Lấy ID của Ứng viên thật trong DB usr_users của bạn)
    // ID này phải là chủ sở hữu của cái CV bạn định test
    $fakeUser = new \Illuminate\Auth\GenericUser([
        'id' => 'b47ba303-b1a3-45ee-8ee2-d2c57751583e', // <--- THAY ID CỦA USER VÀO ĐÂY
        'email' => 'baophungthai9@gmail.com',
        'name' => 'bảo phùng thái',
        'type' => 'candidate'
    ]);

    // 2. Đăng nhập user fake này vào hệ thống
    \Illuminate\Support\Facades\Auth::setUser($fakeUser);

    // 3. Gọi Controller Apply như bình thường
    return app(\App\Http\Controllers\JobApplicationController::class)->apply($request, $jobId);
});