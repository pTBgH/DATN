<?php

namespace App\Http\Controllers\Job;

use App\Http\Controllers\Controller;
use App\Models\Job\JobCompany;
use App\Models\Sys\SysLocation;
use App\Http\Resources\JobCompanyResource; // (File Resource bạn đã tạo ở bước trước)
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class JobCompanyController extends Controller
{
    /**
     * 1. Lấy thông tin chi tiết để hiển thị lên Form chỉnh sửa
     * GET /api/companies/{id}
     */
    public function show($id)
    {
        $company = JobCompany::with(['location', 'size', 'industry'])
            ->where('CompanyID', $id)
            ->first();

        if (!$company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        return new JobCompanyResource($company);
    }

    /**
     * 2. Lưu thông tin chỉnh sửa (Update)
     * PUT /api/companies/{id}
     */
    public function update(Request $request, $id)
    {
        $company = JobCompany::find($id);

        if (!$company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        // Validate dữ liệu đầu vào
        $validated = $request->validate([
            'name'        => 'sometimes|required|string|max:255',
            'website'     => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'logo'        => 'nullable|string',
            
            // Validate các ID danh mục
            'size_id'     => 'nullable|integer',
            'industry_id' => 'nullable|integer',
            
            // Validate Location
            'location'    => 'nullable|string|max:255', // Địa chỉ text
            'city_id'     => 'nullable|integer',
            'district_id' => 'nullable|integer',
        ]);

        try {
            DB::transaction(function () use ($company, $request) {
                
                // --- 1. XỬ LÝ LOCATION (Tạo mới hoặc Update) ---
                $hasLocationInfo = $request->hasAny(['location', 'city_id', 'district_id']);
                
                if ($hasLocationInfo) {
                    $locData = [];
                    if ($request->has('location'))    $locData['DetailLocation'] = $request->input('location', '');
                    if ($request->has('city_id'))     $locData['CityID']         = $request->input('city_id');
                    if ($request->has('district_id')) $locData['DistrictID']     = $request->input('district_id');

                    if ($company->LocationID) {
                        // Update
                        SysLocation::where('LocationID', $company->LocationID)->update($locData);
                    } else {
                        // Create New
                        // Đảm bảo DetailLocation không null
                        if (!isset($locData['DetailLocation'])) $locData['DetailLocation'] = '';
                        
                        $newLoc = SysLocation::create($locData);
                        $company->LocationID = $newLoc->LocationID;
                        $company->save(); // Lưu ngay để có FK
                    }
                }

                // --- 2. XỬ LÝ THÔNG TIN CÔNG TY ---
                $updateData = [];
                if ($request->has('name'))        $updateData['CompanyName'] = $request->input('name');
                if ($request->has('website'))     $updateData['Website']     = $request->input('website');
                if ($request->has('description')) $updateData['Description'] = $request->input('description');
                if ($request->has('logo'))        $updateData['PicturePath'] = $request->input('logo');
                if ($request->has('size_id'))     $updateData['SizeID']      = $request->input('size_id');
                if ($request->has('industry_id')) $updateData['IndustryID']  = $request->input('industry_id');

                if (!empty($updateData)) {
                    $company->update($updateData);
                }
            });

            // Trả về dữ liệu mới nhất
            return new JobCompanyResource($company->fresh(['location', 'size', 'industry']));

        } catch (\Exception $e) {
            Log::error("Update Company Failed: " . $e->getMessage());
            return response()->json(['message' => 'Update failed', 'error' => $e->getMessage()], 500);
        }
    }
}