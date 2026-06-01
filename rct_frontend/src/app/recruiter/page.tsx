"use client";

import Link from "next/link";
import { workspaceApi } from "@/lib/api";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function RecruiterHomePage() {
  const { data: workspaces, loading, error } = useAuthedFetch(
    () => workspaceApi.getMyWorkspaces(),
    [],
  );

  if (loading) return <PageLoading label="Đang tải workspace..." />;
  if (error) return <PageError message={error} />;

  const list = workspaces ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Workspace Của Tôi</h1>
          <p className="mt-1 text-slate-600">Quản lý các workspace tuyển dụng của công ty</p>
        </div>
        <Button variant="primary" size="lg">
          + Tạo Workspace
        </Button>
      </div>

      {list.length === 0 ? (
        <Card className="py-12 text-center bg-gray-50 border border-gray-200">
          <div className="space-y-4">
            <div className="text-4xl text-gray-400">[ WS ]</div>
            <div>
              <p className="font-semibold text-slate-900">Chưa có workspace nào</p>
              <p className="mt-1 text-sm text-slate-600">
                Hãy tạo workspace đầu tiên để bắt đầu quản lý tuyển dụng
              </p>
            </div>
            <Button variant="primary">Tạo Workspace Mới</Button>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          <div className="rounded-lg bg-blue-50 border border-blue-200 p-4">
            <p className="text-sm text-blue-900">
              Bạn có <span className="font-semibold">{list.length}</span> workspace.
              Chọn workspace để xem chi tiết tuyển dụng.
            </p>
          </div>

          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {list.map((w) => (
              <Link
                key={w.id}
                href={`/recruiter/${w.id}`}
              >
                <Card hover className="h-full space-y-4 bg-white border border-gray-200">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1">
                      <h3 className="text-lg font-semibold text-slate-900 line-clamp-1">
                        {w.name}
                      </h3>
                      <p className="text-sm text-slate-600">
                        {w.email}
                      </p>
                    </div>
                    <Badge variant="primary" size="sm">
                      {w.plan ?? "Free"}
                    </Badge>
                  </div>

                  <div className="space-y-2 pt-2 border-t border-gray-100">
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-slate-600">Công Việc Hoạt Động</span>
                      <span className="font-bold text-blue-600">{w.active_jobs}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-slate-600">Lượt Xem</span>
                      <span className="font-bold text-slate-900">{w.views.toLocaleString("vi-VN")}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-slate-600">Tỷ Lệ Ứng Tuyển</span>
                      <span className="font-bold text-orange-600">{w.apply_rate}%</span>
                    </div>
                  </div>

                  <Button variant="outline" size="md" className="w-full">
                    Truy Cập →
                  </Button>
                </Card>
              </Link>
            ))}
          </div>
        </div>
      )}

      <Card className="bg-gradient-to-r from-blue-50 to-cyan-50">
        <div className="flex items-start gap-3 p-4">
          <div className="text-2xl">💡</div>
          <div>
            <p className="font-semibold text-slate-900">Mẹo Quản Lý Workspace</p>
            <ul className="mt-2 space-y-1 text-sm text-slate-700">
              <li>• Mỗi workspace là một công ty hoặc phòng ban riêng</li>
              <li>• Mời thành viên vào workspace để hợp tác cùng nhau</li>
              <li>• Theo dõi chỉ số công việc để tối ưu hóa quá trình tuyển dụng</li>
            </ul>
          </div>
        </div>
      </Card>
    </div>
  );
}
