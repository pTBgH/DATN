<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class JobDegreelevel extends Model {
    protected $table = 'job_degreelevels';
    protected $primaryKey = 'DegreeLevelID';
    public $timestamps = false;
}