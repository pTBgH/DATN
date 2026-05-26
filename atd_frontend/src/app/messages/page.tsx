import Link from "next/link";
import { commApi } from "@/lib/api";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { truncateText } from "@/lib/formatters";

export const dynamic = "force-dynamic";

export default async function MessagesPage() {
  const conversations = await commApi.listConversations();

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Tin Nhắn</h1>
          <p className="mt-1 text-slate-600">Liên lạc trực tiếp với nhà tuyển dụng</p>
        </div>
        {conversations.length > 0 && (
          <Badge variant="info" size="md">
            💬 {conversations.length} cuộc trò chuyện
          </Badge>
        )}
      </div>

      {conversations.length === 0 ? (
        <Card className="py-12 text-center bg-gradient-to-br from-slate-50 to-slate-100">
          <div className="space-y-4">
            <div className="text-5xl">💬</div>
            <div>
              <p className="font-semibold text-slate-900">Chưa có tin nhắn nào</p>
              <p className="mt-1 text-sm text-slate-600">
                Khi bạn ứng tuyển công việc hoặc nhà tuyển dụng liên hệ, 
                tin nhắn sẽ xuất hiện ở đây
              </p>
            </div>
            <Link href="/jobs">
              <Button variant="primary">Tìm Việc Và Ứng Tuyển</Button>
            </Link>
          </div>
        </Card>
      ) : (
        <ul className="space-y-3">
          {conversations.map((c) => {
            const lastMessageTime = c.last_message
              ? new Date(c.last_message.CreatedAt || c.UpdatedAt)
              : new Date(c.UpdatedAt);
            const isRecent = Date.now() - lastMessageTime.getTime() < 24 * 60 * 60 * 1000;

            return (
              <li key={c.ConversationID}>
                <Card hover>
                  <div className="flex items-center gap-4">
                    <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-gradient-to-br from-cyan-100 to-blue-100 text-lg font-semibold text-cyan-700">
                      {c.Type === "direct" ? "1:1" : "👥"}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-baseline justify-between gap-2 mb-1">
                        <h3 className="font-semibold text-slate-900">
                          Workspace <span className="font-mono text-sm text-slate-500">#{c.WorkspaceID}</span>
                        </h3>
                        {isRecent && (
                          <Badge variant="primary" size="sm">🔔 Mới</Badge>
                        )}
                      </div>

                      <p className="line-clamp-1 text-sm text-slate-600">
                        {c.last_message?.Content 
                          ? truncateText(c.last_message.Content, 80)
                          : "(chưa có tin nhắn)"}
                      </p>

                      <p className="mt-1 text-xs text-slate-500">
                        {formatMessageTime(lastMessageTime)}
                      </p>
                    </div>

                    <Button variant="outline" size="md">
                      Mở →
                    </Button>
                  </div>
                </Card>
              </li>
            );
          })}
        </ul>
      )}

      <Card className="bg-gradient-to-r from-blue-50 to-cyan-50">
        <div className="flex items-start gap-3 p-4">
          <div className="text-2xl">💡</div>
          <div>
            <p className="font-semibold text-slate-900">Mẹo Liên Lạc</p>
            <ul className="mt-2 space-y-1 text-sm text-slate-700">
              <li>• Phản hồi nhanh để tăng khả năng được chọn</li>
              <li>• Hỏi rõ về vai trò, môi trường làm việc, lương thưởng</li>
              <li>• Giữ thái độ chuyên nghiệp và lịch sự trong mọi cuộc trò chuyện</li>
            </ul>
          </div>
        </div>
      </Card>
    </div>
  );
}

function formatMessageTime(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / (1000 * 60));
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffMins < 1) return "Vừa xong";
  if (diffMins < 60) return `${diffMins} phút trước`;
  if (diffHours < 24) return `${diffHours} giờ trước`;
  if (diffDays === 1) return "Hôm qua";
  if (diffDays < 7) return `${diffDays} ngày trước`;
  
  return date.toLocaleDateString("vi-VN");
}
