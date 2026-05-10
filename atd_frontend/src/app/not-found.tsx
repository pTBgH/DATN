import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto max-w-md rounded-xl border bg-white p-8 text-center">
      <h1 className="text-2xl font-semibold">404</h1>
      <p className="mt-2 text-sm text-slate-500">Không tìm thấy trang bạn cần.</p>
      <Link href="/" className="mt-4 inline-block text-sm text-brand hover:underline">
        ← Về trang chủ
      </Link>
    </div>
  );
}
