<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Job\JobController;
use App\Http\Controllers\Job\JobMakingController;
use App\Http\Controllers\Job\JobStatusController;
use App\Http\Controllers\Job\JobHistoryController;
use App\Http\Controllers\OptionController;
use App\Http\Middleware\IdentifyUserContext;
use App\Http\Middleware\CheckJobPerm;
use App\Http\Controllers\Public\MetadataController;
use App\Http\Controllers\Job\JobCompanyController;

// 1. PUBLIC ROUTES
Route::get('/options/general', [OptionController::class, 'getGeneralOptions']);
Route::get('/options/company-types', [OptionController::class, 'getCompanyOptions']);
Route::get('/public/jobs', [JobController::class, 'publicSearch']);
Route::get('/public/jobs/{id}', [JobController::class, 'publicDetail']);
Route::get('/public/metadata/common', [MetadataController::class, 'getCommon']);
Route::get('/public/metadata/districts/{city_id}', [MetadataController::class, 'getDistricts']);


// 2. AUTHENTICATED ROUTES
Route::middleware([IdentifyUserContext::class])->group(function () {

    // Admin Routes
    Route::prefix('admin/jobs')->middleware('super.admin')->group(function () {
        Route::get('/', [JobController::class, 'listPending']);
        Route::patch('/{jobId}/approve', [JobStatusController::class, 'approve']);
        Route::patch('/{jobId}/reject', [JobStatusController::class, 'reject']);
    });

    Route::prefix('admin/categories')->middleware('super.admin')->group(function () {
        Route::get('/sectors', [\App\Http\Controllers\Admin\CategoryController::class, 'indexSectors']);
        Route::post('/sectors', [\App\Http\Controllers\Admin\CategoryController::class, 'storeSector']);
        Route::put('/sectors/{id}', [\App\Http\Controllers\Admin\CategoryController::class, 'updateSector']);
        Route::delete('/sectors/{id}', [\App\Http\Controllers\Admin\CategoryController::class, 'destroySector']);
    });

    Route::middleware('role:recruiter')->group(function () {

        Route::get('/companies/{id}', [JobCompanyController::class, 'show']);
        Route::put('/companies/{id}', [JobCompanyController::class, 'update']);

        Route::prefix('workspaces/{wsId}/jobs')->group(function () {
            
            // --- READ ---
            Route::get('/', [JobController::class, 'index']);
                //  ->middleware(CheckJobPerm::class . ':READ_JOB');
            
            Route::get('/{jobId}', [JobController::class, 'show']);
                //  ->middleware(CheckJobPerm::class . ':READ_JOB');

            // --- CREATE ---
            // Route::middleware(CheckJobPerm::class . ':CREATE_JOB')->group(function () {
                Route::post('/manual', [JobMakingController::class, 'createManualJob']);
                Route::post('/draft', [JobMakingController::class, 'saveDraft']);
                Route::post('/submit', [JobMakingController::class, 'submitNewJob']);
                
                Route::post('/from-file', [JobMakingController::class, 'extractJobFromFile']);
            // });

            // --- UPDATE ---
            // Route::middleware(CheckJobPerm::class . ':UPDATE_JOB')->group(function () {
                Route::put('/{jobId}', [JobController::class, 'update']);
                Route::post('/{jobId}/rollback', [JobHistoryController::class, 'rollback']);
                
                Route::patch('/{jobId}/submit', [JobStatusController::class, 'submit']);
                Route::patch('/{jobId}/unpublish', [JobStatusController::class, 'unpublish']);
                Route::patch('/{jobId}/close', [JobStatusController::class, 'close']);
            // });
        });
    });
});

// Internal Routes for other services
Route::prefix('internal')->group(function () {
    Route::post('/jobs/batch-info', [\App\Http\Controllers\Internal\JobInternalController::class, 'getBatchInfo']);
});