<?php

use Illuminate\Support\Facades\Route;
use App\Http\Middleware\IdentifyUserContext;
// Chỉ Import những Controller thuộc Workspace Service
use App\Http\Controllers\Workspace\WorkspaceController;
use App\Http\Controllers\Workspace\WorkspaceMemberController;
use App\Http\Controllers\Workspace\WorkspaceInvitationController;
use App\Http\Controllers\OptionController;
// Import Internal Controllers
use App\Http\Controllers\Internal\PermissionInternalController;
use App\Http\Controllers\Internal\CompanyInternalController;
use App\Http\Controllers\Internal\InternalWorkspaceController;

// =================================================================
// 1. PUBLIC ROUTES (Không cần đăng nhập)
// =================================================================

// =================================================================
// 2. INTERNAL ROUTES (Dành cho Service khác gọi - Job, Identity...)
// =================================================================
Route::prefix('internal')->group(function () {
    // Identity gọi để lấy profile
    Route::get('/workspaces/by-user/{userId}', [InternalWorkspaceController::class, 'getUserWorkspaces']);
    
    // Job/Hiring gọi để check quyền
    Route::get('/permissions/{wsId}/{userId}', [PermissionInternalController::class, 'getUserPermissions']);
    
    // Job gọi để lấy thông tin công ty (Enrichment)
    Route::post('/companies/batch-info', [CompanyInternalController::class, 'getBatchInfo']);
});

// =================================================================
// 3. AUTHENTICATED ROUTES (User thao tác)
// =================================================================
Route::middleware([IdentifyUserContext::class])->group(function () {

    // --- Workspace CRUD ---
    Route::post('/workspaces', [WorkspaceController::class, 'store']); // Tạo mới
    Route::get('/my-workspaces', [WorkspaceController::class, 'index']); // Lấy danh sách

    // --- Invitations (Xử lý lời mời) ---
    Route::prefix('invitations')->group(function () {
        Route::post('/accept', [WorkspaceMemberController::class, 'accept']); // Chấp nhận mời
        Route::post('/join-by-code', [WorkspaceMemberController::class, 'joinByCode']); // Nhập code
    });

    // --- Workspace Context (Thao tác trong 1 Workspace cụ thể) ---
    // Lưu ý: Logic check quyền (Middleware permission) bạn cần cài đặt riêng cho Workspace Service
    // Ở đây mình tạm để trống middleware permission để bạn chạy được luồng chính trước
    Route::prefix('workspaces/{workspace}')->group(function () {

        // Xem/Sửa thông tin Workspace
        Route::get('/', [WorkspaceController::class, 'show']);
        Route::put('/', [WorkspaceController::class, 'update']);
        Route::delete('/', [WorkspaceController::class, 'destroy']);

        // Quản lý thành viên (Members)
        Route::prefix('members')->group(function () {
            Route::get('/', [WorkspaceMemberController::class, 'index']); // Xem list
            Route::put('/', [WorkspaceMemberController::class, 'updateMembers']); // Phân quyền
            Route::delete('/{recruiter}', [WorkspaceMemberController::class, 'removeMember']); // Xóa
            
            // Mời thành viên
            Route::prefix('invitations')->group(function () {
                Route::post('/invite-by-email', [WorkspaceMemberController::class, 'invite']); 
                Route::post('/create-code', [WorkspaceMemberController::class, 'createInviteCode']); 
            });
        });
    });

});