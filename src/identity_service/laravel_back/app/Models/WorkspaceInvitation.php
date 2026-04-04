<?php

namespace App\Models;

use App\Models\Traits\HasUuids; 
use Illuminate\Database\Eloquent\Model;

class WorkspaceInvitation extends Model
{
    use HasUuids;

    protected $table = 'workspace_invitations';
    protected $primaryKey = 'InvitationID';
    
    public $timestamps = true; 

    protected $fillable = [
        'WorkspaceID',
        'InvitedBy',
        'email',       
        'permissions',
        'token',
        'code',
        'expires_at',
    ];

    protected $casts = [
        'permissions' => 'array',
        'expires_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function workspace()
    {
        return $this->belongsTo(\App\Models\Workspace::class, 'WorkspaceID', 'WorkspaceID');
    }

    public function inviter()
    {
        return $this->belongsTo(\App\Models\Recruiter\Recruiter::class, 'InvitedBy', 'RecruiterID');
    }
}