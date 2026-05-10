import Link from "next/link";

export default function HomePage() {
  return (
    <div className="space-y-10">
      <section className="rounded-xl bg-gradient-to-r from-brand to-brand-dark p-10 text-white shadow">
        <h1 className="text-3xl font-bold">Job7189 — Recruiter &amp; Admin Console</h1>
        <p className="mt-2 max-w-3xl text-brand-100">
          Hệ thống quản lý tuyển dụng cho nhà tuyển dụng và quản trị viên — chạy
          trên Cloudflare Pages, kết nối tới 7 microservice Laravel qua Kong gateway,
          xác thực bằng Keycloak realm <code className="rounded bg-white/15 px-1">job7189</code>.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href="/recruiter"
            className="rounded bg-white px-4 py-2 font-medium text-brand hover:bg-slate-100"
          >
            Vào trang Nhà tuyển dụng
          </Link>
          <Link
            href="/admin"
            className="rounded border border-white/40 px-4 py-2 font-medium hover:bg-white/10"
          >
            Vào trang Quản trị
          </Link>
        </div>
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        <RoleCard
          title="Nhà tuyển dụng"
          desc="Quản lý workspace, tin tuyển dụng, pipeline kanban, lịch phỏng vấn, scorecard."
          href="/recruiter"
        />
        <RoleCard
          title="Quản trị hệ thống"
          desc="Duyệt tin tuyển dụng, quản lý ngành nghề, người dùng, công ty."
          href="/admin"
        />
      </section>
    </div>
  );
}

function RoleCard({
  title,
  desc,
  href,
}: {
  title: string;
  desc: string;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="group rounded-xl border bg-white p-6 transition hover:border-brand"
    >
      <div className="text-lg font-semibold text-slate-900 group-hover:text-brand">
        {title}
      </div>
      <p className="mt-2 text-sm text-slate-600">{desc}</p>
    </Link>
  );
}
