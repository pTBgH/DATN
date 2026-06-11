<?php

namespace App\Http\Controllers;

use App\Services\MetadataService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class OptionController extends Controller
{
    private MetadataService $metadataService;

    public function __construct(MetadataService $metadataService)
    {
        $this->metadataService = $metadataService;
    }

    public function getGeneralOptions(): JsonResponse
    {
        $format = function($item, $key) {
            return [
                'id' => $key,
                'name' => $item->{$this->resolveNameProperty($item)}
            ];
        };

        $data = [
            'job_types' => $this->metadataService->getJobTypes()->map($format)->values(),
            'job_sectors' => $this->metadataService->getJobSectors()->map($format)->values(),
            'working_types' => $this->metadataService->getWorkingTypes()->map($format)->values(),
            'contract_types' => $this->metadataService->getContractTypes()->map($format)->values(),
            'degree_levels' => $this->metadataService->getDegreeLevels()->map($format)->values(),
            'currencies' => $this->metadataService->getCurrencies()->map($format)->values(),
            'sexes' => $this->metadataService->getSexes()->map($format)->values(),
        ];

        Log::channel('daily_normal')->info('Jusst to test');

        return response()->json($data);
    }

    public function getCities(): JsonResponse
    {
        $cities = DB::table('sys_cities')
                    // ->where('CountryID', 1)
                    ->orderBy('Order', 'desc')
                    ->orderBy('CityName', 'asc')
                    ->get(['CityID as id', 'CityName as name']);

        return response()->json($cities);
    }

    public function getDistrictsByCity(int $cityId): JsonResponse
    {
        $districts = DB::table('sys_districts')
                       ->where('CityID', $cityId)
                       ->orderBy('DistrictName', 'asc')
                       ->get(['DistrictID as id', 'DistrictName as name']);
                       
        return response()->json($districts);
    }

    private function resolveNameProperty($item): string
    {
        $properties = [
            'JobTypeName', 'JobSectorName', 'WorkingTypeName', 'ContractTypeName',
            'DegreeLevelName', 'CurrencyCode', 'SexName'
        ];

        foreach ($properties as $prop) {
            if (isset($item->{$prop})) {
                return $prop;
            }
        }
        return 'name';
    }

    public function getCompanyOptions(): JsonResponse
    {
        // Cache những dữ liệu này sẽ rất tốt cho hiệu năng
        $sizes = \App\Models\Job\JobCompanySize::query()->get(['SizeID as id', 'SizeName as name']);

        $industries = \App\Models\Job\JobIndustry::query()
            ->get(['IndustryID as id', 'IndustryName as name']);

        return response()->json([
            'sizes' => $sizes,
            'industries' => $industries,
        ]);
    }
}