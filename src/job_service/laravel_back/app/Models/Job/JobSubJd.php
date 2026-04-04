<?php
namespace App\Models\Job;

use App\Enums\JobStatusEnum;
use App\Models\Job\JobCompany;
use App\Services\MetadataService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Casts\Attribute;
use App\Models\Job\JobStat;
use App\Models\Traits\HasUuids; // 1. Import Trait
use Illuminate\Support\Facades\Log;
use App\Support\Logging\StructuredLogger;


use App\Models\Job\JobPipeline;

class JobSubJd extends Model
{
    use HasFactory, HasUuids;
    
    protected $table = 'job_sub_jds';
    protected $primaryKey = 'JobID';
    public $incrementing = false;
    protected $keyType = 'string';

    const CREATED_AT = "CreatedAt";
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = [
        'JobID', 'CompanyID', 'PipelineID', 'status', 'Version', 'pending_data',
        'Title', 'slug', 'SourceID', 'FlagID',
        
        // Nhóm phân loại
        'JobSectorID', 'JobTypeID', 'WorkingTypeID', 'ContractTypeID', 'DegreeLevelID', 'SexID',
        
        // Nhóm lương & hạn
        'MinSalary', 'MaxSalary', 'CurrencyID', 
        'ExperienceYear', 'MinAge', 'MaxAge', 
        'OpenDate', 'EndDate',
        
        // Nhóm nội dung (Tên mới)
        'Description',   // Thay cho Job_Description
        'Requirements',  // Thay cho Job_Requirements
        'Benefits',      // Thay cho Job_Benefits
        
        // Nhóm legacy/text
        'MainDescription', 'Experience', 'Degree', 
        'TechnicalSkill', 'SoftSkill', 'Keywords',
        
        // Nhóm liên kết
        'JobLink', 'job_link_chat', 'PictureUrl', 'detail_address', 'LocationID'
    ];

    protected $casts = [        
        'OpenDate' => 'datetime',
        'EndDate' => 'datetime',
        'CreatedAt' => 'datetime',
        'UpdatedAt' => 'datetime',
    ];

    protected function status(): Attribute
    {
        return Attribute::make(
            get: fn ($value) => JobStatusEnum::tryFrom($value) ?? JobStatusEnum::DRAFT,
            set: fn ($value) => ($value instanceof JobStatusEnum) ? $value->value : $value,
        );
    }

    // public function companyInfo(): BelongsTo
    // {
    //     return $this->belongsTo(JobCompany::class, 'CompanyID', 'CompanyID');
    // }

    public function snapshots(): HasMany
    {
        return $this->hasMany(JobJdSnapshot::class, 'JobID', 'JobID')->orderBy('Version', 'desc');
    }

    public function changes(): HasMany
    {
        return $this->hasMany(JobJdChange::class, 'JobID', 'JobID')->orderBy('Version', 'desc');
    }

    public function jobJd(): HasOne
    {
        return $this->hasOne(JobJd::class, 'JobID', 'JobID');
    }

    public function jobStat(): HasOne
    {
        return $this->hasOne(JobStat::class, 'job_id', 'JobID');
    }

    public function pipeline()
    {
        return $this->belongsTo(JobPipeline::class, 'PipelineID', 'PipelineID');
    }

    private function getMetadataName(string $method, ?int $id, string $nameProperty): ?string
    {
        if (is_null($id)) return null;
        $collection = app(MetadataService::class)->$method();
        return $collection->get($id)?->$nameProperty;
    }

    public function getJobTypeNameAttribute(): ?string       { return $this->getMetadataName('getJobTypes', $this->JobTypeID, 'JobTypeName'); }
    public function getJobSectorNameAttribute(): ?string     { return $this->getMetadataName('getJobSectors', $this->JobSectorID, 'JobSectorName'); }
    public function getWorkingTypeNameAttribute(): ?string   { return $this->getMetadataName('getWorkingTypes', $this->WorkingTypeID, 'WorkingTypeName'); }
    public function getContractTypeNameAttribute(): ?string  { return $this->getMetadataName('getContractTypes', $this->ContractTypeID, 'ContractTypeName'); }
    public function getDegreeLevelNameAttribute(): ?string   { return $this->getMetadataName('getDegreeLevels', $this->DegreeLevelID, 'DegreeLevelName'); }
    public function getCurrencyCodeAttribute(): ?string    { return $this->getMetadataName('getCurrencies', $this->CurrencyID, 'CurrencyCode'); }
    public function getSexNameAttribute(): ?string           { return $this->getMetadataName('getSexes', $this->SexID, 'SexName'); }
}