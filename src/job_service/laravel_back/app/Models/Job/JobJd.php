<?php

namespace App\Models\Job;

use Illuminate\Database\Eloquent\Model;

class JobJd extends Model
{
    protected $table = 'job_jds';
    protected $primaryKey = 'JobID';
    public $incrementing = false;
    protected $keyType = 'string';

    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    // Khai báo rõ các trường để Listener updateOrCreate hoạt động an toàn
    protected $fillable = [
        'JobID', 'CompanyID', 'IsActive', 'slug', 'FlagID', 'SourceID',
    
        'Title', 
        'JobSectorID', 'JobTypeID', 'WorkingTypeID', 'DegreeLevelID', 'ContractTypeID', 'SexID',
        'ExperienceYear', 'MinAge', 'MaxAge',
        'MinSalary', 'MaxSalary', 'CurrencyID',
        'OpenDate', 'EndDate',

        // Tên cột mới
        'Description', 'Requirements', 'Benefits',
        
        'MainDescription', 'Experience', 'Degree', 
        'TechnicalSkill', 'SoftSkill', 'Keywords',
        
        'JobLink', 'job_link_chat', 'PictureUrl', 'detail_address', 'LocationID',
        
        'ViewCount', 'ApplyCount'
    ];

    // Định dạng dữ liệu trả về JSON
    protected $casts = [
        'IsActive'  => 'boolean',
        'OpenDate'  => 'datetime:Y-m-d', // Trả về format chuẩn ngày
        'EndDate'   => 'datetime:Y-m-d',
        'CreatedAt' => 'datetime',
        'UpdatedAt' => 'datetime',
        'ViewCount' => 'integer',
        'ApplyCount'=> 'integer',
        'Salary_Max'=> 'integer',
        'Salary_Min'=> 'integer',
    ];

    // Tự động gán thuộc tính ảo để Frontend dễ dùng (giống cấu trúc enrich)
    protected $appends = ['company_name', 'company_logo'];

    public function company()
    {
        return $this->belongsTo(JobCompany::class, 'CompanyID', 'CompanyID');
    }

    public function getCompanyNameAttribute()
    {
        return $this->attributes['CompanyNameSnapshot'] ?? null;
    }

    public function getCompanyLogoAttribute()
    {
        return $this->attributes['CompanyLogoSnapshot'] ?? null;
    }
}