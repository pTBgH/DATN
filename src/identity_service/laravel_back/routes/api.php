<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Recruiter\RecruiterController;
use App\Http\Middleware\VerifyKeycloakToken;
use App\Http\Controllers\Candidate\CandidateProfileController;

// 1. API cho Frontend gọi (Có xác thực & Sync)
Route::middleware([VerifyKeycloakToken::class])->group(function () {
    Route::middleware('role:recruiter')->prefix('recruiters/profile')->group(function () {
        Route::get('/', [RecruiterController::class, 'getMyProfile']);
        Route::put('/', [RecruiterController::class, 'update']);
    });

    Route::middleware('role:candidate')->prefix('candidates/profile')->group(function () {
        Route::get('/', [CandidateProfileController::class, 'show']);
        Route::put('/', [CandidateProfileController::class, 'update']);
    });
});

// 2. API Nội bộ (Cho Job/Hiring Service gọi để map ID)
Route::prefix('internal')->group(function () {
    Route::post('/auth/sync-user', [\App\Http\Controllers\Internal\IdentityInternalController::class, 'syncUser']);
    // Include hot-reload internal route (no session/cookie middleware)
    if (file_exists(__DIR__ . '/internal.php')) {
        require __DIR__ . '/internal.php';
    }
    // Route::get('/auth/map-user/{keycloakId}', [\App\Http\Controllers\Internal\IdentityInternalController::class, 'mapUser']);
    Route::get('/users/{id}', [\App\Http\Controllers\Internal\IdentityInternalController::class, 'getUserDetail']);
});

























// 1. Health Check
Route::get('/health', function () {
    return response()->json(['status' => 'ok', 'service' => 'Identity Service']);
});

// Internal API để Keycloak/Service khác gọi (Bảo vệ bằng Secret Key nội bộ)
// Route::middleware('auth.internal_api')->group(function () {
//     Route::post('/auth/sync-recruiter', [AuthController::class, 'syncRecruiter']);
// });

// // APIs yêu cầu User đã đăng nhập qua Keycloak
// Route::middleware('keycloak')->group(function () {
    
//     // 2. Recruiter Profile (Đã có trong Monolith)
//     Route::prefix('recruiters/profile')->group(function () {
//         Route::get('/', [RecruiterController::class, 'getMyProfile']);
//         Route::put('/', [RecruiterController::class, 'update']);
//     });

//     // 3. Candidate Profile (TODO: Chưa có trong Monolith)
//     // Route::prefix('candidates/profile')->group(function () {
//     //     Route::get('/', [CandidateProfileController::class, 'show']);
//     //     Route::put('/', [CandidateProfileController::class, 'update']);
//     // });

//     // 4. Admin User Management (TODO: Chưa có trong Monolith)
//     // Route::prefix('admin/users')->middleware('super.admin')->group(function () {
//     //     Route::get('/', [UserController::class, 'index']);
//     //     Route::patch('/{id}/status', [UserController::class, 'updateStatus']); 
//     // });
// });

// Internal APIs: Cung cấp thông tin User cho các Service khác
Route::prefix('internal')->group(function () {
    // Logic này cần viết thêm để Service khác lấy tên/avatar user qua ID
    // Route::get('/users', [UserController::class, 'getInternalUsers']); 
});