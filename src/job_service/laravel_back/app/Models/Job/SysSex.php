<?php
namespace App\Models\Job;
use Illuminate\Database\Eloquent\Model;
class SysSex extends Model {
    protected $table = 'sys_sex';
    protected $primaryKey = 'SexID';
    public $timestamps = false;
}