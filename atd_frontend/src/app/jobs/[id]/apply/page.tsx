import Link from "next/link";
import { candidateApi, jobApi } from "@/lib/api";
import { ApiClientError } from "@/lib/api/client";
import { notFound } from "next/navigation";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";

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
    <div className="space-y-6 max-w-3xl mx-auto">
      <div>
        <Link
          href={`/jobs/${params.id}`}
          className="text-sm text-cyan-600 hover:text-cyan-700 font-medium"
        >
          ← Quay lại tin tuyển dụng
        </Link>
        <h1 className="mt-4 text-3xl font-bold text-slate-900">Ứng Tuyển Công Việc</h1>
        <p className="mt-2 text-lg text-slate-600">{job.title}</p>
      </div>

      {/* Job Summary Card */}
      <Card className="bg-gradient-to-r from-cyan-50 to-blue-50">
        <div className="space-y-3 p-4">
          <div className="flex items-baseline justify-between gap-4">
            <div>
              <p className="text-sm text-slate-600">Công ty</p>
              <p className="font-semibold text-slate-900">{job.company_name}</p>
            </div>
            <div className="text-right">
              <p className="text-sm text-slate-600">Mức lương</p>
              <p className="font-bold text-cyan-600">
                {fmtSalary(job.salary_min)}–{fmtSalary(job.salary_max)} VND
              </p>
            </div>
          </div>
          <div>
            <p className="text-sm text-slate-600">Hạn cuối ứng tuyển</p>
            <p className="font-semibold text-slate-900">
              {new Date(job.deadline).toLocaleDateString("vi-VN")}
            </p>
          </div>
        </div>
      </Card>

      {/* Application Form */}
      <Card>
        <CardHeader title="Chọn CV Để Ứng Tuyển" />
        <CardContent className="space-y-4">
          {cvs.length === 0 ? (
            <div className="rounded-lg border-2 border-dashed border-slate-300 bg-slate-50 p-6 text-center">
              <p className="text-4xl mb-3">📄</p>
              <p className="font-semibold text-slate-900">Chưa có CV nào</p>
              <p className="mt-1 text-sm text-slate-600">
                Bạn cần có ít nhất 1 CV để ứng tuyển
              </p>
              <Link href="/cvs">
                <Button variant="primary" size="md" className="mt-4">
                  Tải Lên CV Ngay
                </Button>
              </Link>
            </div>
          ) : (
            <form className="space-y-4">
              <div className="space-y-2">
                {cvs.map((cv, index) => (
                  <label
                    key={cv.cv_id}
                    className="flex items-center gap-3 p-4 rounded-lg border-2 border-slate-200 hover:border-cyan-300 cursor-pointer transition"
                  >
                    <input
                      type="radio"
                      name="cv_id"
                      value={cv.cv_id}
                      defaultChecked={cv.is_default}
                      className="h-4 w-4 text-cyan-600"
                    />
                    <div className="flex items-center gap-3 flex-1">
                      <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-cyan-100 text-sm font-semibold text-cyan-700">
                        {index + 1}
                      </div>
                      <div className="flex-1">
                        <div className="font-semibold text-slate-900">{cv.title}</div>
                        <div className="text-xs text-slate-500">
                          Cập nhật: {new Date(cv.updated_at).toLocaleDateString("vi-VN")}
                        </div>
                      </div>
                    </div>
                    {cv.is_default && (
                      <Badge variant="primary" size="sm">
                        ★ Mặc định
                      </Badge>
                    )}
                  </label>
                ))}
              </div>

              <div className="rounded-lg bg-blue-50 p-4 text-sm text-blue-900">
                <p className="font-medium">💡 Mẹo:</p>
                <p className="mt-1">
                  Chọn CV phù hợp nhất với vị trí để tăng cơ hội được xem xét.
                  Bạn có thể quay lại đây để ứng tuyển lại với CV khác.
                </p>
              </div>

              <Button type="submit" variant="primary" size="lg" className="w-full">
                Gửi Đơn Ứng Tuyển
              </Button>
            </form>
          )}
        </CardContent>
      </Card>

      {/* Additional Info */}
      <Card className="bg-gradient-to-r from-green-50 to-emerald-50">
        <div className="p-4 space-y-3">
          <div className="flex items-start gap-3">
            <div className="text-2xl">✓</div>
            <div>
              <p className="font-semibold text-slate-900">Bước Tiếp Theo</p>
              <ul className="mt-2 space-y-1 text-sm text-slate-700">
                <li>1. Sau khi gửi đơn, hãy kiểm tra email để xác nhận</li>
                <li>2. Nhà tuyển dụng sẽ liên hệ với bạn qua tin nhắn hoặc email</li>
                <li>3. Chuẩn bị cho buổi phỏng vấn nếu được chọn</li>
              </ul>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
