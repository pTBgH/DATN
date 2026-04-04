<?php

namespace App\Models\Hiring;

use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids; // Đảm bảo trait này có trong Hiring Service

class HiringExecution extends Model
{
    use HasUuids;

    protected $table = 'hiring_executions';
    protected $primaryKey = 'ExecutionID';
    public $incrementing = false;
    protected $keyType = 'string';

    // Tắt timestamp mặc định vì bảng này dùng StartedAt/FinishedAt
    public $timestamps = false; 

    protected $fillable = [
        'ExecutionID', 
        'PipelineID', 
        'ApplicationID', 
        'TriggerNodeID',
        'Status', 
        'CurrentNode', 
        'ExecutionData', 
        'Logs',
        'StartedAt', 
        'FinishedAt'
    ];

    protected $casts = [
        'ExecutionData' => 'array', // Tự động chuyển JSON <-> Array
        'Logs'          => 'array',
        'StartedAt'     => 'datetime',
        'FinishedAt'    => 'datetime'
    ];
}