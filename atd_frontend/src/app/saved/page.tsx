import Link from "next/link";
import { jobApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function SavedJobsPage() {
  // GET /api/interactions/saved-jobs returns JobSubJdResource[] (mock-only here)
  const featured = await jobApi.listPublicJobs({ limit: 4 });
  const saved = featured.data.slice(0, 2);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Việc đã lưu</h1>
      <p className="text-sm text-slate-500">
        Endpoint: `GET /api/interactions/saved-jobs` · `POST` để toggle lưu/bỏ
        lưu (candidate-service §4.1).
      </p>

      {saved.length === 0 ? (
        <div className="rounded border border-dashed bg-white p-8 text-center text-sm text-slate-500">
          Bạn chưa lưu công việc nào.
        </div>
      ) : (
        <ul className="space-y-3">
          {saved.map((j) => (
            <li key={j.job_id}>
              <Link
                href={`/jobs/${j.slug ?? j.job_id}`}
                className="flex items-baseline justify-between gap-3 rounded-lg border bg-white p-4 hover:border-brand"
              >
                <div>
                  <div className="font-semibold">{j.title}</div>
                  <div className="text-xs text-slate-500">
                    {j.company_name} · Deadline {j.deadline}
                  </div>
                </div>
                <span className="text-xs text-brand">★ Đã lưu</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
