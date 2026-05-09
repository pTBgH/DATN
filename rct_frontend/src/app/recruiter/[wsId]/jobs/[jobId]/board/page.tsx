import Link from "next/link";
import { hiringApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function BoardPage({
  params,
}: {
  params: { wsId: string; jobId: string };
}) {
  const board = await hiringApi.getBoard(params.jobId);
  return (
    <div className="space-y-4">
      <header className="flex items-baseline justify-between">
        <div>
          <Link
            href={`/recruiter/${params.wsId}/jobs/${params.jobId}`}
            className="text-xs text-slate-500 hover:underline"
          >
            ← Quay lại tin tuyển dụng
          </Link>
          <h1 className="mt-1 text-2xl font-semibold">Hiring board</h1>
          <div className="text-xs text-slate-500">
            Pipeline <code>{board.pipeline_id}</code>
          </div>
        </div>
      </header>

      <div className="grid grid-flow-col auto-cols-[16rem] gap-3 overflow-x-auto pb-3">
        {board.stages.map((stage) => (
          <div
            key={stage.stage_id}
            className="rounded-lg border bg-slate-50 p-2"
            style={{ borderTop: `4px solid ${stage.color ?? "#94a3b8"}` }}
          >
            <div className="flex items-center justify-between px-1 pb-2 text-sm font-semibold">
              <span>{stage.name}</span>
              <span className="rounded bg-white px-1.5 py-0.5 text-xs text-slate-600">
                {stage.candidates.length}
              </span>
            </div>
            <div className="space-y-2">
              {stage.candidates.map((c) => (
                <Link
                  key={c.application_id}
                  href={`/recruiter/${params.wsId}/applications/${c.application_id}`}
                  className="block rounded border bg-white p-3 hover:border-brand"
                >
                  <div className="text-sm font-medium">{c.candidate_name}</div>
                  <div className="text-xs text-slate-500">{c.candidate_email}</div>
                  <div className="mt-2 flex items-center justify-between text-xs">
                    <span className="text-slate-500">
                      {new Date(c.applied_at).toLocaleDateString("vi-VN")}
                    </span>
                    <span className="rounded bg-brand-50 px-1.5 py-0.5 text-brand">
                      {c.score}
                    </span>
                  </div>
                </Link>
              ))}
              {stage.candidates.length === 0 ? (
                <div className="rounded border border-dashed bg-white p-3 text-center text-xs text-slate-400">
                  Chưa có ứng viên
                </div>
              ) : null}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
