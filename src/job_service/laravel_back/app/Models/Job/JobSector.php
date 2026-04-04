<?php

namespace App\Models\Job;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JobSector extends Model
{
    use HasFactory;

    protected $table = 'job_sectors';
    protected $primaryKey = 'JobSectorID'; // Chỉ định nếu khóa chính không phải là 'id'

    protected $fillable = [
        'JobSectorName',
    ];
}