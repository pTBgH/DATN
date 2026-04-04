<?php

namespace App\Models\Recruiter;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids;
use Illuminate\Foundation\Auth\User as Authenticatable;
use App\Models\Job\JobSector;
// use App\Models\Recruiter\RecruiterStatus;
// use App\Models\Recruiter\RecruiterRole;
use Illuminate\Database\Eloquent\Relations\BelongsToMany as BelongsToMany; 
use App\Models\Job\JobCompany;
use App\Models\Workspace;

class Recruiter extends Authenticatable
{
    use HasFactory, HasUuids;

    protected $table = 'rct_profiles';
    protected $primaryKey = 'RecruiterID';

    const CREATED_AT = "CreatedAt";
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = [
        'UserName',
        'Email',
        'KeycloakUserID',
        'StatusID',
        'PhoneNumber',
        'FirstName',
        'LastName',
    ];

    protected $casts = [
        'StatusID' => 'integer',
        'CreatedAt' => 'datetime', 
        'UpdatedAt' => 'datetime',
    ];

    // public function status()
    // {
    //     return $this->belongsTo(RecruiterStatus::class, 'StatusID', 'StatusID');
    // }
    
    public function workspaces(): BelongsToMany
    {
        return $this->belongsToMany(
            Workspace::class,
            'workspace_members',
            'RecruiterID',
            'WorkspaceID'
        )->withPivot([
            // CÁC CỘT MỚI (snake_case)
            'workspace_permissions',
            'job_permissions',
            'candidate_permissions',
            'pipeline_permissions',
            'status_id', // Đã đổi từ StatusID
            'created_at', // Đã đổi từ CreatedAt
            'updated_at'
        ])
        ->withTimestamps('created_at', 'updated_at'); 
    }
}
