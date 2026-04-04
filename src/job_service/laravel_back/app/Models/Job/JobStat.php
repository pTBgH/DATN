<?php

namespace App\Models\Job;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JobStat extends Model
{
    protected $table = 'job_stats';
    protected $primaryKey = 'job_id'; // Khóa chính là job_id
    public $incrementing = false;
    protected $keyType = 'string';

    const CREATED_AT = 'created_at';
    const UPDATED_AT = 'updated_at';

    protected $fillable = [
        'job_id',
        'view_count',
        'apply_count',
    ];

    public function job(): BelongsTo
    {
        return $this->belongsTo(JobSubJd::class, 'job_id', 'JobID');
    }
}