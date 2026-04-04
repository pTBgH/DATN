<?php
namespace App\Models\Sys;
use Illuminate\Database\Eloquent\Model;
class SysSex extends Model {
    protected $table = 'sys_sexes';
    protected $primaryKey = 'SexID';
    public $timestamps = false;
}