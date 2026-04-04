<?php
namespace App\Models\Recruiter;
use Illuminate\Database\Eloquent\Model;

class RecruiterStatus extends Model
{
    protected $table = 'sys_rct_status';
    protected $primaryKey = 'StatusID';
    public $timestamps = false; // Bảng này không cần timestamps
}