import Link from "next/link";
import { jobApi } from "@/lib/api";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { getJobStatusBadgeClass } from "@/lib/formatters";

export const dynamic = "force-dynamic";

export default async function WorkspaceJobsPage({
  params,
  searchParams,
}: {
  params: { wsId: string };
  searchParams: { q?: string; status?: string };
}) {
  const result = await jobApi.listWorkspaceJobs(params.wsId, {
    q: searchParams.q || undefined,
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Danh Sách Công Việc</h1>
        <p className="mt-2 text-slate-600">
          Quản lý và theo dõi các vị trí tuyển dụng của công ty
        </p>
      </div>

      <form className="flex flex-wrap gap-3" method="GET">
        <input
          name="q"
          defaultValue={searchParams.q ?? ""}
          placeholder="Tìm theo tiêu đề công việc…"
          className="flex-1 rounded-lg border border-slate-300 px-4 py-2 placeholder-slate-400 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
        />
        <select
          name="status"
          defaultValue={searchParams.status ?? ""}
          className="rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
        >
          <option value="">Tất cả trạng thái</option>
          <option value="Draft">Nháp</option>
          <option value="Pending">Chờ duyệt</option>
          <option value="Published">Đang tuyển</option>
          <option value="Closed">Đã đóng</option>
          <option value="Rejected">Bị từ chối</option>
        </select>
        <Button variant="primary" type="submit">
          Lọc
        </Button>
      </form>

      <div className="flex items-center justify-between rounded-lg bg-blue-50 border border-blue-200 p-4">
        <p className="text-sm font-medium text-slate-700">
          Tổng <span className="text-blue-600 font-semibold">{result.meta?.total ?? result.data.length}</span> công việc
        </p>
        <p className="text-sm text-slate-600">
          Trang {result.meta?.current_page ?? 1}/{result.meta?.last_page ?? 1}
        </p>
      </div>

      {result.data.length === 0 ? (
        <Card className="text-center py-12 bg-gray-50 border border-gray-200">
          <div className="text-4xl text-gray-400 mb-4">[ CV ]</div>
          <p className="text-lg font-semibold text-slate-900">Không tìm thấy công việc</p>
          <p className="mt-1 text-slate-600">Hãy thử thay đổi điều kiện tìm kiếm</p>
        </Card>
      ) : (
        <ul className="space-y-3">
          {result.data.map((j) => (
            <li key={j.job_id}>
              <Link href={`/recruiter/${params.wsId}/jobs/${j.job_id}`}>
                <Card hover className="border border-gray-200">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1 space-y-2">
                      <div className="flex items-baseline justify-between gap-2">
                        <h3 className="text-lg font-semibold text-slate-900">
                          {j.title}
                        </h3>
                        <Badge 
                          className={getJobStatusBadgeClass(j.status)}
                          size="sm"
                        >
                          {j.status}
                        </Badge>
                      </div>

                      <p className="text-sm text-slate-600">
                        Hạn: {new Date(j.deadline).toLocaleDateString("vi-VN")}
                      </p>

                      <div className="flex flex-wrap gap-2 pt-2">
                        <Badge variant="info" size="sm">
                          {j.view_count} xem
                        </Badge>
                        <Badge variant="primary" size="sm">
                          {j.apply_count} ứng tuyển
                        </Badge>
                      </div>
                    </div>

                    <Button variant="outline" size="md">
                      Chi tiết
                    </Button>
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

function getStatusIcon(status: string): string {
  const icons: Record<string, string> = {
    "Draft": "📝",
    "Pending": "⏳",
    "Published": "✓",
    "Closed": "🚫",
    "Rejected": "❌",
  };
  return icons[status] || "";
}
