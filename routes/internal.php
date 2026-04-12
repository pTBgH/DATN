<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Providers\HotReloadServiceProvider;

/**
 * Internal routes for hot-reload. This file should be included from RouteServiceProvider
 * and mounted in a local/internal middleware group (or protected by network policy).
 */

Route::post('/reload-db', function (Request $request) {
    $token = $request->header('X-Internal-Token', '');
    $expected = env('INTERNAL_RELOAD_TOKEN', '');
    if (empty($expected) || !hash_equals($expected, $token)) {
        return response('unauthorized', 401);
    }

    try {
        HotReloadServiceProvider::reloadDatabaseConnection();
        return response('reloaded', 200);
    } catch (\Throwable $e) {
        logger()->error('internal.reload-db error: ' . $e->getMessage());
        return response('error', 500);
    }
});
