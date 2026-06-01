import Link from "next/link";
import { jobApi } from "@/lib/api";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { truncateText } from "@/lib/formatters";

export const dynamic = "force-dynamic";

export default async function SavedJobsPage() {
  const featured = await jobApi.listPublicJobs({ limit: 4 });
  const saved = featured.data.slice(0, 2);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Công Việc Đã Lưu</h1>
          <p className="mt-1 text-slate-600">Các vị trí bạn quan tâm và muốn theo dõi sau</p>
        </div>
        {saved.length > 0 && (
          <Badge variant="primary" size="md">
            {saved.length} công việc
          </Badge>
        )}
      </div>

      {saved.length === 0 ? (
        <Card className="py-12 text-center bg-gray-50 border border-gray-200">
          <div className="space-y-4">
            <div className="text-4xl text-gray-400">[ ★ ]</div>
            <div>
              <p className="font-semibold text-slate-900">Chưa lưu công việc nào</p>
              <p className="mt-1 text-sm text-slate-600">
                Hãy duyệt danh sách công việc và lưu những vị trí bạn yêu thích
              </p>
            </div>
            <Link href="/jobs">
              <Button variant="primary">Khám Phá Công Việc</Button>
            </Link>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          <ul className="space-y-3">
            {saved.map((j) => (
              <li key={j.job_id}>
                <Link href={`/jobs/${j.slug ?? j.job_id}`}>
                  <Card hover className="border border-gray-200">
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
                          Đã lưu
                        </Badge>
                      </div>

                      {j.description && (
                        <p className="line-clamp-2 text-sm text-slate-600">
                          {truncateText(j.description, 150)}
                        </p>
                      )}

                      <div className="flex items-center justify-between border-t border-gray-100 pt-3">
                        <div>
                          <p className="text-xs text-slate-500">Mức lương</p>
                          <p className="font-semibold text-blue-600">
                            {fmtSalary(j.salary_min)}–{fmtSalary(j.salary_max)} VND
                          </p>
                        </div>
                        <div className="text-right">
                          <p className="text-xs text-slate-500">Hạn cuối</p>
                          <p className="font-medium text-slate-900">
                            {formatDeadline(j.deadline)}
                          </p>
                        </div>
                        <Button variant="outline" size="md">
                          Xem Chi Tiết
                        </Button>
                      </div>
                    </div>
                  </Card>
                </Link>
              </li>
            ))}
          </ul>

          <Card className="bg-gray-50 border border-gray-200">
            <div className="flex items-start gap-3 p-4">
              <div className="text-lg font-bold text-gray-600">i</div>
              <div>
                <p className="font-semibold text-slate-900">Gợi Ý</p>
                <p className="mt-1 text-sm text-slate-700">
                  Lưu các công việc quan tâm để dễ dàng quay lại và ứng tuyển sau. 
                  Bạn có thể quản lý danh sách lưu từ trang tìm kiếm công việc.
                </p>
              </div>
            </div>
          </Card>
        </div>
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
