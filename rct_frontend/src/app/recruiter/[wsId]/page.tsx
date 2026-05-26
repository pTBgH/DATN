import Link from "next/link";
import { jobApi, workspaceApi } from "@/lib/api";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { truncateText } from "@/lib/formatters";

export const dynamic = "force-dynamic";

export default async function WorkspaceDashboardPage({
  params,
}: {
  params: { wsId: string };
}) {
  const [ws, jobs] = await Promise.all([
    workspaceApi.getWorkspace(params.wsId),
    jobApi.listWorkspaceJobs(params.wsId),
  ]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">{ws.name}</h1>
        <p className="mt-1 text-slate-600">Tổng quan và quản lý tuyển dụng</p>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <MetricCard
          label="Công Việc Hoạt Động"
          value={ws.active_jobs}
          color="from-cyan-100 to-blue-100"
          icon="📋"
        />
        <MetricCard
          label="Lượt Xem"
          value={ws.views.toLocaleString("vi-VN")}
          color="from-green-100 to-emerald-100"
          icon="👁️"
        />
        <MetricCard
          label="Ứng Tuyển"
          value={ws.applications.toLocaleString("vi-VN")}
          color="from-purple-100 to-pink-100"
          icon="📬"
        />
        <MetricCard
          label="Tỷ Lệ Ứng Tuyển"
          value={`${ws.apply_rate}%`}
          color="from-amber-100 to-orange-100"
          icon="📈"
        />
      </div>

      {/* Recent Jobs Section */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-2xl font-bold text-slate-900">Tin Tuyển Dụng Gần Đây</h2>
            <p className="text-sm text-slate-600">Những công việc mới nhất của workspace</p>
          </div>
          <Link href={`/recruiter/${ws.id}/jobs`}>
            <Button variant="outline" size="md">
              Xem Tất Cả
            </Button>
          </Link>
        </div>

        {jobs.data.length === 0 ? (
          <Card className="py-12 text-center bg-slate-50">
            <div className="text-5xl mb-3">📋</div>
            <p className="font-semibold text-slate-900">Chưa có tin tuyển dụng nào</p>
            <p className="mt-1 text-sm text-slate-600">
              Hãy tạo tin tuyển dụng đầu tiên
            </p>
            <Link href={`/recruiter/${ws.id}/jobs/new`}>
              <Button variant="primary" size="md" className="mt-4">
                Tạo Tin Tuyển Mới
              </Button>
            </Link>
          </Card>
        ) : (
          <ul className="space-y-3">
            {jobs.data.slice(0, 5).map((j) => (
              <li key={j.job_id}>
                <Link href={`/recruiter/${ws.id}/jobs/${j.job_id}`}>
                  <Card hover>
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <div className="flex items-baseline gap-3">
                          <h3 className="text-lg font-semibold text-slate-900 line-clamp-2">
                            {j.title}
                          </h3>
                          <Badge 
                            variant={j.status === 'Open' ? 'primary' : 'default'}
                            size="sm"
                          >
                            {getStatusIcon(j.status)} {j.status}
                          </Badge>
                        </div>

                        {j.description && (
                          <p className="mt-2 line-clamp-1 text-sm text-slate-600">
                            {truncateText(j.description, 100)}
                          </p>
                        )}

                        <div className="mt-2 flex flex-wrap gap-4 text-xs text-slate-500">
                          <span>Deadline: {new Date(j.deadline).toLocaleDateString("vi-VN")}</span>
                          <span>👁️ {j.view_count} xem</span>
                          <span>📬 {j.apply_count} ứng tuyển</span>
                        </div>
                      </div>

                      <Button variant="outline" size="md">
                        Quản Lý →
                      </Button>
                    </div>
                  </Card>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* Action Buttons */}
      <div className="flex flex-wrap gap-3">
        <Link href={`/recruiter/${ws.id}/jobs/new`}>
          <Button variant="primary" size="lg">
            + Tạo Tin Tuyển Dụng
          </Button>
        </Link>
        <Link href={`/recruiter/${ws.id}/jobs`}>
          <Button variant="outline" size="lg">
            Quản Lý Công Việc
          </Button>
        </Link>
        <Link href={`/recruiter/${ws.id}/pipelines`}>
          <Button variant="outline" size="lg">
            Xem Pipeline
          </Button>
        </Link>
      </div>

      {/* Quick Tips */}
      <Card className="bg-gradient-to-r from-blue-50 to-cyan-50">
        <div className="flex items-start gap-3 p-4">
          <div className="text-2xl">💡</div>
          <div>
            <p className="font-semibold text-slate-900">Gợi Ý Nhanh</p>
            <ul className="mt-2 space-y-1 text-sm text-slate-700">
              <li>• Tạo tin tuyển dụng mới để bắt đầu nhận hồ sơ ứng viên</li>
              <li>• Sử dụng Pipeline để quản lý tiến độ ứng viên</li>
              <li>• Gửi tin nhắn với ứng viên để liên hệ trực tiếp</li>
              <li>• Lên lịch phỏng vấn và lưu điểm cho ứng viên</li>
            </ul>
          </div>
        </div>
      </Card>
    </div>
  );
}

function MetricCard({
  label,
  value,
  color,
  icon,
}: {
  label: string;
  value: string | number;
  color: string;
  icon: string;
}) {
  return (
    <Card>
      <div className={`flex items-start justify-between bg-gradient-to-br ${color} rounded-lg p-4 mb-4`}>
        <div>
          <p className="text-sm text-slate-700 font-medium">{label}</p>
          <p className="mt-1 text-3xl font-bold text-slate-900">{value}</p>
        </div>
        <div className="text-2xl">{icon}</div>
      </div>
    </Card>
  );
}

function getStatusIcon(status: string): string {
  const icons: Record<string, string> = {
    "Open": "✓",
    "Closed": "🚫",
    "Draft": "📝",
    "Pending": "⏳",
  };
  return icons[status] || "•";
}
