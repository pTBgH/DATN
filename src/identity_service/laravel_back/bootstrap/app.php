<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use App\Http\Middleware\VerifyKeycloakToken;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        api: __DIR__.'/../routes/api.php',
        health: '/up',
        then: function () {
            Route::model('job', \App\Models\Job\JobSubJd::class);
            Route::model('application', \App\Models\Job\JobApplication::class);
            Route::model('pipeline', \App\Models\Hiring\HiringPipeline::class);
        }
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            'keycloak' => \App\Http\Middleware\VerifyKeycloakToken::class,
            'auth.internal_api' => \App\Http\Middleware\AuthenticateInternalApi::class,
            'auth.optional' => \App\Http\Middleware\AuthenticateOptional::class,
            'permission' => \App\Http\Middleware\CheckPermission::class,
            'super.admin' => \App\Http\Middleware\CheckSuperAdmin::class,
            'role' => \App\Http\Middleware\EnsureUserRole::class,
        ]);
        $middleware->validateCsrfTokens(except: [
        'api/get_html'
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })
    ->withProviders([
        // MongoDB\Laravel\MongoDBServiceProvider::class, 
        \Mews\Purifier\PurifierServiceProvider::class,
        App\Providers\AuthServiceProvider::class,
    ])
    ->booting(function () {
    })->create();

