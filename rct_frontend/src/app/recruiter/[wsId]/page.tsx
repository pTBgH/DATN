import Link from "next/link";
import { jobApi, workspaceApi } from "@/lib/api";
import { Stat } from "@/components/Stat";

export const dynamic = "force-dynamic";

export default async function WorkspaceDashboardPage({
  params,
}: {
  params: { wsId: string };
}) {
  const [ws, jobs] = await Promise.all([
    workspaceApi.getWorkspace(params.wsId),
    jobApi.listWorkspaceJobs(params.wsId),
  ]);

  return (
    <div className="space-y-6">
      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Stat label="Active jobs" value={ws.active_jobs} />
        <Stat label="Views" value={ws.views.toLocaleString("vi-VN")} />
        <Stat label="Applications" value={ws.applications.toLocaleString("vi-VN")} />
        <Stat label="Apply rate" value={`${ws.apply_rate}%`} />
      </section>

      <section>
        <div className="mb-3 flex items-baseline justify-between">
          <h2 className="text-lg font-semibold">Tin tuyển dụng gần đây</h2>
          <Link
            href={`/recruiter/${ws.id}/jobs`}
            className="text-sm text-brand hover:underline"
          >
            Xem tất cả →
          </Link>
        </div>
        <ul className="space-y-3">
          {jobs.data.slice(0, 5).map((j) => (
            <li key={j.job_id}>
              <Link
                href={`/recruiter/${ws.id}/jobs/${j.job_id}`}
                className="block rounded-lg border bg-white p-4 hover:border-brand"
              >
                <div className="flex items-baseline justify-between">
                  <div>
                    <div className="font-semibold">{j.title}</div>
                    <div className="mt-1 text-xs text-slate-500">
                      {j.status} · Deadline {j.deadline}
                    </div>
                  </div>
                  <div className="text-right text-xs text-slate-500">
                    {j.view_count} views · {j.apply_count} applies
                  </div>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
