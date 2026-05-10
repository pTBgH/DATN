import Link from "next/link";
import { adminApi } from "@/lib/api";
import { Stat } from "@/components/Stat";

export const dynamic = "force-dynamic";

export default async function AdminHomePage() {
  const [pending, sectors, users, companies] = await Promise.all([
    adminApi.listPendingJobs(),
    adminApi.listSectors(),
    adminApi.listAdminUsers(),
    adminApi.listAdminCompanies(),
  ]);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Tổng quan hệ thống</h1>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Stat label="Tin chờ duyệt" value={pending.length} />
        <Stat label="Người dùng" value={users.length} hint="(mock)" />
        <Stat label="Công ty" value={companies.length} hint="(mock)" />
        <Stat label="Ngành nghề" value={sectors.filter((s) => s.active).length} />
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        <Link
          href="/admin/jobs"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Duyệt tin tuyển dụng</div>
          <p className="mt-1 text-sm text-slate-500">
            Endpoint: `GET /api/admin/jobs`, `PATCH /api/admin/jobs/{"{id}"}/approve`
          </p>
        </Link>
        <Link
          href="/admin/sectors"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Quản lý ngành nghề</div>
          <p className="mt-1 text-sm text-slate-500">
            Endpoint: `GET/POST/PUT/DELETE /api/admin/categories/sectors`
          </p>
        </Link>
        <Link
          href="/admin/users"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Người dùng</div>
          <p className="mt-1 text-sm text-slate-500">
            Tương lai sẽ kết hợp với Keycloak admin API.
          </p>
        </Link>
        <Link
          href="/admin/companies"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Công ty</div>
          <p className="mt-1 text-sm text-slate-500">
            Endpoint: `GET /api/companies/{"{id}"}` + workspace-service.
          </p>
        </Link>
      </section>
    </div>
  );
}
