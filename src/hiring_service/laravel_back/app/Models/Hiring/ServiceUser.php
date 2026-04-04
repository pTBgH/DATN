<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ServiceUser extends Model
{
    protected $table = 'service_users';
    protected $primaryKey = 'internal_id';
    public $incrementing = false;
    protected $keyType = 'string';
    
    protected $fillable = ['internal_id', 'keycloak_id', 'email', 'name', 'type'];
}