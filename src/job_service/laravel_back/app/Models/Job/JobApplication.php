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
    
    protected $fillable = [ 'JobID', 'CVID', 'WorkspaceID', 'ApplicantID', 'StatusID', 'StageID' ];

    public function stage() {
        return $this->belongsTo(PipelineStage::class, 'StageID', 'StageID');
    }
    public function workspace() {
        return $this->belongsTo(Workspace::class, 'WorkspaceID', 'WorkspaceID');
    }
    public function cv() {
        return $this->belongsTo(Cv::class, 'CVID', 'CVID');
    }
    public function job() {
        return $this->belongsTo(JobSubJd::class, 'JobID', 'JobID');
    }
}