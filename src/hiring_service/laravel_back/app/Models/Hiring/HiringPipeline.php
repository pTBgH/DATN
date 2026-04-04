<?php
namespace App\Models\Hiring;
use App\Models\Traits\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class HiringPipeline extends Model
{
    use HasUuids;
    protected $table = 'rct_hiring_pipelines';
    protected $primaryKey = 'PipelineID';
    public $incrementing = false;
    protected $keyType = 'string';
    const CREATED_AT = "CreatedAt";
    const UPDATED_AT = 'UpdatedAt';
    protected $fillable = ['WorkspaceID', 'Name', 'IsDefault', 'WorkflowConfig', 'Settings'];

    public function stages(): HasMany
    {
        return $this->hasMany(PipelineStage::class, 'PipelineID', 'PipelineID')->orderBy('StageOrder');
    }

    protected $casts = [
        'IsDefault' => 'boolean',
        'WorkflowConfig' => 'array',
        'Settings' => 'array',
    ];
}