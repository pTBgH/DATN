"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { config } from "@/lib/config";
import { useMockAuth } from "@/lib/auth/mock";

export function TopNav() {
  const path = usePathname();
  const router = useRouter();
  const { role, email, signOut } = useMockAuth();

  const handleSignOut = () => {
    signOut();
    router.push("/login");
  };

  return (
    <header className="border-b bg-white">
      <div className="mx-auto flex max-w-7xl items-center gap-6 px-4 py-3">
        <Link href="/" className="text-lg font-semibold text-brand">
          Job7189 <span className="text-slate-400">/ RCT</span>
        </Link>

        <nav className="flex items-center gap-4 text-sm text-slate-600">
          {role === "recruiter" || !role ? (
            <Link
              href="/recruiter"
              className={path?.startsWith("/recruiter") ? "text-brand" : ""}
            >
              Nhà tuyển dụng
            </Link>
          ) : null}
          {role === "admin" || !role ? (
            <Link
              href="/admin"
              className={path?.startsWith("/admin") ? "text-brand" : ""}
            >
              Quản trị hệ thống
            </Link>
          ) : null}
        </nav>

        <div className="ml-auto flex items-center gap-3 text-sm">
          {config.useMock ? (
            <span className="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
              MOCK MODE
            </span>
          ) : null}
          {role && email ? (
            <>
              <span className="rounded bg-slate-100 px-2 py-1 text-xs">
                {email} · {role}
              </span>
              <button
                onClick={handleSignOut}
                className="rounded border px-3 py-1.5 text-sm hover:bg-slate-50"
              >
                Đăng xuất
              </button>
            </>
          ) : (
            <Link
              href="/login"
              className="rounded bg-brand px-3 py-1.5 text-white hover:bg-brand-dark"
            >
              Đăng nhập
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
