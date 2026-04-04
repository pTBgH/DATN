<?php

namespace App\Models\Hiring;

use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids; // Sử dụng Trait UUIDv7 của hệ thống
use App\Models\Job\JobApplication;

class Interview extends Model
{
    use HasUuids;

    protected $table = 'interviews';
    protected $primaryKey = 'InterviewID';
    public $incrementing = false;
    protected $keyType = 'string';

    public $timestamps = false;

    protected $fillable = [
        'InterviewID',   // Được HasUuids tự sinh, nhưng thêm vào đây để an toàn
        'ApplicationID',
        'StartTime',
        'EndTime',
        'Status',        // Scheduled, Completed, Cancelled
        'Location',      // Link họp hoặc địa chỉ
        'CreatedAt',
        'Note',
        'Feedback'
    ];

    protected $casts = [
        'StartTime' => 'datetime',
        'EndTime'   => 'datetime',
        'CreatedAt' => 'datetime',
    ];

    /**
     * Quan hệ với bảng job_applications
     */
    public function application()
    {
        return $this->belongsTo(JobApplication::class, 'ApplicationID', 'ApplicationID');
    }
}