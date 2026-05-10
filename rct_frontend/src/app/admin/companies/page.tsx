import { adminApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function AdminCompaniesPage() {
  const companies = await adminApi.listAdminCompanies();
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Công ty đăng ký</h1>
      <p className="text-sm text-slate-500">
        Tổng {companies.length} công ty. Endpoint tham khảo:
        `GET /api/companies/{"{id}"}` (job-service) + workspace-service §2.
      </p>

      <ul className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {companies.map((c) => (
          <li
            key={c.company_id}
            className="rounded-lg border bg-white p-5"
          >
            <div className="flex items-baseline justify-between">
              <div>
                <div className="font-semibold">{c.name}</div>
                <div className="text-xs text-slate-500">{c.industry}</div>
              </div>
              {c.verified ? (
                <span className="rounded bg-green-100 px-2 py-0.5 text-xs text-green-700">
                  Verified
                </span>
              ) : (
                <span className="rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                  Pending
                </span>
              )}
            </div>
            <dl className="mt-3 grid grid-cols-3 gap-2 text-xs text-slate-500">
              <Stat label="Quy mô" value={c.size} />
              <Stat label="Active jobs" value={c.active_jobs} />
              <Stat label="Workspaces" value={c.workspace_count} />
            </dl>
          </li>
        ))}
      </ul>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded bg-slate-50 p-2 text-center">
      <div className="font-semibold text-slate-900">{value}</div>
      <div className="text-[10px] uppercase tracking-wide">{label}</div>
    </div>
  );
}
