<?php

namespace App\Services;

use App\Models\Job\JobContracttype;
use App\Models\Job\JobDegreelevel;
use App\Models\Job\JobSector;
use App\Models\Job\JobType;
use App\Models\Job\JobWorkingtype;
use App\Models\Sys\SysCurrency;
use App\Models\Sys\SysSex;
use Illuminate\Support\Facades\Cache;
use Illuminate\Database\Eloquent\Collection;

class MetadataService
{
    // Cache for 1 day
    const CACHE_TTL = 86400; 

    private function getAndCache(string $key, string $modelClass, string $primaryKey): Collection
    {
        return Cache::remember($key, self::CACHE_TTL, function () use ($modelClass, $primaryKey) {
            return $modelClass::query()->get()->keyBy($primaryKey);
        });
    }

    public function getJobTypes(): Collection       { return $this->getAndCache('metadata:job_types', JobType::class, 'JobTypeID'); }
    public function getJobSectors(): Collection     { return $this->getAndCache('metadata:job_sectors', JobSector::class, 'JobSectorID'); }
    public function getWorkingTypes(): Collection   { return $this->getAndCache('metadata:working_types', JobWorkingtype::class, 'WorkingTypeID'); }
    public function getContractTypes(): Collection  { return $this->getAndCache('metadata:contract_types', JobContracttype::class, 'ContractTypeID'); }
    public function getDegreeLevels(): Collection   { return $this->getAndCache('metadata:degree_levels', JobDegreelevel::class, 'DegreeLevelID'); }
    public function getCurrencies(): Collection     { return $this->getAndCache('metadata:currencies', SysCurrency::class, 'CurrencyID'); }
    public function getSexes(): Collection          { return $this->getAndCache('metadata:sexes', SysSex::class, 'SexID'); }
}