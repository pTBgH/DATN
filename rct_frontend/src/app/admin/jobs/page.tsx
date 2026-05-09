import { adminApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function AdminJobsPage() {
  const pending = await adminApi.listPendingJobs();
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Duyệt tin tuyển dụng</h1>
      <p className="text-sm text-slate-500">
        {pending.length} tin đang chờ duyệt. Bấm “Duyệt” sẽ gọi
        `PATCH /api/admin/jobs/{"{id}"}/approve` (mock-only ở skeleton).
      </p>

      <ul className="space-y-3">
        {pending.map((j) => (
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
                  Workspace {j.workspace_name} · Submitted{" "}
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
