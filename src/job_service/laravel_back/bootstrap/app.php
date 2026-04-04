<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        api: __DIR__.'/../routes/api.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            // Đăng ký alias ngắn gọn (Optional, vì trong route ta dùng ::class rồi)
            'job.perm' => \App\Http\Middleware\CheckJobPerm::class,
            'super.admin' => \App\Http\Middleware\CheckSuperAdmin::class,
            'role' => \App\Http\Middleware\EnsureUserRole::class,
        ]);

        $middleware->validateCsrfTokens(except: ['api/*']);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })
    ->withProviders([
        \Mews\Purifier\PurifierServiceProvider::class,
        App\Providers\AuthServiceProvider::class,
        // EventServiceProvider nên được giữ lại nếu dùng Listener đồng bộ JobJd
        App\Providers\EventServiceProvider::class, 
    ])
    ->create();