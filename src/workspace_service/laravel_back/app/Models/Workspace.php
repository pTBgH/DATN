<?php

namespace App\Models;

use App\Models\Recruiter\Recruiter;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use App\Models\Traits\HasUuids;

class Workspace extends Model
{
    use HasUuids;

    protected $table = 'workspaces';
    protected $primaryKey = 'WorkspaceID';
    
    // Cấu hình bắt buộc cho UUID key
    public $incrementing = false;
    protected $keyType = 'string';
    
    public $timestamps = true;
    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    // --- QUAN TRỌNG: Cập nhật danh sách này khớp với DB mới ---
    protected $fillable = [
        'WorkspaceID',
        'Name',   // <--- Phải có cái này mới lưu được tên
        'Logo',   // <--- Phải có cái này mới lưu được logo
        'Email',
    ];

    /**
     * Quan hệ thành viên (Giữ nguyên)
     */
    public function members(): BelongsToMany
    {
        return $this->belongsToMany(
            Recruiter::class,
            'workspace_members',
            'WorkspaceID',
            'RecruiterID'
        )
        ->withPivot([
            'workspace_permissions',
            'job_permissions',
            'candidate_permissions',
            'pipeline_permissions',
            'status_id',
            'created_at', // Cần lấy timestamp của bảng pivot
            'updated_at'
        ])
        ->withTimestamps(); 
    }
}