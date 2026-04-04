<?php

namespace App\Models;

use App\Models\Job\JobCompany;
use App\Models\Recruiter\Recruiter; // Hoặc tên model user của bạn
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids;
use App\Models\RctPlan;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use App\Models\Hiring\HiringPipeline;

class Workspace extends Model
{
    use HasUuids; // Sử dụng trait này nếu bạn muốn Laravel tự tạo UUID

    protected $table = 'workspaces';
    protected $primaryKey = 'WorkspaceID';
    public $timestamps = true;

    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = [
        'WorkspaceID',
        'Email',
        'PlanID',
        'UsageCount',
    ];

    public function companyProfile()
    {
        return $this->hasOne(JobCompany::class, 'CompanyID', 'WorkspaceID');
    }

    public function members()
    {
        return $this->belongsToMany(
            Recruiter::class,
            'workspace_members',
            'WorkspaceID',
            'RecruiterID'
        )
        ->withPivot([
            // CÁC CỘT MỚI
            'workspace_permissions',
            'job_permissions',
            'candidate_permissions',
            'pipeline_permissions',
            'status_id',
            'created_at',
            'updated_at'
        ])
        ->withTimestamps('created_at', 'updated_at'); 
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(RctPlan::class, 'PlanID', 'PlanID');
    }

    public function pipelines(): HasMany
    {
        return $this->hasMany(HiringPipeline::class, 'WorkspaceID', 'WorkspaceID');
    }

    public function defaultPipeline(): HasOne
    {
        return $this->hasOne(HiringPipeline::class, 'WorkspaceID', 'WorkspaceID')
                    ->where('IsDefault', true);
    }
}