<?php
namespace App\Models\Sys;
use Illuminate\Database\Eloquent\Model;
class SysCurrency extends Model {
    protected $table = 'sys_currencies';
    protected $primaryKey = 'CurrencyID';
    public $timestamps = false;
}