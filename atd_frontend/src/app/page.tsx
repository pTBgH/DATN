import Link from "next/link";
import { jobApi } from "@/lib/api";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";
import { truncateText } from "@/lib/formatters";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const jobs = await jobApi.listPublicJobs({});
  return (
    <div className="space-y-12">
      {/* Hero Section */}
      <section className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-cyan-600 via-blue-600 to-slate-700 px-6 py-16 sm:px-12 sm:py-24 text-white shadow-xl">
        <div className="relative z-10 max-w-2xl">
          <h1 className="text-5xl sm:text-6xl font-bold leading-tight">
            Tìm Cơ Hội Nghề Nghiệp Lý Tưởng
          </h1>
          <p className="mt-4 text-lg text-cyan-100">
            Khám phá hàng nghìn cơ hội việc làm từ các công ty hàng đầu. Nâng cao kỹ năng, phát triển sự nghiệp của bạn.
          </p>
          <div className="mt-8 flex flex-wrap gap-4">
            <Link href="/jobs">
              <Button variant="primary" size="lg" className="bg-white text-cyan-600 hover:bg-cyan-50">
                Tìm Việc Ngay →
              </Button>
            </Link>
            <Link href="/login">
              <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/10">
                Đăng Nhập / Đăng Ký
              </Button>
            </Link>
          </div>
        </div>

        {/* Decorative elements */}
        <div className="absolute -right-20 -top-20 h-40 w-40 rounded-full bg-white/10 blur-3xl"></div>
        <div className="absolute -bottom-20 -left-20 h-40 w-40 rounded-full bg-cyan-400/10 blur-3xl"></div>
      </section>

      {/* Stats Section */}
      <section className="grid grid-cols-3 gap-4 sm:gap-6">
        <Card className="text-center py-6 sm:py-8">
          <div className="text-3xl sm:text-4xl font-bold text-cyan-600">{jobs.data.length}+</div>
          <p className="mt-2 text-sm text-slate-600">Công Việc Đang Tuyển</p>
        </Card>
        <Card className="text-center py-6 sm:py-8">
          <div className="text-3xl sm:text-4xl font-bold text-cyan-600">500+</div>
          <p className="mt-2 text-sm text-slate-600">Công Ty Tuyển Dụng</p>
        </Card>
        <Card className="text-center py-6 sm:py-8">
          <div className="text-3xl sm:text-4xl font-bold text-cyan-600">10K+</div>
          <p className="mt-2 text-sm text-slate-600">Ứng Viên Thành Công</p>
        </Card>
      </section>

      {/* Featured Jobs Section */}
      <section>
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h2 className="text-3xl font-bold text-slate-900">Việc Làm Nổi Bật</h2>
            <p className="mt-1 text-slate-600">Những vị trí tuyển dụng hot nhất hôm nay</p>
          </div>
          <Link href="/jobs">
            <Button variant="outline" size="md">
              Xem Tất Cả
            </Button>
          </Link>
        </div>

        {jobs.data.length === 0 ? (
          <Card className="py-12 text-center text-slate-500">
            Hiện không có công việc nào. Vui lòng quay lại sau.
          </Card>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {jobs.data.slice(0, 6).map((j) => (
              <Link
                key={j.job_id}
                href={`/jobs/${j.slug ?? j.job_id}`}
              >
                <Card hover className="h-full space-y-3">
                  <div>
                    <Badge variant="primary" size="sm">
                      {j.apply_count} ứng tuyển
                    </Badge>
                  </div>
                  <div>
                    <h3 className="font-semibold text-slate-900 line-clamp-2">
                      {j.title}
                    </h3>
                    <p className="mt-1 text-sm text-slate-600">
                      {j.company_name}
                    </p>
                  </div>

                  {j.description && (
                    <p className="line-clamp-2 text-sm text-slate-600">
                      {truncateText(j.description, 100)}
                    </p>
                  )}

                  <div className="flex items-center justify-between border-t pt-3">
                    <span className="font-semibold text-cyan-600">
                      {fmtSalary(j.salary_min)}–{fmtSalary(j.salary_max)}
                    </span>
                    <span className="text-xs text-slate-500">
                      {j.view_count} lượt xem
                    </span>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>

      {/* Benefits Section */}
      <section className="rounded-2xl bg-gradient-to-r from-slate-50 to-slate-100 p-8 sm:p-12">
        <h2 className="text-3xl font-bold text-slate-900">Tại Sao Chọn Job7189?</h2>
        <div className="mt-8 grid gap-6 md:grid-cols-3">
          <div className="space-y-2">
            <div className="text-3xl">🔍</div>
            <h3 className="font-semibold text-slate-900">Tìm Kiếm Thông Minh</h3>
            <p className="text-sm text-slate-600">
              Filter theo vị trí, kỹ năng, mức lương để tìm công việc phù hợp.
            </p>
          </div>
          <div className="space-y-2">
            <div className="text-3xl">📊</div>
            <h3 className="font-semibold text-slate-900">Theo Dõi Hồ Sơ</h3>
            <p className="text-sm text-slate-600">
              Quản lý tất cả đơn ứng tuyển và theo dõi tiến độ xử lý.
            </p>
          </div>
          <div className="space-y-2">
            <div className="text-3xl">💬</div>
            <h3 className="font-semibold text-slate-900">Liên Lạc Trực Tiếp</h3>
            <p className="text-sm text-slate-600">
              Chat với nhà tuyển dụng để hỏi đáp và thương lượng điều kiện.
            </p>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="rounded-2xl bg-slate-900 px-6 py-12 sm:px-12 sm:py-16 text-center text-white">
        <h2 className="text-3xl font-bold">Sẵn Sàng Bắt Đầu?</h2>
        <p className="mt-2 text-slate-300">Tạo hồ sơ và ứng tuyển vào công việc mơ ước của bạn hôm nay.</p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Link href="/jobs">
            <Button variant="primary" size="lg" className="bg-cyan-600 hover:bg-cyan-700">
              Khám Phá Công Việc
            </Button>
          </Link>
          <Link href="/login">
            <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/10">
              Đăng Ký Ngay
            </Button>
          </Link>
        </div>
      </section>
    </div>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
