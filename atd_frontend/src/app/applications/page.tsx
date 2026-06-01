"use client";

import Link from "next/link";
import { candidateApi } from "@/lib/api";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { getStatusBadgeClass } from "@/lib/formatters";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function MyApplicationsPage() {
  const { data, loading, error } = useAuthedFetch(
    () => candidateApi.getMyApplications(),
    [],
  );

  if (loading) return <PageLoading label="Đang tải đơn ứng tuyển..." />;
  if (error) return <PageError message={error} />;

  const applications = data?.data ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Đơn Ứng Tuyển Của Tôi</h1>
        <p className="mt-2 text-slate-600">
          Theo dõi tiến độ các đơn ứng tuyển của bạn
        </p>
      </div>

      {applications.length === 0 ? (
        <Card className="text-center py-12 bg-gray-50 border border-gray-200">
          <div className="space-y-4">
            <div className="text-4xl text-gray-400">[ 📝 ]</div>
            <div>
              <p className="text-lg font-semibold text-slate-900">Chưa có đơn ứng tuyển nào</p>
              <p className="mt-1 text-slate-600">
                Hãy bắt đầu khám phá các cơ hội việc làm thú vị
              </p>
            </div>
            <Link href="/jobs">
              <Button variant="primary" size="md">
                Tìm việc ngay
              </Button>
            </Link>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          <div className="flex items-center justify-between rounded-lg bg-blue-50 border border-blue-200 p-4">
            <p className="text-sm font-medium text-slate-700">
              Tổng <span className="text-blue-600 font-semibold">{applications.length}</span> đơn ứng tuyển
            </p>
          </div>

          <ul className="space-y-3">
            {applications.map((a) => (
              <li key={a.application_id}>
                <Link href={`/jobs/${a.job.slug ?? a.job.id}`}>
                  <Card hover>
                    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                      <div className="flex-1">
                        <h3 className="text-lg font-semibold text-slate-900 hover:text-cyan-600">
                          {a.job.title}
                        </h3>
                        <p className="mt-1 text-sm text-slate-600">
                          {a.job.company_name}
                        </p>
                        <p className="mt-2 text-xs text-slate-500">
                          Ứng tuyển lúc: {new Date(a.applied_at).toLocaleDateString("vi-VN", {
                            weekday: 'short',
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                          })}
                        </p>
                      </div>

                      <div className="flex items-center gap-3">
                        <Badge 
                          className={getStatusBadgeClass(a.stage.name)}
                          size="md"
                        >
                          {getStatusLabel(a.stage.name)}
                        </Badge>
                      </div>
                    </div>
                  </Card>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function getStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    "Applied": "✓ Đã ứng tuyển",
    "Viewed": "👁️ Đã xem",
    "Shortlisted": "⭐ Lọc sơ",
    "Interview": "📞 Phỏng vấn",
    "Offered": "🎉 Nhận việc",
    "Rejected": "❌ Từ chối",
    "Withdrawn": "🔙 Rút lại",
  };
  return labels[status] || status;
}
