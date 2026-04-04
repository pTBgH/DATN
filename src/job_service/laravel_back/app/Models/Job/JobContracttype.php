<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class JobContracttype extends Model {
    protected $table = 'job_contracttypes';
    protected $primaryKey = 'ContractTypeID';
    public $timestamps = false;
}