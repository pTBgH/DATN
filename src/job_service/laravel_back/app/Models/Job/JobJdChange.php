<?php

namespace App\Models\Job;

use App\Models\Traits\HasUuids; 
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JobJdChange extends Model
{
    use HasUuids; 
    /** Tên bảng */
    protected $table = 'job_jd_changes';

    /** Khóa chính */
    protected $primaryKey = 'ChangeID';

    /** Bảng này không sử dụng timestamps (updated_at) của Laravel */
    public $timestamps = false;

    public $incrementing = false;

    /** Các thuộc tính có thể gán hàng loạt */
    protected $fillable = [
        'JobID',
        'Version',
        'Field',
        'OldValue',
        'NewValue',
        'ChangedBy',
        'CreatedAt',
    ];

    /** Tự động cast các thuộc tính */
    protected $casts = [
        'CreatedAt' => 'datetime',
    ];

    /**
     * Lấy job chính mà thay đổi này thuộc về.
     */
    public function jobSubJd(): BelongsTo
    {
        // Liên kết: khóa ngoại 'JobID' của bảng này -> khóa chính 'JobID' của bảng job_sub_jds
        return $this->belongsTo(JobSubJd::class, 'JobID', 'JobID');
    }
}