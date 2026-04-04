<?php
namespace App\Models\Hiring;
use App\Models\Traits\HasUuids;
use Illuminate\Database\Eloquent\Model;

class PipelineStage extends Model
{
    use HasUuids;
    protected $table = 'rct_pipeline_stages';
    protected $primaryKey = 'StageID';
    public $incrementing = false;
    protected $keyType = 'string';
    const CREATED_AT = "CreatedAt";
    const UPDATED_AT = 'UpdatedAt';
    protected $fillable = ['PipelineID', 'Name', 'StageOrder', 'Color', 'IsSystemStage'];
    protected $casts = ['IsSystemStage' => 'boolean', 'StageOrder' => 'integer'];
}