import Link from "next/link";
import { jobApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const jobs = await jobApi.listPublicJobs({});
  return (
    <div className="space-y-10">
      <section className="rounded-xl bg-gradient-to-r from-brand to-brand-dark p-10 text-white shadow">
        <h1 className="text-3xl font-bold">Tìm việc với Job7189</h1>
        <p className="mt-2 max-w-2xl text-brand-50">
          Frontend dành cho người ứng tuyển — duyệt việc, ứng tuyển, theo dõi
          trạng thái hồ sơ. Chạy trên Cloudflare Pages, kết nối tới 7 microservice
          Laravel qua Kong gateway, xác thực bằng Keycloak realm{" "}
          <code className="rounded bg-white/15 px-1">job7189</code>.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href="/jobs"
            className="rounded bg-white px-4 py-2 font-medium text-brand hover:bg-slate-100"
          >
            Xem tất cả việc làm
          </Link>
          <Link
            href="/login"
            className="rounded border border-white/40 px-4 py-2 font-medium hover:bg-white/10"
          >
            Đăng nhập / Đăng ký
          </Link>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xl font-semibold">Việc nổi bật</h2>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {jobs.data.slice(0, 6).map((j) => (
            <Link
              key={j.job_id}
              href={`/jobs/${j.slug ?? j.job_id}`}
              className="rounded-lg border bg-white p-4 transition hover:border-brand"
            >
              <div className="text-sm text-slate-500">{j.company_name}</div>
              <div className="mt-1 text-base font-semibold">{j.title}</div>
              <div className="mt-2 text-xs text-slate-500">
                Deadline: {j.deadline} · {j.view_count} views ·{" "}
                {j.apply_count} applies
              </div>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}
