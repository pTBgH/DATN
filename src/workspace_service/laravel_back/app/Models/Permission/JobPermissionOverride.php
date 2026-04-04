<?php
namespace App\Models\Permission;

use Illuminate\Database\Eloquent\Model;

class JobPermissionOverride extends Model
{
    protected $table = 'per_job'; // Tên bảng chính xác
    public $incrementing = false;
    protected $primaryKey = null; // Composite key
    public $timestamps = false; // Bảng dùng assigned_at thay vì created_at/updated_at

    protected $fillable = ['job_id', 'recruiter_id', 'job_permissions', 'assigned_at'];
}