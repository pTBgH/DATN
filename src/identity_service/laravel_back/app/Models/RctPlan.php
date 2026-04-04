<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RctPlan extends Model
{
    use HasFactory;

    protected $table = 'rct_plans';
    protected $primaryKey = 'PlanID';
    public $timestamps = true; // Giữ lại vì bảng có CreatedAt/UpdatedAt

    // Không cần fillable nếu bạn không tạo plan từ code
}