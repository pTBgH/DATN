"use client";

import { adminApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function AdminSectorsPage() {
  const { data: sectors, loading, error } = useAuthedFetch(
    () => adminApi.listSectors(),
    [],
  );

  if (loading) return <PageLoading label="Đang tải ngành nghề..." />;
  if (error) return <PageError message={error} />;

  const list = sectors ?? [];
  return (
    <div className="space-y-4">
      <header className="flex items-baseline justify-between">
        <h1 className="text-2xl font-semibold">Ngành nghề</h1>
        <button className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark">
          + Tạo ngành nghề
        </button>
      </header>
      <p className="text-sm text-slate-500">
        Duy trì danh mục ngành nghề để dữ liệu tuyển dụng đồng nhất trên toàn hệ thống.
      </p>

      <table className="min-w-full divide-y rounded-lg border bg-white text-sm">
        <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
          <tr>
            <th className="px-4 py-2">ID</th>
            <th className="px-4 py-2">Tên</th>
            <th className="px-4 py-2">Mã</th>
            <th className="px-4 py-2">Số tin</th>
            <th className="px-4 py-2">Trạng thái</th>
            <th className="px-4 py-2"></th>
          </tr>
        </thead>
        <tbody className="divide-y text-sm">
          {list.map((s) => (
            <tr key={s.id} className="hover:bg-slate-50">
              <td className="px-4 py-2 text-slate-500">{s.id}</td>
              <td className="px-4 py-2 font-medium">{s.name}</td>
              <td className="px-4 py-2">
                <code className="text-xs">{s.code}</code>
              </td>
              <td className="px-4 py-2">{s.job_count}</td>
              <td className="px-4 py-2">
                <span
                  className={
                    "rounded px-2 py-0.5 text-xs " +
                    (s.active
                      ? "bg-green-100 text-green-700"
                      : "bg-slate-100 text-slate-500")
                  }
                >
                  {s.active ? "Đang dùng" : "Tạm ẩn"}
                </span>
              </td>
              <td className="px-4 py-2 text-right">
                <button className="text-xs text-slate-500 hover:text-brand">
                  Sửa
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
