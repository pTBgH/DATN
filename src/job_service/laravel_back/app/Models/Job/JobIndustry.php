<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class JobIndustry extends Model {
    protected $table = 'job_industries';
    protected $primaryKey = 'IndustryID';
    public $timestamps = false;
    protected $fillable = ['IndustryName'];
}