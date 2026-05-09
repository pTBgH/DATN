import Link from "next/link";
import { hiringApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function ApplicationDetailPage({
  params,
}: {
  params: { wsId: string; applicationId: string };
}) {
  const [app, interviews] = await Promise.all([
    hiringApi.getApplicationDetail(params.applicationId),
    hiringApi.listInterviews(params.applicationId),
  ]);
  return (
    <div className="space-y-6">
      <header>
        <Link
          href={`/recruiter/${params.wsId}`}
          className="text-xs text-slate-500 hover:underline"
        >
          ← Quay lại workspace
        </Link>
        <h1 className="mt-1 text-2xl font-semibold">{app.candidate.name}</h1>
        <div className="text-sm text-slate-500">
          {app.candidate.email} · ApplicationID <code>{app.id}</code>
        </div>
      </header>

      <section className="grid gap-4 md:grid-cols-2">
        <div className="rounded-lg border bg-white p-5">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
            Stage hiện tại
          </h2>
          <span
            className="rounded px-2 py-1 text-sm font-medium"
            style={{ backgroundColor: app.stage.color, color: "#1e293b" }}
          >
            {app.stage.name}
          </span>
          <div className="mt-3 text-xs text-slate-500">
            Ứng tuyển: {new Date(app.applied_at).toLocaleString("vi-VN")}
          </div>
        </div>
        <div className="rounded-lg border bg-white p-5">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
            Hồ sơ
          </h2>
          <ul className="space-y-1 text-sm">
            <li>SĐT: {app.candidate.phone ?? "—"}</li>
            <li>
              CV:{" "}
              <a
                href={app.candidate.cv_url}
                target="_blank"
                rel="noreferrer"
                className="text-brand hover:underline"
              >
                Mở file CV
              </a>
            </li>
            <li>
              CvID <code>{app.candidate.cv_id}</code>
            </li>
          </ul>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Phỏng vấn ({interviews.length})</h2>
        <ul className="space-y-2 text-sm">
          {interviews.map((iv) => (
            <li
              key={iv.interview_id}
              className="rounded-lg border bg-white p-4"
            >
              <div className="flex items-baseline justify-between">
                <div>
                  <div className="font-medium">{iv.status}</div>
                  <div className="text-xs text-slate-500">
                    {new Date(iv.start_time).toLocaleString("vi-VN")} →{" "}
                    {new Date(iv.end_time).toLocaleString("vi-VN")}
                  </div>
                </div>
                {iv.location ? (
                  <a
                    href={iv.location}
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs text-brand hover:underline"
                  >
                    Mở link / địa điểm
                  </a>
                ) : null}
              </div>
              {iv.note ? (
                <div className="mt-2 text-xs text-slate-600">{iv.note}</div>
              ) : null}
            </li>
          ))}
          {interviews.length === 0 ? (
            <li className="rounded border border-dashed bg-white p-4 text-center text-xs text-slate-400">
              Chưa có lịch phỏng vấn
            </li>
          ) : null}
        </ul>
      </section>
    </div>
  );
}
