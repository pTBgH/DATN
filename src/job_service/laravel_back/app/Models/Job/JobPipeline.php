<?php

namespace App\Models\Job;

use Illuminate\Database\Eloquent\Model;

class JobPipeline extends Model
{
    protected $table = 'job_pipelines';
    protected $primaryKey = 'PipelineID';
    public $incrementing = false;
    protected $keyType = 'string';
    
    // Tắt timestamps nếu bảng này chỉ để read và sync đơn giản
    public $timestamps = false; 

    protected $fillable = ['PipelineID', 'Name', 'IsDefault'];
}