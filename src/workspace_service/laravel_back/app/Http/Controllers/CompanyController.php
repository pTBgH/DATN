<?php

namespace App\Http\Controllers;

use App\Http\Resources\CompanyResource;
use App\Services\CompanyService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CompanyController extends Controller
{
    protected CompanyService $companyService;

    public function __construct(CompanyService $companyService)
    {
        $this->companyService = $companyService;
    }

    /**
     * Lấy danh sách các workspace mà người dùng hiện tại là thành viên.
     * Route này sẽ được đổi tên thành myWorkspaces để rõ nghĩa hơn.
     */
    public function myCompanies(Request $request)
    {
        $recruiter = Auth::user();
        if (!$recruiter) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $workspaces = $this->companyService->getWorkspacesFor($recruiter);

        return CompanyResource::collection($workspaces);
    }
}