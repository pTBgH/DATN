import { commApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function MessagesPage() {
  const conversations = await commApi.listConversations();
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Tin nhắn với nhà tuyển dụng</h1>
      <p className="text-sm text-slate-500">
        Endpoint: `GET /api/conversations` + `…/messages` (communication-service
        §6). Backend chưa expose realtime → frontend hiện chỉ poll qua REST.
      </p>
      {conversations.length === 0 ? (
        <div className="rounded border border-dashed bg-white p-8 text-center text-sm text-slate-500">
          Chưa có cuộc hội thoại.
        </div>
      ) : (
        <ul className="divide-y rounded-lg border bg-white">
          {conversations.map((c) => (
            <li key={c.ConversationID} className="flex items-center gap-3 p-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-50 text-brand">
                {c.Type === "direct" ? "1:1" : "G"}
              </div>
              <div className="flex-1">
                <div className="text-sm font-medium">
                  Workspace <code className="text-xs">{c.WorkspaceID}</code>
                </div>
                <div className="text-xs text-slate-500">
                  {c.last_message?.Content ?? "(chưa có tin nhắn)"}
                </div>
              </div>
              <div className="text-xs text-slate-400">
                {new Date(c.UpdatedAt).toLocaleString("vi-VN")}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
