<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class JobType extends Model {
    protected $table = 'job_types';
    protected $primaryKey = 'JobTypeID';
    public $timestamps = false;
}