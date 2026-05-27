import Link from "next/link";
import { hiringApi } from "@/lib/api";
import { KanbanBoard } from "@/components/KanbanBoard";

export const dynamic = "force-dynamic";

export default async function BoardPage({
  params,
}: {
  params: { wsId: string; jobId: string };
}) {
  const board = await hiringApi.getBoard(params.jobId);
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
