<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
use App\Models\Sys\SysLocation;
use App\Models\Job\JobCompanySize;
use App\Models\Job\JobIndustry;
use App\Models\Traits\HasUuids;

class JobCompany extends Model
{
    use HasUuids; // Tự sinh UUIDv7
    protected $table = 'job_companies';
    protected $primaryKey = 'CompanyID';
    public $incrementing = false;
    protected $keyType = 'string';
    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = [
        'CompanyID', 'CompanyID', 'CompanyName', 'IsActive', 'PicturePath', 
        'Description', 'SizeID', 'IndustryID', 'LocationID', 'Website'
    ];

    public function location() { return $this->belongsTo(SysLocation::class, 'LocationID', 'LocationID'); }
    public function size() { return $this->belongsTo(JobCompanySize::class, 'SizeID', 'SizeID'); }
    public function industry() { return $this->belongsTo(JobIndustry::class, 'IndustryID', 'IndustryID'); }
}