<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class CompanyInternalController extends Controller
{
    public function getBatchInfo(Request $request)
    {
        // API này đã chuyển sang Job Service do data Company nằm ở đó.
        return response()->json([]);
    }
}