"use client";

import Link from "next/link";
import { adminApi } from "@/lib/api";
import { Stat } from "@/components/Stat";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function AdminHomePage() {
  const { data, loading, error } = useAuthedFetch(
    () =>
      Promise.all([
        adminApi.listPendingJobs(),
        adminApi.listSectors(),
        adminApi.listAdminUsers(),
        adminApi.listAdminCompanies(),
      ]),
    [],
  );

  if (loading) return <PageLoading label="Đang tải dữ liệu..." />;
  if (error) return <PageError message={error} />;
  if (!data) return null;

  const [pending, sectors, users, companies] = data;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Tổng quan hệ thống</h1>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Stat label="Tin chờ duyệt" value={pending.length} />
        <Stat label="Người dùng" value={users.length} />
        <Stat label="Công ty" value={companies.length} />
        <Stat label="Ngành nghề" value={sectors.filter((s) => s.active).length} />
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        <Link
          href="/admin/jobs"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Duyệt tin tuyển dụng</div>
          <p className="mt-1 text-sm text-slate-500">
            Xem các tin mới gửi, kiểm tra nội dung và phê duyệt trước khi công khai.
          </p>
        </Link>
        <Link
          href="/admin/sectors"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Quản lý ngành nghề</div>
          <p className="mt-1 text-sm text-slate-500">
            Cập nhật danh mục ngành nghề dùng cho bộ lọc và form đăng tin.
          </p>
        </Link>
        <Link
          href="/admin/users"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Người dùng</div>
          <p className="mt-1 text-sm text-slate-500">
            Theo dõi tài khoản ứng viên, nhà tuyển dụng và quản trị viên.
          </p>
        </Link>
        <Link
          href="/admin/companies"
          className="rounded-lg border bg-white p-5 hover:border-brand"
        >
          <div className="font-semibold">Công ty</div>
          <p className="mt-1 text-sm text-slate-500">
            Rà soát hồ sơ doanh nghiệp, workspace và trạng thái xác minh.
          </p>
        </Link>
      </section>
    </div>
  );
}
