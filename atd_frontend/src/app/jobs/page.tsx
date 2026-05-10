import Link from "next/link";
import { jobApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function JobsListPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const q = searchParams?.q ?? "";
  const result = await jobApi.listPublicJobs({ q: q || undefined });

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Việc làm</h1>
      <form className="flex gap-2" method="GET">
        <input
          name="q"
          defaultValue={q}
          placeholder="Tìm vị trí, công ty…"
          className="w-full rounded border px-3 py-2"
        />
        <button className="rounded bg-brand px-4 text-white hover:bg-brand-dark">
          Tìm
        </button>
      </form>

      <p className="text-sm text-slate-500">
        Tổng {result.meta?.total ?? result.data.length} kết quả.
      </p>

      <ul className="space-y-3">
        {result.data.map((j) => (
          <li key={j.job_id}>
            <Link
              href={`/jobs/${j.slug ?? j.job_id}`}
              className="block rounded-lg border bg-white p-4 hover:border-brand"
            >
              <div className="flex items-baseline justify-between gap-3">
                <div>
                  <div className="text-base font-semibold">{j.title}</div>
                  <div className="text-sm text-slate-500">
                    {j.company_name} · Deadline {j.deadline}
                  </div>
                </div>
                <div className="text-right text-xs text-slate-500">
                  <div>
                    {fmtSalary(j.salary_min)}–{fmtSalary(j.salary_max)} VND
                  </div>
                  <div>{j.view_count} views</div>
                </div>
              </div>
              {j.description ? (
                <p className="mt-2 line-clamp-2 text-sm text-slate-600">
                  {j.description}
                </p>
              ) : null}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
