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
    <div className="space-y-16">
      {/* Hero Section — Solid teal, clean hierarchy */}
      <section className="rounded-2xl bg-brand px-6 py-16 sm:px-12 sm:py-24 text-white">
        <div className="max-w-3xl">
          <h1 className="text-5xl sm:text-6xl font-bold leading-tight text-balance">
            Tìm Cơ Hội Nghề Nghiệp Lý Tưởng
          </h1>
          <p className="mt-6 text-lg leading-relaxed text-brand-light">
            Khám phá hàng nghìn cơ hội việc làm từ các công ty hàng đầu. Nâng cao kỹ năng, phát triển sự nghiệp của bạn cùng Job7189.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/jobs">
              <Button variant="secondary" size="lg">
                Tìm Việc Ngay
              </Button>
            </Link>
            <Link href="/login">
              <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/10">
                Đăng Nhập / Đăng Ký
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Stats Section — Unified teal numeric styling */}
      <section className="grid grid-cols-3 gap-4 sm:gap-6">
        <Card className="text-center py-8">
          <div className="text-4xl font-bold text-brand">{jobs.data.length}</div>
          <p className="mt-2 text-sm text-slate-600 font-medium">Công Việc</p>
        </Card>
        <Card className="text-center py-8">
          <div className="text-4xl font-bold text-brand">500+</div>
          <p className="mt-2 text-sm text-slate-600 font-medium">Công Ty</p>
        </Card>
        <Card className="text-center py-8">
          <div className="text-4xl font-bold text-success">10K+</div>
          <p className="mt-2 text-sm text-slate-600 font-medium">Thành Công</p>
        </Card>
      </section>

      {/* Featured Jobs Section */}
      <section>
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h2 className="text-3xl font-bold text-slate-900">Việc Làm Nổi Bật</h2>
            <p className="mt-2 text-slate-600 text-sm">Những vị trí tuyển dụng phổ biến nhất hôm nay</p>
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
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {jobs.data.slice(0, 6).map((j) => (
              <Link
                key={j.job_id}
                href={`/jobs/${j.slug ?? j.job_id}`}
              >
                <Card hover className="h-full space-y-4">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1">
                      <h3 className="font-semibold text-slate-900 line-clamp-2 text-base">
                        {j.title}
                      </h3>
                      <p className="mt-1 text-sm text-slate-600">
                        {j.company_name}
                      </p>
                    </div>
                    <Badge variant="primary" size="sm" className="flex-shrink-0">
                      {j.apply_count}
                    </Badge>
                  </div>

                  {j.description && (
                    <p className="line-clamp-2 text-sm text-slate-600">
                      {truncateText(j.description, 100)}
                    </p>
                  )}

                  <div className="flex items-center justify-between pt-3 border-t border-slate-100">
                    <div>
                      <p className="text-xs text-slate-500">Mức lương</p>
                      <p className="font-semibold text-brand">
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

      {/* Benefits Section — Clean, unified design */}
      <section className="rounded-2xl bg-slate-50 p-8 sm:p-12">
        <h2 className="text-3xl font-bold text-slate-900">Tại Sao Chọn Job7189?</h2>
        <div className="mt-8 grid gap-8 md:grid-cols-3">
          <FeatureItem
            icon="🎯"
            title="Tìm Kiếm Thông Minh"
            description="Lọc theo vị trí, kỹ năng, mức lương để tìm công việc phù hợp nhất với mục tiêu của bạn."
          />
          <FeatureItem
            icon="📊"
            title="Theo Dõi Hồ Sơ"
            description="Quản lý tất cả đơn ứng tuyển và theo dõi tiến độ xử lý từng ứng tuyển."
          />
          <FeatureItem
            icon="💬"
            title="Liên Lạc Trực Tiếp"
            description="Chat với nhà tuyển dụng để hỏi đáp và thương lượng điều kiện ngay trên nền tảng."
          />
        </div>
      </section>

      {/* CTA Section — Solid slate, white text */}
      <section className="rounded-2xl bg-slate-900 px-6 py-12 sm:px-12 sm:py-16 text-center text-white">
        <h2 className="text-3xl font-bold">Sẵn Sàng Bắt Đầu?</h2>
        <p className="mt-3 text-slate-300">Tạo hồ sơ và ứng tuyển vào công việc mơ ước của bạn hôm nay.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link href="/jobs">
            <Button variant="primary" size="lg">
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

function FeatureItem({
  icon,
  title,
  description,
}: {
  icon: string;
  title: string;
  description: string;
}) {
  return (
    <div className="space-y-3">
      <div className="text-3xl">{icon}</div>
      <h3 className="font-semibold text-slate-900 text-lg">{title}</h3>
      <p className="text-sm text-slate-600 leading-relaxed">{description}</p>
    </div>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
