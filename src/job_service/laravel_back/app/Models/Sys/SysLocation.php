<?php
namespace App\Models\Sys;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids;

class SysLocation extends Model 
{
    use HasUuids; // Tự sinh UUIDv7
    protected $table = 'sys_locations';
    protected $primaryKey = 'LocationID';
    public $incrementing = false;
    protected $keyType = 'string';
    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';
    protected $fillable = ['DetailLocation', 'CityID', 'DistrictID', 'Latitude', 'Longitude'];
}