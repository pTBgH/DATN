import { notFound } from "next/navigation";
import { jobApi } from "@/lib/api";
import { ApiClientError } from "@/lib/api/client";

export const dynamic = "force-dynamic";

export default async function JobDetailPage({
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

  return (
    <article className="space-y-6">
      <header className="flex items-start gap-4">
        <div>
          <h1 className="text-2xl font-bold">{job.title}</h1>
          <div className="text-sm text-slate-500">
            {job.company_name} · {job.status}
          </div>
        </div>
        <div className="ml-auto text-right text-sm">
          <div>
            {fmtSalary(job.salary_min)}–{fmtSalary(job.salary_max)} VND
          </div>
          <div className="text-xs text-slate-500">Deadline: {job.deadline}</div>
        </div>
      </header>

      <Section title="Mô tả công việc" body={job.description} />
      <Section title="Yêu cầu" body={job.requirements} />
      <Section title="Quyền lợi" body={job.benefits} />

      <div className="rounded border bg-white p-4 text-sm">
        <div>
          Lượt xem: <strong>{job.view_count}</strong>
        </div>
        <div>
          Lượt ứng tuyển: <strong>{job.apply_count}</strong>
        </div>
      </div>
    </article>
  );
}

function Section({ title, body }: { title: string; body: string | null }) {
  if (!body) return null;
  return (
    <section>
      <h2 className="mb-2 text-lg font-semibold">{title}</h2>
      <div className="whitespace-pre-line rounded border bg-white p-4 text-sm leading-6 text-slate-700">
        {body}
      </div>
    </section>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
