import { identityApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function ProfilePage() {
  const profile = await identityApi.getCandidateProfile();
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Hồ sơ của bạn</h1>
      <p className="text-sm text-slate-500">
        Endpoint: `GET/PUT /api/candidates/profile` (identity-service §1.3).
      </p>

      <form className="space-y-4 rounded-lg border bg-white p-6">
        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Họ">
            <input
              defaultValue={profile.last_name ?? ""}
              className="w-full rounded border px-3 py-2"
            />
          </Field>
          <Field label="Tên">
            <input
              defaultValue={profile.first_name ?? ""}
              className="w-full rounded border px-3 py-2"
            />
          </Field>
          <Field label="Username">
            <input
              defaultValue={profile.user_name ?? ""}
              className="w-full rounded border px-3 py-2"
            />
          </Field>
          <Field label="Email">
            <input
              defaultValue={profile.email}
              disabled
              className="w-full cursor-not-allowed rounded border bg-slate-50 px-3 py-2 text-slate-500"
            />
          </Field>
          <Field label="Số điện thoại">
            <input
              defaultValue={profile.phone_number ?? ""}
              className="w-full rounded border px-3 py-2"
            />
          </Field>
          <Field label="Năm kinh nghiệm">
            <input
              type="number"
              min={0}
              max={50}
              defaultValue={profile.experience_years ?? 0}
              className="w-full rounded border px-3 py-2"
            />
          </Field>
          <Field label="Ngày sinh">
            <input
              type="date"
              defaultValue={profile.birth ?? ""}
              className="w-full rounded border px-3 py-2"
            />
          </Field>
          <Field label="Giới tính">
            <select
              defaultValue={profile.sex_id ?? ""}
              className="w-full rounded border px-3 py-2"
            >
              <option value="">—</option>
              <option value="1">Nam</option>
              <option value="2">Nữ</option>
              <option value="3">Khác</option>
            </select>
          </Field>
        </div>
        <div className="flex justify-end">
          <button className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
            Lưu
          </button>
        </div>
      </form>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block text-sm">
      <span className="font-medium text-slate-700">{label}</span>
      <div className="mt-1">{children}</div>
    </label>
  );
}
