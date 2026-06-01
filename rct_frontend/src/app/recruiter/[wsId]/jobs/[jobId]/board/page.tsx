"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { hiringApi } from "@/lib/api";
import { KanbanBoard } from "@/components/KanbanBoard";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function BoardPage() {
  const params = useParams<{ wsId: string; jobId: string }>();
  const { wsId, jobId } = params ?? {};

  const { data: board, loading, error } = useAuthedFetch(
    () => hiringApi.getBoard(jobId!),
    [jobId],
  );

  if (loading) return <PageLoading label="Đang tải board..." />;
  if (error) return <PageError message={error} />;
  if (!board) return null;
  return (
    <div className="flex h-full flex-col gap-3">
      <header className="flex items-center justify-between rounded-lg border bg-white px-4 py-2.5">
        <div className="flex items-center gap-3">
          <Link
            href={`/recruiter/${params.wsId}/jobs/${params.jobId}`}
            className="text-xs text-slate-500 hover:underline"
          >
            ← Quay lại
          </Link>
          <div>
            <h1 className="text-sm font-semibold">Hiring board</h1>
            <div className="text-xs text-slate-400">
              Pipeline <code className="text-xs">{board.pipeline_id}</code>
            </div>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-hidden rounded-lg border bg-white p-3">
        <KanbanBoard board={board} wsId={params.wsId} />
      </div>
    </div>
  );
}
