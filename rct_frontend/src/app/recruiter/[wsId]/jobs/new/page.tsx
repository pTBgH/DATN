import Link from "next/link";
import { jobApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function NewJobPage({ params }: { params: { wsId: string } }) {
  const opts = await jobApi.getGeneralOptions();
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <header>
        <Link
          href={`/recruiter/${params.wsId}/jobs`}
          className="text-xs text-slate-500 hover:underline"
        >
          ← Danh sách tin
        </Link>
        <h1 className="mt-1 text-2xl font-semibold">Đăng tin mới</h1>
        <p className="text-sm text-slate-500">
          Skeleton form theo schema <code>JobInput</code> (xem
          <code>frontend/docs/API_INVENTORY.md</code> §3). Submit thật sẽ gọi{" "}
          <code>POST /api/workspaces/&#123;wsId&#125;/jobs/draft</code> (lưu nháp) hoặc{" "}
          <code>…/jobs/submit</code> (gửi duyệt).
        </p>
      </header>

      <form className="space-y-4 rounded-lg border bg-white p-6">
        <Field label="Tiêu đề *">
          <input
            name="title"
            required
            className="w-full rounded border px-3 py-2"
            placeholder="VD: Senior Backend Engineer (Go)"
          />
        </Field>

        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Loại công việc">
            <select name="job_type" className="w-full rounded border px-3 py-2">
              {opts.job_types.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Ngành">
            <select name="job_sector" className="w-full rounded border px-3 py-2">
              {opts.job_sectors.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Hình thức làm việc">
            <select name="working_type" className="w-full rounded border px-3 py-2">
              {opts.working_types.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Hợp đồng">
            <select name="contract_type" className="w-full rounded border px-3 py-2">
              {opts.contract_types.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Trình độ">
            <select name="degree_level" className="w-full rounded border px-3 py-2">
              {opts.degree_levels.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Currency">
            <select name="currency" className="w-full rounded border px-3 py-2">
              {opts.currencies.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Lương min">
            <input name="salary_min" type="number" className="w-full rounded border px-3 py-2" />
          </Field>
          <Field label="Lương max">
            <input name="salary_max" type="number" className="w-full rounded border px-3 py-2" />
          </Field>
          <Field label="Deadline">
            <input name="deadline" type="date" className="w-full rounded border px-3 py-2" />
          </Field>
          <Field label="Số năm kinh nghiệm">
            <input name="exp_years" type="number" min={0} max={50} className="w-full rounded border px-3 py-2" />
          </Field>
        </div>

        <Field label="Mô tả">
          <textarea name="description" rows={5} className="w-full rounded border px-3 py-2" />
        </Field>
        <Field label="Yêu cầu">
          <textarea name="requirements" rows={5} className="w-full rounded border px-3 py-2" />
        </Field>
        <Field label="Quyền lợi">
          <textarea name="benefits" rows={5} className="w-full rounded border px-3 py-2" />
        </Field>

        <div className="flex gap-2">
          <button
            type="submit"
            formAction="#"
            className="rounded border px-4 py-2 text-sm hover:bg-slate-50"
          >
            Lưu nháp
          </button>
          <button
            type="submit"
            formAction="#"
            className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark"
          >
            Gửi duyệt
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
