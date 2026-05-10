import { config } from "@/lib/config";
import { mockConversations, mockMessages } from "@/mocks/communication";
import type {
  Conversation,
  CreateConversationInput,
  Message,
  SendMessageInput,
} from "@/types/communication";
import { apiFetch } from "./client";

export async function listConversations(): Promise<Conversation[]> {
  if (config.useMock) return Promise.resolve(mockConversations);
  return apiFetch<Conversation[]>("/api/conversations");
}

export async function createConversation(
  input: CreateConversationInput,
): Promise<Conversation> {
  if (config.useMock) return Promise.resolve(mockConversations[0]);
  return apiFetch<Conversation>("/api/conversations", {
    method: "POST",
    body: input,
  });
}

export async function getMessages(conversationId: string): Promise<Message[]> {
  if (config.useMock) return Promise.resolve(mockMessages);
  const r = await apiFetch<{ data: Message[] }>(
    `/api/conversations/${encodeURIComponent(conversationId)}/messages`,
  );
  return r.data;
}

export async function sendMessage(input: SendMessageInput): Promise<Message> {
  if (config.useMock) {
    return Promise.resolve({
      MessageID: `msg_mock_${Date.now()}`,
      ConversationID: input.conversation_id,
      SenderID: "rec_01HZA0XK4N7H1GKD8ZYM2H8XQE",
      Content: input.content,
      CreatedAt: new Date().toISOString(),
    });
  }
  return apiFetch<Message>("/api/messages", {
    method: "POST",
    body: input,
  });
}
