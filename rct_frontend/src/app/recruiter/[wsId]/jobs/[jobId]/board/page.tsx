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

      <KanbanBoard board={board} wsId={params.wsId} />
    </div>
  );
}
