<?php

namespace App\Services;

use App\Models\Chat\Conversation;
use App\Models\Chat\ConversationParticipant;
use App\Models\Chat\Message;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ChatService
{
    /**
     * Lấy danh sách hội thoại của User
     */
    public function getUserConversations(string $userId)
    {
        // Join để lấy tin nhắn cuối cùng (preview)
        // Đây là query phức tạp, làm đơn giản trước: Lấy list ID rồi load relation
        
        $conversationIds = ConversationParticipant::where('UserID', $userId)
            ->pluck('ConversationID');

        return Conversation::whereIn('ConversationID', $conversationIds)
            ->with(['messages' => function($q) {
                $q->limit(1); // Lấy tin mới nhất làm preview
            }])
            ->orderBy('UpdatedAt', 'desc')
            ->get();
    }

    /**
     * Gửi tin nhắn
     */
    public function sendMessage(string $conversationId, string $senderId, string $content)
    {
        // 1. Check xem user có trong hội thoại không
        $isParticipant = ConversationParticipant::where('ConversationID', $conversationId)
            ->where('UserID', $senderId)
            ->exists();

        if (!$isParticipant) {
            throw new \Exception("User is not a participant of this conversation.");
        }

        // 2. Tạo tin nhắn
        $msg = Message::create([
            'MessageID' => Str::uuid(),
            'ConversationID' => $conversationId,
            'SenderID' => $senderId,
            'Content' => $content,
            'CreatedAt' => now()
        ]);

        // 3. Update thời gian hội thoại (để nó nổi lên đầu)
        Conversation::where('ConversationID', $conversationId)->update(['UpdatedAt' => now()]);

        // TODO: Bắn Socket (Pusher/Redis) để Realtime ở đây
        // event(new MessageSent($msg));

        return $msg;
    }

    /**
     * Tìm hoặc Tạo hội thoại 1-1 (Direct)
     */
    public function getDirectConversation(string $userA, string $userB, string $workspaceId)
    {
        // Tìm hội thoại chung giữa 2 người
        // Logic SQL hơi phức tạp, tạm thời làm đơn giản:
        // Tìm các hội thoại của A, sau đó check xem B có trong đó không.
        
        $commonConversation = DB::table('con_conversation_participants as p1')
            ->join('con_conversation_participants as p2', 'p1.ConversationID', '=', 'p2.ConversationID')
            ->where('p1.UserID', $userA)
            ->where('p2.UserID', $userB)
            ->select('p1.ConversationID')
            ->first();

        if ($commonConversation) {
            return Conversation::find($commonConversation->ConversationID);
        }

        // Tạo mới
        return DB::transaction(function () use ($userA, $userB, $workspaceId) {
            $conv = Conversation::create([
                'ConversationID' => Str::uuid(),
                'WorkspaceID' => $workspaceId,
                'Type' => 'direct'
            ]);

            ConversationParticipant::insert([
                ['ConversationID' => $conv->ConversationID, 'UserID' => $userA, 'JoinedAt' => now()],
                ['ConversationID' => $conv->ConversationID, 'UserID' => $userB, 'JoinedAt' => now()],
            ]);

            return $conv;
        });
    }
}