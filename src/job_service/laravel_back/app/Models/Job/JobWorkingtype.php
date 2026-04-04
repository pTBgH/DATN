<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class JobWorkingtype extends Model {
    protected $table = 'job_workingtypes';
    protected $primaryKey = 'WorkingTypeID';
    public $timestamps = false;
}