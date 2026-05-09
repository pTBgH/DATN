import { candidateApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function ResumeManagerPage() {
  const cvs = await candidateApi.listResumes();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-2xl font-semibold">Quản lý CV</h1>
        <button className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark">
          + Tải lên CV mới
        </button>
      </header>
      <p className="text-sm text-slate-500">
        Flow upload (xem `frontend/docs/API_INVENTORY.md` §7.3):
        <br />
        1. `POST /api/presigned-url` → 2. `PUT &lt;url&gt;` (file binary) → 3. `POST
        /api/resumes` với <code>cv_path</code> trả về.
      </p>

      <ul className="space-y-3">
        {cvs.map((cv) => (
          <li
            key={cv.cv_id}
            className="flex items-center justify-between gap-4 rounded-lg border bg-white p-4"
          >
            <div className="flex-1">
              <div className="font-semibold">{cv.title}</div>
              <div className="text-xs text-slate-500">
                Cập nhật {new Date(cv.updated_at).toLocaleDateString("vi-VN")} ·{" "}
                <code className="text-[10px]">{cv.cv_path}</code>
              </div>
            </div>
            {cv.is_default ? (
              <span className="rounded bg-brand-50 px-2 py-0.5 text-xs text-brand">
                Mặc định
              </span>
            ) : (
              <button className="text-xs text-slate-500 hover:text-brand">
                Đặt mặc định
              </button>
            )}
            {cv.view_url ? (
              <a
                href={cv.view_url}
                target="_blank"
                rel="noreferrer"
                className="text-xs text-brand hover:underline"
              >
                Mở
              </a>
            ) : null}
            <button className="text-xs text-slate-500 hover:text-red-600">
              Xoá
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
