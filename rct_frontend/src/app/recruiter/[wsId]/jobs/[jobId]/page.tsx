"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { jobApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function RecruiterJobDetailPage() {
  const params = useParams<{ wsId: string; jobId: string }>();
  const { wsId, jobId } = params ?? {};

  const { data: job, loading, error } = useAuthedFetch(
    () => jobApi.getWorkspaceJob(wsId!, jobId!),
    [wsId, jobId],
  );

  if (loading) return <PageLoading label="Đang tải chi tiết công việc..." />;
  if (error) return <PageError message={error} />;
  if (!job) return null;
  return (
    <article className="space-y-6">
      <header className="flex items-start gap-4">
        <div className="flex-1">
          <Link
            href={`/recruiter/${params.wsId}/jobs`}
            className="text-xs text-slate-500 hover:underline"
          >
            ← Danh sách tin
          </Link>
          <h1 className="mt-1 text-2xl font-bold">{job.title}</h1>
          <div className="text-sm text-slate-500">
            {job.company_name} · {job.status} · slug <code>{job.slug}</code>
          </div>
        </div>
        <div className="text-right text-sm">
          <Link
            href={`/recruiter/${params.wsId}/jobs/${job.job_id}/board`}
            className="rounded bg-brand px-3 py-1.5 text-white hover:bg-brand-dark"
          >
            Mở Kanban board
          </Link>
        </div>
      </header>

      <section className="rounded-lg border bg-amber-50 p-4 text-sm">
        <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-amber-700">
          Hành động trạng thái
        </div>
        <div className="flex flex-wrap gap-2">
          <button className="rounded border border-amber-300 bg-white px-3 py-1.5 hover:bg-amber-100">
            Submit (Draft → Pending)
          </button>
          <button className="rounded border border-amber-300 bg-white px-3 py-1.5 hover:bg-amber-100">
            Archive
          </button>
          <button className="rounded border border-amber-300 bg-white px-3 py-1.5 hover:bg-amber-100">
            Restore
          </button>
        </div>
        <p className="mt-2 text-xs text-amber-700">
          Mock-only: button thật sẽ gọi <code>PATCH /api/workspaces/&#123;wsId&#125;/jobs/&#123;jobId&#125;/&#123;submit|archive|restore&#125;</code>{" "}
          (xem <code>jobApi.submitExistingJob/archiveJob/restoreJob</code>).
        </p>
      </section>

      <section className="grid grid-cols-2 gap-3 rounded-lg border bg-white p-4 text-sm md:grid-cols-4">
        <KV label="Lương min">
          {job.salary_min ? job.salary_min.toLocaleString("vi-VN") : "—"}
        </KV>
        <KV label="Lương max">
          {job.salary_max ? job.salary_max.toLocaleString("vi-VN") : "—"}
        </KV>
        <KV label="Deadline">{job.deadline}</KV>
        <KV label="Lượt ứng tuyển">{job.apply_count}</KV>
      </section>

      <Section title="Mô tả công việc" body={job.description} />
      <Section title="Yêu cầu" body={job.requirements} />
      <Section title="Quyền lợi" body={job.benefits} />
    </article>
  );
}

function KV({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-0.5 font-semibold">{children}</div>
    </div>
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
