import Link from "next/link";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";

export default function HomePage() {
  return (
    <div className="space-y-16">
      {/* Hero Section — Solid indigo, clean hierarchy */}
      <section className="rounded-2xl bg-brand px-6 py-16 sm:px-12 sm:py-24 text-white">
        <div className="max-w-3xl">
          <div className="inline-block mb-4 px-3 py-1 rounded-full bg-white/15 text-sm font-medium">
            Job7189 Recruiter Platform
          </div>
          <h1 className="text-5xl sm:text-6xl font-bold leading-tight text-balance">
            Hệ Thống Quản Lý Tuyển Dụng Toàn Diện
          </h1>
          <p className="mt-6 text-lg leading-relaxed text-brand-light">
            Quản lý công việc, đội ngũ, phỏng vấn và hồ sơ ứng viên từ một nơi duy nhất. Tối ưu hóa quy trình tuyển dụng của công ty bạn.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/recruiter">
              <Button variant="secondary" size="lg">
                Vào Trang Nhà Tuyển Dụng
              </Button>
            </Link>
            <Link href="/admin">
              <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/10">
                Vào Trang Quản Trị
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Role Selection — Unified design */}
      <section className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold text-slate-900">Chọn Vai Trò Của Bạn</h2>
          <p className="mt-2 text-slate-600">Truy cập các tính năng phù hợp với vai trò của bạn</p>
        </div>

        <div className="grid gap-6 md:grid-cols-2">
          <RoleCard
            emoji="👔"
            title="Nhà Tuyển Dụng"
            description="Quản lý workspace, tạo tin tuyển dụng, theo dõi ứng viên, lên lịch phỏng vấn và đánh giá."
            href="/recruiter"
            features={[
              "Quản lý workspace",
              "Tạo & quản lý tin tuyển",
              "Pipeline Kanban",
              "Lịch phỏng vấn",
              "Tin nhắn với ứng viên"
            ]}
          />
          <RoleCard
            emoji="⚙️"
            title="Quản Trị Hệ Thống"
            description="Duyệt & phê duyệt tin tuyển dụng, quản lý ngành nghề, người dùng, công ty và toàn bộ hệ thống."
            href="/admin"
            features={[
              "Duyệt tin tuyển",
              "Quản lý ngành nghề",
              "Quản lý người dùng",
              "Quản lý công ty",
              "Báo cáo & analytics"
            ]}
          />
        </div>
      </section>

      {/* Stats Section — Unified indigo styling */}
      <section className="rounded-2xl bg-slate-50 p-8 sm:p-12">
        <h2 className="text-3xl font-bold text-slate-900">Nền Tảng Đáng Tin Cậy</h2>
        <div className="mt-8 grid gap-6 md:grid-cols-4">
          <StatCard label="Công Ty" value="500+" />
          <StatCard label="Công Việc" value="5K+" />
          <StatCard label="Ứng Viên" value="50K+" />
          <StatCard label="Thành Công" value="10K+" />
        </div>
      </section>

      {/* Features Section — Clean unified design */}
      <section>
        <h2 className="text-3xl font-bold text-slate-900 mb-8">Tính Năng Chính</h2>
        <div className="grid gap-6 md:grid-cols-3">
          <FeatureCard
            emoji="📊"
            title="Dashboard Thông Minh"
            description="Theo dõi các chỉ số quan trọng: lượt xem, ứng tuyển, tỷ lệ chuyển đổi theo thời gian thực."
          />
          <FeatureCard
            emoji="📋"
            title="Quản Lý Công Việc"
            description="Tạo, chỉnh sửa, công bố và theo dõi trạng thái của tất cả tin tuyển dụng từ một nơi."
          />
          <FeatureCard
            emoji="👥"
            title="Quản Lý Ứng Viên"
            description="Tổ chức ứng viên vào pipeline, thực hiện phỏng vấn, lưu điểm và nhận xét chi tiết."
          />
          <FeatureCard
            emoji="💬"
            title="Liên Lạc Trực Tiếp"
            description="Gửi tin nhắn với ứng viên, nhà tuyển dụng trực tiếp qua nền tảng mà không cần email."
          />
          <FeatureCard
            emoji="⭐"
            title="Đánh Giá & Scorecard"
            description="Ghi lại ý kiến phỏng vấn, so sánh ứng viên và đưa ra quyết định tuyển dụng tốt hơn."
          />
          <FeatureCard
            emoji="📈"
            title="Báo Cáo & Phân Tích"
            description="Xem chi tiết về hiệu suất tuyển dụng, tỷ lệ chuyển đổi, thời gian tuyển dụng trung bình."
          />
        </div>
      </section>

      {/* CTA Section — Solid slate */}
      <section className="rounded-2xl bg-slate-900 px-6 py-12 sm:px-12 sm:py-16 text-center text-white">
        <h2 className="text-3xl font-bold">Bắt Đầu Quản Lý Tuyển Dụng Ngay</h2>
        <p className="mt-3 text-slate-300">Tối ưu hóa quy trình tuyển dụng và tìm được ứng viên tuyệt vời.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link href="/recruiter">
            <Button variant="primary" size="lg">
              Vào Trang Nhà Tuyển Dụng
            </Button>
          </Link>
          <Link href="/admin">
            <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/10">
              Vào Trang Quản Trị
            </Button>
          </Link>
        </div>
      </section>
    </div>
  );
}

function RoleCard({
  emoji,
  title,
  description,
  href,
  features,
}: {
  emoji: string;
  title: string;
  description: string;
  href: string;
  features: string[];
}) {
  return (
    <Link href={href}>
      <Card hover>
        <div className="space-y-4">
          <div className="text-3xl">{emoji}</div>
          <div>
            <h3 className="text-xl font-bold text-slate-900">{title}</h3>
            <p className="mt-2 text-sm text-slate-600 leading-relaxed">{description}</p>
          </div>
          <ul className="space-y-2 pt-2">
            {features.map((feature, i) => (
              <li key={i} className="flex items-center gap-2 text-sm text-slate-700">
                <span className="text-brand">✓</span> {feature}
              </li>
            ))}
          </ul>
          <div className="pt-2">
            <Button variant="outline" size="md" className="w-full">
              Truy Cập Ngay
            </Button>
          </div>
        </div>
      </Card>
    </Link>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <Card className="text-center py-8">
      <p className="text-3xl font-bold text-brand">{value}</p>
      <p className="mt-2 text-sm text-slate-600 font-medium">{label}</p>
    </Card>
  );
}

function FeatureCard({
  emoji,
  title,
  description,
}: {
  emoji: string;
  title: string;
  description: string;
}) {
  return (
    <Card>
      <div className="text-3xl mb-4">{emoji}</div>
      <h3 className="font-semibold text-slate-900 text-lg">{title}</h3>
      <p className="mt-2 text-sm text-slate-600 leading-relaxed">{description}</p>
    </Card>
  );
}
