import Link from "next/link";
import { candidateApi, identityApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function CandidateHomePage() {
  const [profile, cvs, history] = await Promise.all([
    identityApi.getCandidateProfile(),
    candidateApi.listResumes(),
    candidateApi.getMyApplications(),
  ]);

  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <section className="rounded-lg border bg-white p-5">
        <h2 className="mb-2 text-lg font-semibold">Hồ sơ</h2>
        <div className="text-sm text-slate-700">
          <div>
            <strong>
              {profile.first_name} {profile.last_name}
            </strong>
          </div>
          <div className="text-slate-500">{profile.email}</div>
          <div className="text-slate-500">{profile.phone_number}</div>
          <div className="mt-2">
            Kinh nghiệm: <strong>{profile.experience_years ?? 0}</strong> năm
          </div>
        </div>
      </section>

      <section className="rounded-lg border bg-white p-5">
        <h2 className="mb-2 text-lg font-semibold">CV ({cvs.length})</h2>
        <ul className="space-y-2 text-sm">
          {cvs.map((cv) => (
            <li
              key={cv.cv_id}
              className="flex items-center justify-between rounded border px-3 py-2"
            >
              <div>
                <div className="font-medium">{cv.title}</div>
                <div className="text-xs text-slate-500">{cv.cv_path}</div>
              </div>
              {cv.is_default ? (
                <span className="rounded bg-brand-50 px-2 py-0.5 text-xs text-brand">
                  default
                </span>
              ) : null}
            </li>
          ))}
        </ul>
      </section>

      <section className="rounded-lg border bg-white p-5 lg:col-span-3">
        <h2 className="mb-2 text-lg font-semibold">
          Đã ứng tuyển ({history.data.length})
        </h2>
        <ul className="divide-y text-sm">
          {history.data.map((a) => (
            <li
              key={a.application_id}
              className="flex items-center justify-between py-2"
            >
              <div>
                <Link
                  href={`/jobs/${a.job.slug ?? a.job.id}`}
                  className="font-medium text-brand hover:underline"
                >
                  {a.job.title}
                </Link>
                <div className="text-xs text-slate-500">
                  {a.job.company_name} · ứng tuyển{" "}
                  {new Date(a.applied_at).toLocaleDateString("vi-VN")}
                </div>
              </div>
              <span
                className="rounded px-2 py-0.5 text-xs"
                style={{
                  backgroundColor: `${a.stage.color}22`,
                  color: a.stage.color,
                }}
              >
                {a.stage.name}
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
