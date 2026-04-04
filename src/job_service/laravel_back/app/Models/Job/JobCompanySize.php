<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class JobCompanySize extends Model {
    protected $table = 'job_company_sizes';
    protected $primaryKey = 'SizeID';
    public $timestamps = false;
    protected $fillable = ['SizeName'];
}