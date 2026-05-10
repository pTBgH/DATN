import Link from "next/link";
import { jobApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function WorkspaceJobsPage({
  params,
  searchParams,
}: {
  params: { wsId: string };
  searchParams: { q?: string; status?: string };
}) {
  // Note: backend expects numeric status_id; keep the dropdown for UX preview
  // and let backend handle the lookup once a status enum lookup is wired.
  const result = await jobApi.listWorkspaceJobs(params.wsId, {
    q: searchParams.q || undefined,
  });

  return (
    <div className="space-y-4">
      <form className="flex flex-wrap gap-2" method="GET">
        <input
          name="q"
          defaultValue={searchParams.q ?? ""}
          placeholder="Tìm theo tiêu đề…"
          className="flex-1 rounded border px-3 py-2 text-sm"
        />
        <select
          name="status"
          defaultValue={searchParams.status ?? ""}
          className="rounded border px-3 py-2 text-sm"
        >
          <option value="">Tất cả trạng thái</option>
          <option value="Draft">Draft</option>
          <option value="Pending">Pending</option>
          <option value="Published">Published</option>
          <option value="Rejected">Rejected</option>
          <option value="Closed">Closed</option>
        </select>
        <button className="rounded bg-brand px-4 text-sm text-white hover:bg-brand-dark">
          Lọc
        </button>
      </form>

      <p className="text-sm text-slate-500">
        {result.meta?.total ?? result.data.length} tin · trang {result.meta?.current_page ?? 1}/
        {result.meta?.last_page ?? 1}
      </p>

      <ul className="space-y-2">
        {result.data.map((j) => (
          <li key={j.job_id}>
            <Link
              href={`/recruiter/${params.wsId}/jobs/${j.job_id}`}
              className="flex items-baseline justify-between gap-3 rounded-lg border bg-white p-4 hover:border-brand"
            >
              <div>
                <div className="font-semibold">{j.title}</div>
                <div className="text-xs text-slate-500">
                  Deadline {j.deadline} · {j.view_count} views · {j.apply_count} applies
                </div>
              </div>
              <span className="rounded bg-slate-100 px-2 py-0.5 text-xs">
                {j.status}
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
