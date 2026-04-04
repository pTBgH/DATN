<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Models\Job\JobCompanySize;
use App\Models\Job\JobIndustry;
use App\Models\Sys\SysCity;
use App\Models\Sys\SysDistrict;
use Illuminate\Http\Request;

class MetadataController extends Controller
{
    /**
     * API lấy toàn bộ danh mục chung (Size, Industry, City)
     * GET /api/metadata/common
     */
    public function getCommon()
    {
        return response()->json([
            'sizes'      => JobCompanySize::all(['SizeID as id', 'SizeName as name']),
            'industries' => JobIndustry::all(['IndustryID as id', 'IndustryName as name']),
            'cities'     => SysCity::orderBy('CityName')->get(['CityID as id', 'CityName as name']),
        ]);
    }

    /**
     * API lấy Quận/Huyện theo CityID (Khi người dùng chọn Thành phố thì gọi cái này)
     * GET /api/metadata/districts/{city_id}
     */
    public function getDistricts($cityId)
    {
        $districts = SysDistrict::where('CityID', $cityId)
            ->orderBy('DistrictName')
            ->get(['DistrictID as id', 'DistrictName as name']);
            
        return response()->json($districts);
    }
}