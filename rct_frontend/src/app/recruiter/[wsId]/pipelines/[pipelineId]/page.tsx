import Link from "next/link";
import { hiringApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function PipelineDetailPage({
  params,
}: {
  params: { wsId: string; pipelineId: string };
}) {
  const [pipeline, workflow, definitions] = await Promise.all([
    hiringApi.getPipeline(params.wsId, params.pipelineId),
    hiringApi.getPipelineWorkflow(params.wsId, params.pipelineId),
    hiringApi.getWorkflowDefinitions(params.wsId),
  ]);

  const defByCode = new Map(
    definitions.map((d) => [d.definition_id, d] as const),
  );
  const stagesByCode = new Map(
    (pipeline.stages ?? []).map((s) => [s.stage_id, s] as const),
  );

  return (
    <div className="space-y-6">
      <header>
        <Link
          href={`/recruiter/${params.wsId}/pipelines`}
          className="text-xs text-slate-500 hover:underline"
        >
          ← Pipelines
        </Link>
        <div className="mt-1 flex items-baseline gap-3">
          <h1 className="text-2xl font-semibold">{pipeline.name}</h1>
          {pipeline.is_default ? (
            <span className="rounded bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800">
              Default
            </span>
          ) : null}
        </div>
        <div className="text-xs text-slate-500">
          PipelineID <code>{pipeline.pipeline_id}</code>
        </div>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Stages
        </h2>
        <ol className="flex flex-wrap items-center gap-2 text-sm">
          {pipeline.stages?.map((s, i) => (
            <li key={s.stage_id} className="flex items-center gap-2">
              <span
                className="rounded px-2 py-1"
                style={{ backgroundColor: s.color ?? "#e2e8f0" }}
              >
                {s.order}. {s.name}
                {s.is_system ? " (system)" : ""}
              </span>
              {i < (pipeline.stages?.length ?? 0) - 1 ? (
                <span className="text-slate-400">→</span>
              ) : null}
            </li>
          ))}
        </ol>
      </section>

      <section>
        <div className="mb-3 flex items-baseline justify-between">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Quy tắc tự động ({workflow.rules.length})
          </h2>
          <button className="rounded border px-3 py-1.5 text-xs hover:bg-slate-50">
            + Thêm rule
          </button>
        </div>
        <ul className="space-y-2 text-sm">
          {workflow.rules.map((r) => {
            const def = defByCode.get(r.definition_id);
            const stg = stagesByCode.get(r.stage_id);
            return (
              <li
                key={r.rule_id}
                className="flex items-start gap-3 rounded-lg border bg-white p-4"
              >
                <span
                  className={`mt-1 inline-block h-2 w-2 rounded-full ${
                    r.enabled ? "bg-emerald-500" : "bg-slate-300"
                  }`}
                />
                <div className="flex-1">
                  <div className="font-medium">
                    {def?.name ?? r.definition_id}
                  </div>
                  <div className="text-xs text-slate-500">
                    Khi vào stage{" "}
                    <span
                      className="rounded px-1.5"
                      style={{ backgroundColor: stg?.color ?? "#e2e8f0" }}
                    >
                      {stg?.name ?? r.stage_id}
                    </span>
                  </div>
                  {def?.description ? (
                    <div className="mt-1 text-xs text-slate-600">
                      {def.description}
                    </div>
                  ) : null}
                </div>
              </li>
            );
          })}
          {workflow.rules.length === 0 ? (
            <li className="rounded border border-dashed bg-white p-4 text-center text-xs text-slate-400">
              Chưa có rule nào
            </li>
          ) : null}
        </ul>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Workflow definitions có sẵn ({definitions.length})
        </h2>
        <ul className="grid gap-2 text-sm md:grid-cols-2">
          {definitions.map((d) => (
            <li
              key={d.definition_id}
              className="rounded border bg-white p-4"
            >
              <div className="font-medium">{d.name}</div>
              <div className="text-xs text-slate-500">
                trigger: <code>{d.trigger}</code> · code <code>{d.code}</code>
              </div>
              {d.description ? (
                <p className="mt-1 text-xs text-slate-600">{d.description}</p>
              ) : null}
            </li>
          ))}
        </ul>
        <p className="mt-3 text-xs text-slate-500">
          Mock-only: GET <code>…/pipelines/workflow-definitions</code>, POST{" "}
          <code>…/pipelines/&#123;id&#125;/workflow</code> để gắn rule.
        </p>
      </section>
    </div>
  );
}
