import Link from "next/link";
import { jobApi } from "@/lib/api";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { truncateText } from "@/lib/formatters";
import { Button } from "@/components/Button";

export const dynamic = "force-dynamic";

export default async function JobsListPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const q = searchParams?.q ?? "";
  const result = await jobApi.listPublicJobs({ q: q || undefined });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Khám phá Việc Làm</h1>
        <p className="mt-2 text-slate-600">
          Tìm cơ hội việc làm phù hợp với kỹ năng và sự nghiệp của bạn
        </p>
      </div>

      <form className="flex gap-2" method="GET">
        <input
          name="q"
          defaultValue={q}
          placeholder="Tìm vị trí, công ty, kỹ năng…"
          className="flex-1 rounded-lg border border-slate-300 px-4 py-2.5 text-base placeholder-slate-400 focus:border-cyan-500 focus:outline-none focus:ring-2 focus:ring-cyan-100"
        />
        <Button variant="primary" type="submit">
          Tìm kiếm
        </Button>
      </form>

      <div className="flex items-center justify-between rounded-lg bg-gradient-to-r from-cyan-50 to-blue-50 p-4">
        <p className="text-sm font-medium text-slate-700">
          Tổng <span className="text-cyan-600 font-semibold">{result.meta?.total ?? result.data.length}</span> kết quả tìm kiếm
        </p>
        {result.data.length === 0 && (
          <p className="text-sm text-slate-600">
            Hãy thử tìm kiếm với từ khóa khác
          </p>
        )}
      </div>

      {result.data.length === 0 ? (
        <Card className="text-center py-12">
          <div className="text-slate-500">
            <p className="text-lg font-medium mb-2">Không tìm thấy công việc</p>
            <p className="text-sm">Vui lòng thử tìm kiếm với các từ khóa khác</p>
          </div>
        </Card>
      ) : (
        <ul className="space-y-3">
          {result.data.map((j) => (
            <li key={j.job_id}>
              <Link
                href={`/jobs/${j.slug ?? j.job_id}`}
                className="block"
              >
                <Card hover className="h-full">
                  <div className="space-y-3">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <h3 className="text-lg font-semibold text-slate-900 line-clamp-2">
                          {j.title}
                        </h3>
                        <p className="mt-1 text-sm text-slate-600">
                          {j.company_name}
                        </p>
                      </div>
                      <Badge variant="primary" size="sm">
                        {j.apply_count} ứng tuyển
                      </Badge>
                    </div>

                    {j.description && (
                      <p className="line-clamp-2 text-sm text-slate-600">
                        {truncateText(j.description, 150)}
                      </p>
                    )}

                    <div className="flex items-center justify-between pt-2">
                      <div className="text-sm font-semibold text-cyan-600">
                        {fmtSalary(j.salary_min)}–{fmtSalary(j.salary_max)} VND
                      </div>
                      <div className="flex items-center gap-4 text-xs text-slate-500">
                        <span>{j.view_count} 👁️</span>
                        <span>Hạn: {formatDeadline(j.deadline)}</span>
                      </div>
                    </div>
                  </div>
                </Card>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}

function formatDeadline(deadline: string): string {
  const date = new Date(deadline);
  const now = new Date();
  const diffDays = Math.floor((date.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  
  if (diffDays < 0) return "Đã hết hạn";
  if (diffDays === 0) return "Hôm nay";
  if (diffDays === 1) return "Ngày mai";
  if (diffDays <= 7) return `${diffDays} ngày`;
  return date.toLocaleDateString("vi-VN");
}
