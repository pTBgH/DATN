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
      <section className="rounded-2xl bg-gradient-to-r from-blue-600 to-blue-700 px-6 py-16 sm:px-12 sm:py-24 text-white shadow-md">
        <div className="max-w-2xl">
          <h1 className="text-5xl sm:text-6xl font-bold leading-tight">
            Tìm Cơ Hội Nghề Nghiệp Lý Tưởng
          </h1>
          <p className="mt-4 text-lg text-blue-50">
            Khám phá hàng nghìn cơ hội việc làm từ các công ty hàng đầu. Nâng cao kỹ năng, phát triển sự nghiệp của bạn.
          </p>
          <div className="mt-8 flex flex-wrap gap-4">
            <Link href="/jobs">
              <Button variant="secondary" size="lg" className="bg-white border-2 border-blue-600 text-blue-600 hover:bg-blue-50 font-semibold">
                Tìm Việc Ngay
              </Button>
            </Link>
            <Link href="/login">
              <Button variant="outline" size="lg" className="border-white text-white hover:bg-blue-500/30 font-semibold">
                Đăng Nhập / Đăng Ký
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="grid grid-cols-3 gap-4 sm:gap-6">
        <Card className="text-center py-8 bg-white border border-gray-200 rounded-lg">
          <div className="text-4xl font-bold text-blue-600">{jobs.data.length}</div>
          <p className="mt-2 text-sm text-slate-700 font-medium">Công Việc</p>
        </Card>
        <Card className="text-center py-8 bg-white border border-gray-200 rounded-lg">
          <div className="text-4xl font-bold text-green-600">500+</div>
          <p className="mt-2 text-sm text-slate-700 font-medium">Công Ty</p>
        </Card>
        <Card className="text-center py-8 bg-white border border-gray-200 rounded-lg">
          <div className="text-4xl font-bold text-orange-600">10K+</div>
          <p className="mt-2 text-sm text-slate-700 font-medium">Thành Công</p>
        </Card>
      </section>

      {/* Featured Jobs Section */}
      <section>
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h2 className="text-3xl font-bold text-slate-900">Việc Làm Nổi Bật</h2>
            <p className="mt-2 text-slate-600 text-sm">Những vị trí tuyển dụng phổ biến nhất</p>
          </div>
          <Link href="/jobs">
            <Button variant="outline" size="md">
              Xem Tất Cả
            </Button>
          </Link>
        </div>

        {jobs.data.length === 0 ? (
          <Card className="py-12 text-center text-slate-500 bg-gray-50 border border-gray-200">
            Hiện không có công việc nào. Vui lòng quay lại sau.
          </Card>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {jobs.data.slice(0, 6).map((j) => (
              <Link
                key={j.job_id}
                href={`/jobs/${j.slug ?? j.job_id}`}
              >
                <Card hover className="h-full space-y-4 bg-white border border-gray-200">
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <h3 className="font-semibold text-slate-900 line-clamp-2 text-base">
                        {j.title}
                      </h3>
                      <p className="mt-1 text-sm text-slate-600">
                        {j.company_name}
                      </p>
                    </div>
                    <Badge variant="primary" size="sm">
                      {j.apply_count}
                    </Badge>
                  </div>

                  {j.description && (
                    <p className="line-clamp-2 text-sm text-slate-600">
                      {truncateText(j.description, 100)}
                    </p>
                  )}

                  <div className="flex items-center justify-between pt-3 border-t border-gray-100">
                    <div>
                      <p className="text-xs text-slate-500">Mức lương</p>
                      <p className="font-semibold text-blue-600">
                        {fmtSalary(j.salary_min)}–{fmtSalary(j.salary_max)}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-slate-500">{j.view_count} xem</p>
                    </div>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>

      {/* Benefits Section */}
      <section className="rounded-2xl bg-gray-50 p-8 sm:p-12 border border-gray-200">
        <h2 className="text-3xl font-bold text-slate-900">Tại Sao Chọn Job7189?</h2>
        <div className="mt-8 grid gap-6 md:grid-cols-3">
          <div className="space-y-3">
            <div className="inline-flex items-center justify-center w-10 h-10 rounded-lg bg-blue-100">
              <span className="text-sm font-bold text-blue-600">1</span>
            </div>
            <h3 className="font-semibold text-slate-900">Tìm Kiếm Thông Minh</h3>
            <p className="text-sm text-slate-600">
              Lọc theo vị trí, kỹ năng, mức lương để tìm công việc phù hợp.
            </p>
          </div>
          <div className="space-y-3">
            <div className="inline-flex items-center justify-center w-10 h-10 rounded-lg bg-green-100">
              <span className="text-sm font-bold text-green-600">2</span>
            </div>
            <h3 className="font-semibold text-slate-900">Theo Dõi Hồ Sơ</h3>
            <p className="text-sm text-slate-600">
              Quản lý tất cả đơn ứng tuyển và theo dõi tiến độ xử lý.
            </p>
          </div>
          <div className="space-y-3">
            <div className="inline-flex items-center justify-center w-10 h-10 rounded-lg bg-orange-100">
              <span className="text-sm font-bold text-orange-600">3</span>
            </div>
            <h3 className="font-semibold text-slate-900">Liên Lạc Trực Tiếp</h3>
            <p className="text-sm text-slate-600">
              Chat với nhà tuyển dụng để hỏi đáp và thương lượng điều kiện.
            </p>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="rounded-2xl bg-slate-900 px-6 py-12 sm:px-12 sm:py-16 text-center text-white shadow-md">
        <h2 className="text-3xl font-bold">Sẵn Sàng Bắt Đầu?</h2>
        <p className="mt-3 text-gray-300">Tạo hồ sơ và ứng tuyển vào công việc mơ ước của bạn hôm nay.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link href="/jobs">
            <Button variant="primary" size="lg" className="bg-blue-600 hover:bg-blue-700 font-semibold">
              Khám Phá Công Việc
            </Button>
          </Link>
          <Link href="/login">
            <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/10 font-semibold">
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
