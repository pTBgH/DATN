"use client";

import { identityApi } from "@/lib/api";
import { Card, CardContent, CardHeader } from "@/components/Card";
import { Button } from "@/components/Button";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function ProfilePage() {
  const { data: profile, loading, error } = useAuthedFetch(
    () => identityApi.getCandidateProfile(),
    [],
  );

  if (loading) return <PageLoading label="Đang tải hồ sơ..." />;
  if (error) return <PageError message={error} />;
  if (!profile) return null;
  return (
    <div className="space-y-6 max-w-4xl">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Hồ Sơ Của Tôi</h1>
        <p className="mt-1 text-slate-600">Cập nhật thông tin cá nhân để nâng cao cơ hội xin việc</p>
      </div>

      <form className="space-y-6">
        {/* Personal Information Section */}
        <Card>
          <CardHeader title="Thông Tin Cá Nhân" />
          <CardContent>
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Họ">
                <input
                  defaultValue={profile.last_name ?? ""}
                  placeholder="VD: Nguyễn"
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                />
              </Field>
              <Field label="Tên">
                <input
                  defaultValue={profile.first_name ?? ""}
                  placeholder="VD: Văn A"
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                />
              </Field>
              <Field label="Tên Người Dùng">
                <input
                  defaultValue={profile.user_name ?? ""}
                  placeholder="VD: nguyenvana"
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                />
              </Field>
              <Field label="Email (Không Thể Sửa)">
                <input
                  defaultValue={profile.email}
                  disabled
                  className="w-full rounded-lg border border-slate-200 bg-slate-50 px-4 py-2 text-slate-500 cursor-not-allowed"
                />
              </Field>
              <Field label="Số Điện Thoại">
                <input
                  defaultValue={profile.phone_number ?? ""}
                  type="tel"
                  placeholder="VD: 0123456789"
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                />
              </Field>
              <Field label="Ngày Sinh">
                <input
                  type="date"
                  defaultValue={profile.birth ?? ""}
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                />
              </Field>
            </div>
          </CardContent>
        </Card>

        {/* Professional Information Section */}
        <Card>
          <CardHeader title="Thông Tin Chuyên Môn" />
          <CardContent>
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Năm Kinh Nghiệm">
                <input
                  type="number"
                  min={0}
                  max={50}
                  defaultValue={profile.experience_years ?? 0}
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                />
              </Field>
              <Field label="Giới Tính">
                <select
                  defaultValue={profile.sex_id ?? ""}
                  className="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-100"
                >
                  <option value="">— Chọn giới tính —</option>
                  <option value="1">Nam</option>
                  <option value="2">Nữ</option>
                  <option value="3">Khác</option>
                </select>
              </Field>
            </div>
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <div className="flex flex-wrap gap-3 justify-end">
          <Button variant="outline" size="lg">
            Huỷ Bỏ
          </Button>
          <Button variant="primary" size="lg" type="submit">
            Lưu Thay Đổi
          </Button>
        </div>
      </form>

      {/* Help Section */}
      <Card className="bg-gray-50 border border-gray-200">
        <div className="p-4 space-y-3">
          <div className="flex items-start gap-3">
            <div className="text-lg font-bold text-gray-600">i</div>
            <div>
              <p className="font-semibold text-slate-900">Mẹo Hoàn Thành Hồ Sơ</p>
              <ul className="mt-2 space-y-1 text-sm text-slate-700">
                <li>• Thêm ảnh đại diện để tăng tỷ lệ được nhìn thấy</li>
                <li>• Điền đầy đủ thông tin giúp nhà tuyển dụng hiểu rõ hơn</li>
                <li>• Cập nhật năm kinh nghiệm để phù hợp với vị trí</li>
              </ul>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="text-sm font-medium text-slate-700">{label}</span>
      <div className="mt-1">{children}</div>
    </label>
  );
}
