<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use App\Models\Traits\HasUuids; // Sử dụng Trait UUIDv7 của bạn

class User extends Authenticatable
{
    use HasFactory, Notifiable, HasUuids;

    // Map vào bảng usr_users
    protected $table = 'usr_users';
    
    // Khóa chính là UserID
    protected $primaryKey = 'UserID';
    
    // Tắt incrementing vì dùng UUID
    public $incrementing = false;
    protected $keyType = 'string';

    // Tên cột timestamp (khớp với DB của bạn)
    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = [
        'UserID',
        'KeycloakUserID',
        'Email',
        'UserName',
        'FirstName',
        'LastName',
        'PhoneNumber',
        'SexID',
        'LogoURL', // Avatar
        'Description',
        'ExperienceYears',
        'Birth',
        'SocialLinks',
        'Alias'
    ];

    protected $casts = [
        'SocialLinks' => 'array',
        'Alias' => 'array',
        'Birth' => 'date',
        'CreatedAt' => 'datetime',
        'UpdatedAt' => 'datetime',
    ];
}