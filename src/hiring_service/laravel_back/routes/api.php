<?php

use Illuminate\Support\Facades\Route;
use App\Http\Middleware\IdentifyUserContext;
use App\Http\Middleware\CheckHiringPerm;
use App\Http\Controllers\Hiring\HiringPipelineController;
use App\Http\Controllers\Hiring\HiringBoardController;
use App\Http\Controllers\Internal\ApplicationInternalController;
use App\Http\Controllers\Hiring\WorkflowController;
use App\Http\Controllers\Hiring\ScorecardController;
use App\Http\Controllers\Hiring\InterviewController;

Route::get('/health', function () {
     return response()->json(['status' => 'ok']);
});

Route::prefix('internal')->group(function () {
     Route::post('/applications', [ApplicationInternalController::class, 'store']);
     Route::get('/applications/candidate/{id}', [ApplicationInternalController::class, 'getByCandidate']);
});

Route::middleware([IdentifyUserContext::class])->group(function () {

     Route::prefix('workspaces/{workspaceId}/pipelines')->group(function () {
          Route::get('/workflow-definitions', [WorkflowController::class, 'getDefinitions']);
          // ->middleware(CheckHiringPerm::class . ':READ_PIPELINE');

          Route::get('/', [HiringPipelineController::class, 'index'])
               ->middleware(CheckHiringPerm::class . ':READ_PIPELINE');
               
          Route::post('/', [HiringPipelineController::class, 'store'])
               ->middleware(CheckHiringPerm::class . ':CREATE_PIPELINE'); // Hoặc MANAGE
               
          // 2. Lấy config hiện tại
          Route::get('/{pipelineId}/workflow', [WorkflowController::class, 'getConfig']);
               // ->middleware(CheckHiringPerm::class . ':READ_PIPELINE');

          // 3. Lưu config mới
          Route::post('/{pipelineId}/workflow', [WorkflowController::class, 'updateConfig']);
               // ->middleware(CheckHiringPerm::class . ':UPDATE_PIPELINE');     

          Route::get('/{pipelineId}', [HiringPipelineController::class, 'show']);
               // ->middleware(CheckHiringPerm::class . ':READ_PIPELINE');
               
          Route::put('/{pipelineId}', [HiringPipelineController::class, 'update']);
               // ->middleware(CheckHiringPerm::class . ':UPDATE_PIPELINE');
               
          Route::delete('/{pipelineId}', [HiringPipelineController::class, 'destroy']);
               // ->middleware(CheckHiringPerm::class . ':DELETE_PIPELINE'); // Hoặc MANAGE

     });

     Route::get('/board/{jobId}', [HiringBoardController::class, 'getBoard']);
     
     Route::prefix('applications/{applicationId}')->group(function () {
          
          // Xem chi tiết ứng viên (Profile, CV snapshot...)
          Route::get('/', [HiringBoardController::class, 'showApplication']);
          
          // Kéo thả ứng viên sang Stage khác
          Route::post('/move', [HiringBoardController::class, 'moveApplication']);

          // --- SCORECARDS (Đánh giá) ---
          Route::post('/scorecards', [ScorecardController::class, 'store']);
          Route::get('/scorecards', [ScorecardController::class, 'index']);

          // --- INTERVIEWS (Phỏng vấn - Bổ sung dựa trên file tree) ---
          Route::get('/interviews', [InterviewController::class, 'index']); // Xem lịch sử phỏng vấn
          Route::post('/interviews', [InterviewController::class, 'store']); // Lên lịch phỏng vấn mới
     });
     
     Route::prefix('interviews/{interviewId}')->group(function () {
          Route::get('/', [InterviewController::class, 'show']);
          Route::put('/', [InterviewController::class, 'update']); // Dời lịch, cập nhật link meet
          Route::post('/feedback', [InterviewController::class, 'submitFeedback']); // Gửi feedback sau phỏng vấn
          Route::delete('/', [InterviewController::class, 'destroy']); // Hủy lịch
     });
});