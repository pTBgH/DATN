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
    <div className="space-y-20">
      {/* Hero Section — Premium typography with serif headline */}
      <section className="rounded-3xl bg-gradient-to-br from-brand to-brand-dark px-6 py-20 sm:px-12 sm:py-28 text-white overflow-hidden relative">
        <div className="max-w-3xl relative z-10">
          <h1 className="text-6xl sm:text-7xl font-serif font-bold leading-tight text-balance">
            Tìm Cơ Hội Nghề Nghiệp Lý Tưởng
          </h1>
          <p className="mt-8 text-lg sm:text-xl leading-relaxed text-brand-light font-light">
            Khám phá hàng nghìn cơ hội việc làm từ các công ty hàng đầu. Nâng cao kỹ năng, phát triển sự nghiệp của bạn cùng Job7189.
          </p>
          <div className="mt-10 flex flex-wrap gap-4">
            <Link href="/jobs">
              <Button variant="secondary" size="lg" className="font-medium">
                Tìm Việc Ngay
              </Button>
            </Link>
            <Link href="/login">
              <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/15 font-medium">
                Đăng Nhập / Đăng Ký
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Stats Section — Premium card styling */}
      <section className="grid grid-cols-3 gap-6 sm:gap-8">
        <div className="rounded-2xl bg-white shadow-card p-10 text-center">
          <div className="text-5xl font-serif font-bold text-brand">{jobs.data.length}</div>
          <p className="mt-3 text-sm font-medium text-muted-dark tracking-wide">CÔ HỘI VIỆC LÀM</p>
        </div>
        <div className="rounded-2xl bg-white shadow-card p-10 text-center">
          <div className="text-5xl font-serif font-bold text-brand">500+</div>
          <p className="mt-3 text-sm font-medium text-muted-dark tracking-wide">CÔNG TY HÀNG ĐẦU</p>
        </div>
        <div className="rounded-2xl bg-white shadow-card p-10 text-center">
          <div className="text-5xl font-serif font-bold text-success">10K+</div>
          <p className="mt-3 text-sm font-medium text-muted-dark tracking-wide">THÀNH CÔNG</p>
        </div>
      </section>

      {/* Featured Jobs Section */}
      <section>
        <div className="mb-12 flex items-center justify-between">
          <div>
            <h2 className="text-4xl font-serif font-bold text-foreground">Việc Làm Nổi Bật</h2>
            <p className="mt-3 text-foreground-muted font-light">Những vị trí tuyển dụng hấp dẫn nhất hôm nay</p>
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

      {/* Benefits Section — Premium design */}
      <section className="py-6">
        <h2 className="text-4xl font-serif font-bold text-foreground mb-2">Tại Sao Chọn Job7189?</h2>
        <p className="text-foreground-muted font-light mb-12">Nền tảng được thiết kế để giúp bạn thành công</p>
        <div className="grid gap-10 md:grid-cols-3">
          <FeatureItem
            emoji="🎯"
            title="Tìm Kiếm Thông Minh"
            description="Lọc theo vị trí, kỹ năng, mức lương để tìm công việc phù hợp nhất với mục tiêu của bạn."
          />
          <FeatureItem
            emoji="📊"
            title="Theo Dõi Hồ Sơ"
            description="Quản lý tất cả đơn ứng tuyển và theo dõi tiến độ xử lý từng ứng tuyển."
          />
          <FeatureItem
            emoji="💬"
            title="Liên Lạc Trực Tiếp"
            description="Chat với nhà tuyển dụng để hỏi đáp và thương lượng điều kiện ngay trên nền tảng."
          />
        </div>
      </section>

      {/* CTA Section — Premium dark background */}
      <section className="rounded-3xl bg-foreground px-6 py-20 sm:px-12 sm:py-28 text-center text-white">
        <h2 className="text-5xl sm:text-6xl font-serif font-bold text-balance">Sẵn Sàng Bắt Đầu?</h2>
        <p className="mt-6 text-lg font-light text-slate-300">Tạo hồ sơ và ứng tuyển vào công việc mơ ước của bạn hôm nay.</p>
        <div className="mt-10 flex flex-wrap justify-center gap-4">
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
  emoji,
  title,
  description,
}: {
  emoji: string;
  title: string;
  description: string;
}) {
  return (
    <div className="space-y-4 group">
      <div className="text-5xl group-hover:scale-110 transition-transform duration-300">{emoji}</div>
      <h3 className="font-serif font-bold text-foreground text-xl">{title}</h3>
      <p className="text-foreground-muted font-light leading-relaxed">{description}</p>
    </div>
  );
}

function fmtSalary(v: number | null) {
  if (v === null) return "-";
  return Intl.NumberFormat("vi-VN").format(v);
}
