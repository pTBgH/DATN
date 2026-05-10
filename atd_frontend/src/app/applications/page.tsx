import Link from "next/link";
import { candidateApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function MyApplicationsPage() {
  const { data } = await candidateApi.getMyApplications();
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Đơn ứng tuyển của tôi</h1>
      <p className="text-sm text-slate-500">
        Endpoint: `GET /api/my-applications` (candidate-service §4.1).
      </p>

      {data.length === 0 ? (
        <div className="rounded border border-dashed bg-white p-8 text-center text-sm text-slate-500">
          Bạn chưa ứng tuyển vào công việc nào.
          <Link
            href="/jobs"
            className="ml-1 text-brand hover:underline"
          >
            Tìm việc ngay →
          </Link>
        </div>
      ) : (
        <ul className="space-y-3">
          {data.map((a) => (
            <li
              key={a.application_id}
              className="rounded-lg border bg-white p-4"
            >
              <div className="flex items-baseline justify-between">
                <div>
                  <Link
                    href={`/jobs/${a.job.slug ?? a.job.id}`}
                    className="font-semibold hover:text-brand hover:underline"
                  >
                    {a.job.title}
                  </Link>
                  <div className="text-xs text-slate-500">
                    {a.job.company_name} ·{" "}
                    {new Date(a.applied_at).toLocaleDateString("vi-VN")}
                  </div>
                </div>
                <span
                  className="rounded px-2 py-0.5 text-xs font-medium"
                  style={{ backgroundColor: a.stage.color, color: "#1e293b" }}
                >
                  {a.stage.name}
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
