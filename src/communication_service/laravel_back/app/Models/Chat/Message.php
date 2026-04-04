<?php

namespace App\Models\Chat;

use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasUuids;

class Message extends Model
{
    use HasUuids;
    protected $table = 'con_messages';
    protected $primaryKey = 'MessageID';
    public $incrementing = false;
    protected $keyType = 'string';
    public $timestamps = false; // Bảng này chỉ có CreatedAt

    protected $fillable = ['MessageID', 'ConversationID', 'SenderID', 'Content', 'CreatedAt'];
}