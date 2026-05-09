import Link from "next/link";
import { hiringApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function InterviewDetailPage({
  params,
}: {
  params: { interviewId: string };
}) {
  const interview = await hiringApi.getInterview(params.interviewId);
  return (
    <div className="space-y-6">
      <header>
        <Link
          href="/recruiter"
          className="text-xs text-slate-500 hover:underline"
        >
          ← Recruiter
        </Link>
        <h1 className="mt-1 text-2xl font-semibold">
          Phỏng vấn · {interview.status}
        </h1>
        <div className="text-xs text-slate-500">
          InterviewID <code>{interview.interview_id}</code> · ApplicationID{" "}
          <code>{interview.application_id}</code>
        </div>
      </header>

      <section className="grid gap-4 rounded-lg border bg-white p-5 text-sm md:grid-cols-2">
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500">
            Bắt đầu
          </div>
          <div className="font-medium">
            {new Date(interview.start_time).toLocaleString("vi-VN")}
          </div>
        </div>
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500">
            Kết thúc
          </div>
          <div className="font-medium">
            {new Date(interview.end_time).toLocaleString("vi-VN")}
          </div>
        </div>
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500">
            Địa điểm / link
          </div>
          {interview.location ? (
            <a
              href={interview.location}
              target="_blank"
              rel="noreferrer"
              className="break-all text-brand hover:underline"
            >
              {interview.location}
            </a>
          ) : (
            <span className="text-slate-400">—</span>
          )}
        </div>
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-500">
            Tạo lúc
          </div>
          <div className="font-medium">
            {new Date(interview.created_at).toLocaleString("vi-VN")}
          </div>
        </div>
      </section>

      {interview.note ? (
        <section className="rounded-lg border bg-white p-5 text-sm">
          <div className="text-xs uppercase tracking-wide text-slate-500">
            Ghi chú
          </div>
          <p className="mt-1 whitespace-pre-line text-slate-700">
            {interview.note}
          </p>
        </section>
      ) : null}

      <section className="rounded-lg border bg-white p-5 text-sm">
        <div className="mb-2 text-xs uppercase tracking-wide text-slate-500">
          Feedback
        </div>
        {interview.feedback ? (
          <p className="whitespace-pre-line text-slate-700">
            {interview.feedback}
          </p>
        ) : (
          <div className="text-xs text-slate-400">
            Chưa có feedback. Submit thật sẽ gọi{" "}
            <code>POST /api/interviews/&#123;id&#125;/feedback</code>.
          </div>
        )}
      </section>
    </div>
  );
}
