import Link from "next/link";
import { candidateApi, jobApi } from "@/lib/api";
import { ApiClientError } from "@/lib/api/client";
import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function ApplyJobPage({
  params,
}: {
  params: { id: string };
}) {
  let job;
  try {
    job = await jobApi.getPublicJobDetail(params.id);
  } catch (e) {
    if (e instanceof ApiClientError && e.status === 404) notFound();
    throw e;
  }
  const cvs = await candidateApi.listResumes();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <header>
        <Link
          href={`/jobs/${params.id}`}
          className="text-xs text-slate-500 hover:underline"
        >
          ← Quay lại tin tuyển dụng
        </Link>
        <h1 className="mt-1 text-2xl font-semibold">Ứng tuyển — {job.title}</h1>
        <div className="text-sm text-slate-500">{job.company_name}</div>
      </header>

      <form className="space-y-4 rounded-lg border bg-white p-6">
        <p className="text-sm text-slate-500">
          Submit thật sẽ gọi `POST /api/jobs/{job.job_id}/apply` với body
          <code className="ml-1">{`{ cv_id }`}</code> (candidate-service §4.1).
        </p>

        <fieldset className="space-y-2">
          <legend className="text-sm font-medium text-slate-700">
            Chọn CV
          </legend>
          {cvs.length === 0 ? (
            <div className="rounded border border-dashed bg-slate-50 p-4 text-center text-sm text-slate-500">
              Bạn chưa có CV.{" "}
              <Link href="/cvs" className="text-brand hover:underline">
                Tải lên CV ngay →
              </Link>
            </div>
          ) : (
            cvs.map((cv) => (
              <label
                key={cv.cv_id}
                className="flex cursor-pointer items-center gap-3 rounded border bg-white p-3 hover:bg-slate-50"
              >
                <input
                  type="radio"
                  name="cv_id"
                  value={cv.cv_id}
                  defaultChecked={cv.is_default}
                />
                <div className="flex-1">
                  <div className="text-sm font-medium">{cv.title}</div>
                  <div className="text-xs text-slate-500">
                    {new Date(cv.updated_at).toLocaleDateString("vi-VN")}
                  </div>
                </div>
                {cv.is_default ? (
                  <span className="rounded bg-brand-50 px-2 py-0.5 text-xs text-brand">
                    Mặc định
                  </span>
                ) : null}
              </label>
            ))
          )}
        </fieldset>

        <button
          type="submit"
          formAction="#"
          className="w-full rounded bg-brand px-4 py-2 text-white hover:bg-brand-dark"
        >
          Gửi đơn ứng tuyển
        </button>
      </form>
    </div>
  );
}
