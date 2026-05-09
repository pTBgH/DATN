import { adminApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function AdminSectorsPage() {
  const sectors = await adminApi.listSectors();
  return (
    <div className="space-y-4">
      <header className="flex items-baseline justify-between">
        <h1 className="text-2xl font-semibold">Ngành nghề (sectors)</h1>
        <button className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark">
          + Tạo sector
        </button>
      </header>
      <p className="text-sm text-slate-500">
        Endpoint: `GET/POST/PUT/DELETE /api/admin/categories/sectors` (job-service §3.3).
      </p>

      <table className="min-w-full divide-y rounded-lg border bg-white text-sm">
        <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
          <tr>
            <th className="px-4 py-2">ID</th>
            <th className="px-4 py-2">Tên</th>
            <th className="px-4 py-2">Code</th>
            <th className="px-4 py-2">Job count</th>
            <th className="px-4 py-2">Trạng thái</th>
            <th className="px-4 py-2"></th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {sectors.map((s) => (
            <tr key={s.id} className="hover:bg-slate-50">
              <td className="px-4 py-2 text-slate-500">{s.id}</td>
              <td className="px-4 py-2 font-medium">{s.name}</td>
              <td className="px-4 py-2">
                <code className="text-xs">{s.code}</code>
              </td>
              <td className="px-4 py-2">{s.job_count}</td>
              <td className="px-4 py-2">
                <span
                  className={
                    "rounded px-2 py-0.5 text-xs " +
                    (s.active
                      ? "bg-green-100 text-green-700"
                      : "bg-slate-100 text-slate-500")
                  }
                >
                  {s.active ? "Active" : "Inactive"}
                </span>
              </td>
              <td className="px-4 py-2 text-right">
                <button className="text-xs text-slate-500 hover:text-brand">
                  Sửa
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
