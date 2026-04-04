<?php

namespace App\Models\Chat;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\Traits\HasUuids;

class Conversation extends Model
{
    use HasUuids;
    protected $table = 'con_conversations';
    protected $primaryKey = 'ConversationID';
    public $incrementing = false;
    protected $keyType = 'string';
    const CREATED_AT = 'CreatedAt';
    const UPDATED_AT = 'UpdatedAt';

    protected $fillable = ['ConversationID', 'WorkspaceID', 'Type'];

    public function participants()
    {
        return $this->hasMany(ConversationParticipant::class, 'ConversationID');
    }

    public function messages()
    {
        return $this->hasMany(Message::class, 'ConversationID')->orderBy('CreatedAt', 'desc');
    }
}