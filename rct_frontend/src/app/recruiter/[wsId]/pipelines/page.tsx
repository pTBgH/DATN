"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { hiringApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function PipelinesPage() {
  const params = useParams<{ wsId: string }>();
  const { wsId } = params ?? {};

  const { data: pipelines, loading, error } = useAuthedFetch(
    () => hiringApi.listPipelines(wsId!),
    [wsId],
  );

  if (loading) return <PageLoading label="Đang tải pipeline..." />;
  if (error) return <PageError message={error} />;

  const list = pipelines ?? [];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h2 className="text-lg font-semibold">Pipeline tuyển dụng</h2>
        <button className="rounded border px-3 py-1.5 text-sm hover:bg-slate-50">
          + Tạo pipeline
        </button>
      </header>
      <ul className="space-y-4">
        {list.map((pl) => (
          <li key={pl.pipeline_id} className="rounded-lg border bg-white p-5">
            <div className="flex items-baseline justify-between">
              <div>
                <div className="font-semibold">{pl.name}</div>
                <div className="text-xs text-slate-500">
                  PipelineID <code>{pl.pipeline_id}</code>
                  {pl.is_default ? " · Default" : null}
                </div>
              </div>
              <Link
                href={`/recruiter/${params.wsId}/pipelines/${pl.pipeline_id}`}
                className="text-xs text-slate-500 hover:text-brand"
              >
                Mở chi tiết →
              </Link>
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
