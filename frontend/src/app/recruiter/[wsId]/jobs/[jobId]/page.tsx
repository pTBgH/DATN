import { hiringApi, jobApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function RecruiterJobDetail({
  params,
}: {
  params: { wsId: string; jobId: string };
}) {
  const [job, board] = await Promise.all([
    jobApi.getWorkspaceJob(params.wsId, params.jobId),
    hiringApi.getBoard(params.jobId),
  ]);

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">{job.title}</h1>
        <div className="text-sm text-slate-500">
          {job.status} · Deadline {job.deadline} · {job.view_count} views ·{" "}
          {job.apply_count} applies
        </div>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Hiring board</h2>
        <div className="grid auto-cols-[minmax(200px,1fr)] grid-flow-col gap-3 overflow-x-auto pb-2">
          {board.stages.map((s) => (
            <div key={s.stage_id} className="min-w-[220px] rounded-lg border bg-white">
              <header
                className="rounded-t-lg px-3 py-2 text-sm font-semibold"
                style={{ backgroundColor: s.color ?? "#f1f5f9" }}
              >
                {s.name}{" "}
                <span className="rounded bg-white/60 px-1.5 py-0.5 text-xs">
                  {s.candidates.length}
                </span>
              </header>
              <ul className="space-y-2 p-3 text-sm">
                {s.candidates.map((c) => (
                  <li
                    key={c.application_id}
                    className="rounded border bg-slate-50 p-2"
                  >
                    <div className="font-medium">{c.candidate_name}</div>
                    <div className="text-xs text-slate-500">
                      {c.candidate_email}
                    </div>
                    <div className="mt-1 text-[11px] text-slate-500">
                      score {c.score} ·{" "}
                      {new Date(c.applied_at).toLocaleDateString("vi-VN")}
                    </div>
                  </li>
                ))}
                {s.candidates.length === 0 ? (
                  <li className="text-xs text-slate-400">Chưa có ứng viên</li>
                ) : null}
              </ul>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
