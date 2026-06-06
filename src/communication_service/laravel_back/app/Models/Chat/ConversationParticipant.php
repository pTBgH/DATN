<?php

namespace App\Models\Chat;

use Illuminate\Database\Eloquent\Model;

class ConversationParticipant extends Model
{
    protected $table = 'con_conversation_participants';
    
    // There are no standard created_at / updated_at timestamps
    public $timestamps = false;
    
    // Composite key, so we don't have a single auto-increment primary key
    public $incrementing = false;
    protected $primaryKey = null;

    protected $fillable = [
        'ConversationID',
        'UserID',
        'JoinedAt'
    ];

    /**
     * Handle composite keys for save query if needed.
     */
    protected function setKeysForSaveQuery($query)
    {
        $query->where('ConversationID', '=', $this->getAttribute('ConversationID'))
              ->where('UserID', '=', $this->getAttribute('UserID'));
        return $query;
    }
}
