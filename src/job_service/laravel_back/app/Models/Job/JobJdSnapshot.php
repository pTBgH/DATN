<?php

namespace App\Models\Job;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Traits\HasUuids;

class JobJdSnapshot extends Model
{
    use HasUuids;

    /** Tên bảng */
    protected $table = 'job_jd_snapshot';

    /** Khóa chính */
    protected $primaryKey = 'SnapshotID';

    /** Bảng này không sử dụng timestamps (updated_at) của Laravel */
    public $timestamps = false;

    public $incrementing = false;

    /** Các thuộc tính có thể gán hàng loạt */
    protected $fillable = [
        'JobID',
        'Version',
        'Data',
        'SnapshotType',
        'CreatedBy',
        'CreatedAt',
    ];

    /** Tự động cast các thuộc tính */
    protected $casts = [
        'Data' => 'array',
        'CreatedAt' => 'datetime',
    ];

    /**
     * Lấy job chính mà snapshot này thuộc về.
     */
    public function jobSubJd(): BelongsTo
    {
        // Liên kết: khóa ngoại 'JobID' của bảng này -> khóa chính 'JobID' của bảng job_sub_jds
        return $this->belongsTo(JobSubJd::class, 'JobID', 'JobID');
    }
}