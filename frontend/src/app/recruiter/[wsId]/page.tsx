import Link from "next/link";
import { jobApi, workspaceApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function WorkspaceDetailPage({
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
      <header className="flex items-baseline justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{ws.name}</h1>
          <div className="text-sm text-slate-500">
            {ws.email} · {ws.location ?? "—"}
          </div>
        </div>
        <Link
          href={`/recruiter/${ws.id}/jobs/new`}
          className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark"
        >
          Đăng tin mới
        </Link>
      </header>

      <section className="grid grid-cols-4 gap-3 rounded-lg border bg-white p-4 text-sm">
        <Stat label="Active jobs" value={ws.active_jobs} />
        <Stat label="Views" value={ws.views} />
        <Stat label="Applications" value={ws.applications} />
        <Stat label="Apply rate" value={`${ws.apply_rate}%`} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Tin tuyển dụng</h2>
        <ul className="space-y-3">
          {jobs.data.map((j) => (
            <li key={j.job_id}>
              <Link
                href={`/recruiter/${ws.id}/jobs/${j.job_id}`}
                className="block rounded-lg border bg-white p-4 hover:border-brand"
              >
                <div className="font-semibold">{j.title}</div>
                <div className="mt-1 text-xs text-slate-500">
                  {j.status} · Deadline {j.deadline} · {j.view_count} views ·{" "}
                  {j.apply_count} applies
                </div>
              </Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded border p-3 text-center">
      <div className="text-base font-semibold">{value}</div>
      <div className="text-[10px] uppercase tracking-wide text-slate-500">
        {label}
      </div>
    </div>
  );
}
