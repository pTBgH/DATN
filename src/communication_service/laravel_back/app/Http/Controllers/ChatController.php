<?php

namespace App\Http\Controllers;

use App\Services\ChatService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ChatController extends Controller
{
    protected ChatService $chatService;

    public function __construct(ChatService $chatService)
    {
        $this->chatService = $chatService;
    }

    // GET /api/conversations
    public function index()
    {
        return response()->json($this->chatService->getUserConversations(Auth::id()));
    }

    // POST /api/conversations (Tạo/Lấy hội thoại chat với ai đó)
    public function store(Request $request)
    {
        $request->validate([
            'target_user_id' => 'required',
            'workspace_id'   => 'required' // Chat trong ngữ cảnh nào
        ]);

        $conv = $this->chatService->getDirectConversation(
            Auth::id(), 
            $request->target_user_id,
            $request->workspace_id
        );

        return response()->json($conv);
    }

    // GET /api/conversations/{id}/messages
    public function messages($id)
    {
        // TODO: Check quyền xem user có trong conv này không
        $messages = \App\Models\Chat\Message::where('ConversationID', $id)
            ->orderBy('CreatedAt', 'asc') // Tin cũ trên, mới dưới
            ->paginate(50);
            
        return response()->json($messages);
    }

    // POST /api/messages
    public function sendMessage(Request $request)
    {
        $request->validate([
            'conversation_id' => 'required',
            'content' => 'required|string'
        ]);

        try {
            $msg = $this->chatService->sendMessage(
                $request->conversation_id,
                Auth::id(),
                $request->content
            );
            return response()->json($msg, 201);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 403);
        }
    }
}