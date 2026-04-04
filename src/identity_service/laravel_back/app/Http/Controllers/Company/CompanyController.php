<?php
namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Models\Job\JobCompany;
use App\Http\Resources\CompanyResource;
use Illuminate\Http\Request;

class CompanyController extends Controller
{
    /**
     * Tìm kiếm công ty theo tên để hiển thị trong dropdown/autocomplete.
     */
    public function search(Request $request)
    {
        $request->validate(['query' => 'nullable|string|max:100']);

        $query = $request->input('query');

        $companies = JobCompany::where('IsActive', true)
            ->when($query, function ($q, $query) {
                $q->where('CompanyName', 'LIKE', "%{$query}%");
            })
            ->limit(20)
            ->get();

        return CompanyResource::collection($companies);
    }
}