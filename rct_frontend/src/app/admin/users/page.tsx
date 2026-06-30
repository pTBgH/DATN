"use client";

import { adminApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function AdminUsersPage() {
  const { data: users, loading, error } = useAuthedFetch(
    () => adminApi.listAdminUsers(),
    [],
  );

  if (loading) return <PageLoading label="Đang tải người dùng..." />;
  if (error) return <PageError message={error} />;

  const list = users ?? [];
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Người dùng</h1>
      <p className="text-sm text-slate-500">
        Tổng {list.length} người dùng. Danh sách này dùng để theo dõi trạng
        thái tài khoản và lần đăng nhập gần nhất.
      </p>

      <table className="min-w-full divide-y rounded-lg border bg-white text-sm">
        <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
          <tr>
            <th className="px-4 py-2">Mã người dùng</th>
            <th className="px-4 py-2">Họ tên</th>
            <th className="px-4 py-2">Email</th>
            <th className="px-4 py-2">Role</th>
            <th className="px-4 py-2">Trạng thái</th>
            <th className="px-4 py-2">Đăng nhập gần nhất</th>
          </tr>
        </thead>
        <tbody className="divide-y text-sm">
          {list.map((u) => (
            <tr key={u.user_id} className="hover:bg-slate-50">
              <td className="px-4 py-2">
                <code className="text-xs">{u.user_id}</code>
              </td>
              <td className="px-4 py-2 font-medium">{u.full_name}</td>
              <td className="px-4 py-2">{u.email}</td>
              <td className="px-4 py-2">
                <span className="rounded bg-brand-50 px-2 py-0.5 text-xs text-brand">
                  {u.role}
                </span>
              </td>
              <td className="px-4 py-2">
                <span
                  className={
                    "rounded px-2 py-0.5 text-xs " +
                    (u.status === "Active"
                      ? "bg-green-100 text-green-700"
                      : u.status === "Pending"
                      ? "bg-amber-100 text-amber-700"
                      : "bg-red-100 text-red-700")
                  }
                >
                  {formatStatus(u.status)}
                </span>
              </td>
              <td className="px-4 py-2 text-xs text-slate-500">
                {u.last_login_at
                  ? new Date(u.last_login_at).toLocaleString("vi-VN")
                  : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function formatStatus(status: string) {
  if (status === "Active") return "Đang hoạt động";
  if (status === "Pending") return "Chờ xác nhận";
  if (status === "Suspended") return "Tạm khóa";
  return status;
}
