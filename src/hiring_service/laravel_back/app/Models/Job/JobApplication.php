<?php
namespace App\Models\Job;

use App\Models\Cv\Cv; // Import model Cv
use App\Models\Hiring\PipelineStage; // Import model PipelineStage
use App\Models\Traits\HasUuids;
use Illuminate\Database\Eloquent\Model;
use App\Models\Workspace;

class JobApplication extends Model
{
    use HasUuids;

    protected $table = 'job_applications';
    protected $primaryKey = 'ApplicationID';
    public $incrementing = false;
    protected $keyType = 'string';

    const CREATED_AT = "AppliedAt";
    const UPDATED_AT = 'UpdatedAt';
    
    protected $fillable = [
        'ApplicationID', 
        'JobID', 
        'CVID', 
        'WorkspaceID', 
        'ApplicantID', // ID ứng viên
        'StageID', 
        'StatusID',
        
        // --- CÁC CỘT SNAPSHOT (Đã có sẵn) ---
        'Name', 
        'Email', 
        'Phone', 
        'CvUrl',
        
        'AppliedAt',
        'UpdatedAt'
    ];

    public function stage() {
        return $this->belongsTo(PipelineStage::class, 'StageID', 'StageID');
    }

}