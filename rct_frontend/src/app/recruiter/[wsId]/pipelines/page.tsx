import { hiringApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function PipelinesPage({
  params,
}: {
  params: { wsId: string };
}) {
  const pipelines = await hiringApi.listPipelines(params.wsId);
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h2 className="text-lg font-semibold">Pipeline tuyển dụng</h2>
        <button className="rounded border px-3 py-1.5 text-sm hover:bg-slate-50">
          + Tạo pipeline
        </button>
      </header>
      <ul className="space-y-4">
        {pipelines.map((pl) => (
          <li key={pl.pipeline_id} className="rounded-lg border bg-white p-5">
            <div className="flex items-baseline justify-between">
              <div>
                <div className="font-semibold">{pl.name}</div>
                <div className="text-xs text-slate-500">
                  PipelineID <code>{pl.pipeline_id}</code>
                  {pl.is_default ? " · Default" : null}
                </div>
              </div>
              <button className="text-xs text-slate-500 hover:text-brand">
                Sửa
              </button>
            </div>
            <ol className="mt-3 flex flex-wrap gap-2 text-xs">
              {pl.stages?.map((s) => (
                <li
                  key={s.stage_id}
                  className="rounded px-2 py-1"
                  style={{ backgroundColor: s.color ?? "#e2e8f0" }}
                >
                  {s.order}. {s.name}
                  {s.is_system ? " (system)" : ""}
                </li>
              ))}
            </ol>
          </li>
        ))}
      </ul>
    </div>
  );
}
