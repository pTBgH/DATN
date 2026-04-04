<?php

namespace App\Models\Sys;

use Illuminate\Database\Eloquent\Model;

class SysLocation extends Model 
{
    protected $table = 'sys_locations';
    protected $primaryKey = 'LocationID';

    // --- BỔ SUNG PHẦN NÀY ---
    protected $fillable = [
        'DetailLocation', // <--- Cột gây lỗi
        'Latitude',
        'Longitude'
    ];

    // Cấu hình lại tên cột Timestamp cho khớp với Database của bạn (PascalCase)
    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

}