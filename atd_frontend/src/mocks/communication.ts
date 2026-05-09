import type { Conversation, Message } from "@/types/communication";

export const mockConversations: Conversation[] = [
  {
    ConversationID: "conv_01HZX01",
    WorkspaceID: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",
    Type: "direct",
    participants: [
      { UserID: "rec_01HZA0XK4N7H1GKD8ZYM2H8XQE", role: "recruiter" },
      { UserID: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE", role: "candidate" },
    ],
    last_message: {
      MessageID: "msg_01HZX02",
      ConversationID: "conv_01HZX01",
      SenderID: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE",
      Content: "Mình sẵn sàng phỏng vấn vào thứ 5 ạ.",
      CreatedAt: "2025-09-22T07:14:00.000000Z",
    },
    CreatedAt: "2025-09-13T11:00:00.000000Z",
    UpdatedAt: "2025-09-22T07:14:00.000000Z",
  },
];

export const mockMessages: Message[] = [
  {
    MessageID: "msg_01HZX01",
    ConversationID: "conv_01HZX01",
    SenderID: "rec_01HZA0XK4N7H1GKD8ZYM2H8XQE",
    Content: "Hi Minh, lịch phỏng vấn của bạn sẽ là thứ 5 lúc 10am nhé.",
    CreatedAt: "2025-09-22T07:13:00.000000Z",
  },
  {
    MessageID: "msg_01HZX02",
    ConversationID: "conv_01HZX01",
    SenderID: "usr_01HZB0XK4N7H1GKD8ZYM2H8XQE",
    Content: "Mình sẵn sàng phỏng vấn vào thứ 5 ạ.",
    CreatedAt: "2025-09-22T07:14:00.000000Z",
  },
];
