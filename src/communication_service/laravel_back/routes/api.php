<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Internal\EmailInternalController;
use App\Http\Middleware\IdentifyUserContext;
use App\Http\Controllers\ChatController;

// Route nội bộ cho các service khác gọi
Route::prefix('internal')->group(function () {
    Route::post('/email/send', [EmailInternalController::class, 'send']);
});

// Route health check
Route::get('/health', function () {
    return response()->json(['status' => 'ok', 'service' => 'communication-service']);
});

Route::middleware([IdentifyUserContext::class])->group(function () {
    
    // Chat Routes
    Route::get('/conversations', [ChatController::class, 'index']);
    Route::post('/conversations', [ChatController::class, 'store']); // Start chat
    Route::get('/conversations/{id}/messages', [ChatController::class, 'messages']);
    
    Route::post('/messages', [ChatController::class, 'sendMessage']);
});