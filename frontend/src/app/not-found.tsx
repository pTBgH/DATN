import Link from "next/link";

export default function NotFound() {
  return (
    <div className="rounded-lg border bg-white p-8 text-center">
      <h1 className="text-2xl font-semibold">404 — Không tìm thấy</h1>
      <p className="mt-2 text-sm text-slate-500">
        Trang hoặc tài nguyên này không còn tồn tại.
      </p>
      <Link
        href="/"
        className="mt-4 inline-block rounded bg-brand px-4 py-2 text-white hover:bg-brand-dark"
      >
        Về trang chủ
      </Link>
    </div>
  );
}
