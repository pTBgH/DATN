/**
 * Communication Service — DTOs.
 * NOTE: ChatController in src/communication_service does NOT wrap models in
 * a Resource, so the response is the raw Eloquent payload (PascalCase keys).
 */

export interface Conversation {
  ConversationID: string;
  WorkspaceID: string;
  Type: string;
  participants: Array<{ UserID: string; role?: string }>;
  last_message?: Message;
  CreatedAt: string;
  UpdatedAt: string;
}

export interface Message {
  MessageID: string;
  ConversationID: string;
  SenderID: string;
  Content: string;
  CreatedAt: string;
}

export interface CreateConversationInput {
  target_user_id: string;
  workspace_id: string;
}

export interface SendMessageInput {
  conversation_id: string;
  content: string;
}
