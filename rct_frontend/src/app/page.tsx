import Link from "next/link";
import { Card } from "@/components/Card";
import { Badge } from "@/components/Badge";
import { Button } from "@/components/Button";

export default function HomePage() {
  return (
    <div className="space-y-20">
      {/* Hero Section — Premium serif typography */}
      <section className="rounded-3xl bg-gradient-to-br from-brand to-brand-dark px-6 py-20 sm:px-12 sm:py-28 text-white overflow-hidden relative">
        <div className="max-w-3xl relative z-10">
          <div className="inline-block mb-6 px-4 py-2 rounded-full bg-white/10 text-sm font-medium backdrop-blur-sm border border-white/20">
            Job7189 Recruiter Platform
          </div>
          <h1 className="text-6xl sm:text-7xl font-serif font-bold leading-tight text-balance">
            Hệ Thống Quản Lý Tuyển Dụng Toàn Diện
          </h1>
          <p className="mt-8 text-lg sm:text-xl leading-relaxed text-brand-light font-light">
            Quản lý công việc, đội ngũ, phỏng vấn và hồ sơ ứng viên từ một nơi duy nhất. Tối ưu hóa quy trình tuyển dụng của công ty bạn.
          </p>
          <div className="mt-10 flex flex-wrap gap-4">
            <Link href="/recruiter">
              <Button variant="secondary" size="lg" className="font-medium">
                Vào Trang Nhà Tuyển Dụng
              </Button>
            </Link>
            <Link href="/admin">
              <Button variant="outline" size="lg" className="border-white text-white hover:bg-white/15 font-medium">
                Vào Trang Quản Trị
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Role Selection — Premium cards */}
      <section className="space-y-8">
        <div>
          <h2 className="text-4xl font-serif font-bold text-foreground">Chọn Vai Trò Của Bạn</h2>
          <p className="mt-3 text-foreground-muted font-light">Truy cập các tính năng phù hợp với vai trò của bạn</p>
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

      {/* Stats Section — Premium styling */}
      <section className="py-6">
        <h2 className="text-4xl font-serif font-bold text-foreground mb-2">Nền Tảng Đáng Tin Cậy</h2>
        <p className="text-foreground-muted font-light mb-12">Được tin tưởng bởi các công ty hàng đầu</p>
        <div className="grid gap-6 md:grid-cols-4">
          <StatCard label="CÔNG TY" value="500+" />
          <StatCard label="CÔ HỘI" value="5K+" />
          <StatCard label="ỨNG VIÊN" value="50K+" />
          <StatCard label="THÀNH CÔNG" value="10K+" />
        </div>
      </section>

      {/* Features Section — Premium design */}
      <section>
        <h2 className="text-4xl font-serif font-bold text-foreground mb-2">Tính Năng Chính</h2>
        <p className="text-foreground-muted font-light mb-12">Tất cả công cụ bạn cần để quản lý tuyển dụng hiệu quả</p>
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

      {/* CTA Section — Premium dark */}
      <section className="rounded-3xl bg-foreground px-6 py-20 sm:px-12 sm:py-28 text-center text-white">
        <h2 className="text-5xl sm:text-6xl font-serif font-bold text-balance">Bắt Đầu Quản Lý Tuyển Dụng Ngay</h2>
        <p className="mt-6 text-lg font-light text-slate-300">Tối ưu hóa quy trình tuyển dụng và tìm được ứng viên tuyệt vời.</p>
        <div className="mt-10 flex flex-wrap justify-center gap-4">
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
    <div className="rounded-2xl bg-white shadow-card p-10 text-center group hover:shadow-lg transition-shadow">
      <p className="text-5xl font-serif font-bold text-brand">{value}</p>
      <p className="mt-3 text-xs font-medium text-muted-dark tracking-widest">{label}</p>
    </div>
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
    <div className="rounded-2xl bg-white shadow-card p-8 group hover:shadow-lg transition-shadow">
      <div className="text-5xl mb-4 group-hover:scale-110 transition-transform duration-300">{emoji}</div>
      <h3 className="font-serif font-bold text-foreground text-xl">{title}</h3>
      <p className="mt-3 text-foreground-muted font-light leading-relaxed">{description}</p>
    </div>
  );
}
