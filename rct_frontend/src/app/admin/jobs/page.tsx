"use client";

import { adminApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function AdminJobsPage() {
  const { data: pending, loading, error } = useAuthedFetch(
    () => adminApi.listPendingJobs(),
    [],
  );

  if (loading) return <PageLoading label="Đang tải công việc..." />;
  if (error) return <PageError message={error} />;

  const list = pending ?? [];
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Duyệt tin tuyển dụng</h1>
      <p className="text-sm text-slate-500">
        {list.length} tin đang chờ duyệt. Kiểm tra nội dung, mức lương và hạn
        ứng tuyển trước khi quyết định.
      </p>

      <ul className="space-y-3">
        {list.map((j) => (
          <li
            key={j.job_id}
            className="rounded-lg border bg-white p-5"
          >
            <div className="flex items-baseline justify-between">
              <div>
                <div className="font-semibold">{j.title}</div>
                <div className="text-xs text-slate-500">
                  {j.company_name} · gửi bởi {j.recruiter_name} ({j.recruiter_email})
                </div>
                <div className="mt-1 text-xs text-slate-500">
                  Workspace {j.workspace_name} · gửi lúc{" "}
                  {new Date(j.submitted_at).toLocaleString("vi-VN")}
                </div>
              </div>
              <div className="flex gap-2">
                <button className="rounded border px-3 py-1.5 text-sm hover:bg-red-50">
                  Từ chối
                </button>
                <button className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark">
                  Duyệt
                </button>
              </div>
            </div>
            {j.description ? (
              <p className="mt-3 line-clamp-2 text-sm text-slate-600">
                {j.description}
              </p>
            ) : null}
            <div className="mt-2 flex flex-wrap gap-3 text-xs text-slate-500">
              <span>
                Lương: {j.salary_min?.toLocaleString("vi-VN")}-
                {j.salary_max?.toLocaleString("vi-VN")} VND
              </span>
              <span>Deadline: {j.deadline}</span>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
