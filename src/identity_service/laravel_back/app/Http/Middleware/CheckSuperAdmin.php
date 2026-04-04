<?php

namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpFoundation\Response;

class CheckSuperAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        if (Gate::allows('is-super-admin')) {
            return $next($request);
        }
        return response()->json(['message' => 'Administrator access required.'], 403);
    }
}