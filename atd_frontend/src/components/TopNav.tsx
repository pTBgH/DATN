"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { config } from "@/lib/config";
import { useMockAuth } from "@/lib/auth/mock";

export function TopNav() {
  const path = usePathname();
  const router = useRouter();
  const { email, name, signOut } = useMockAuth();

  const handleSignOut = () => {
    signOut();
    router.push("/");
  };

  return (
    <header className="border-b border-slate-200 bg-white sticky top-0 z-40">
      <div className="mx-auto flex max-w-6xl items-center gap-8 px-4 py-4">
        <Link href="/" className="flex items-center gap-2 text-lg font-bold">
          <div className="w-8 h-8 bg-brand rounded-lg flex items-center justify-center text-white text-sm font-bold">
            J
          </div>
          <span className="text-brand">Job7189</span>
          <span className="text-slate-400 text-sm ml-1">/ ATD</span>
        </Link>

        <nav className="flex items-center gap-6 text-sm text-slate-600 font-medium">
          <NavLink href="/jobs" active={path === "/" || path?.startsWith("/jobs")}>
            🔍 Việc làm
          </NavLink>
          {email ? (
            <>
              <NavLink href="/applications" active={path?.startsWith("/applications")}>
                📋 Đã ứng tuyển
              </NavLink>
              <NavLink href="/saved" active={path?.startsWith("/saved")}>
                ❤️ Đã lưu
              </NavLink>
              <NavLink href="/cvs" active={path?.startsWith("/cvs")}>
                📄 CV
              </NavLink>
              <NavLink href="/messages" active={path?.startsWith("/messages")}>
                💬 Tin nhắn
              </NavLink>
            </>
          ) : null}
        </nav>

        <div className="ml-auto flex items-center gap-4 text-sm">
          {config.useMock ? (
            <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-800">
              MOCK
            </span>
          ) : null}
          {email ? (
            <>
              <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-slate-50 border border-slate-200">
                <div className="w-6 h-6 rounded-full bg-brand/20 flex items-center justify-center text-xs font-bold text-brand">
                  {name?.charAt(0).toUpperCase() ?? email?.charAt(0).toUpperCase()}
                </div>
                <span className="text-slate-700 font-medium">{name ?? email}</span>
              </div>
              <Link
                href="/profile"
                className="text-slate-600 hover:text-brand hover:bg-slate-50 px-3 py-2 rounded-lg transition"
              >
                ⚙️ Hồ sơ
              </Link>
              <button
                onClick={handleSignOut}
                className="text-slate-600 hover:text-red-600 hover:bg-red-50 px-3 py-2 rounded-lg transition border border-transparent hover:border-red-200"
              >
                🚪 Đăng xuất
              </button>
            </>
          ) : (
            <Link
              href="/login"
              className="rounded-lg bg-brand px-4 py-2 text-white font-semibold hover:bg-brand-dark transition shadow-sm"
            >
              Đăng nhập
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}

function NavLink({
  href,
  active,
  children,
}: {
  href: string;
  active?: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className={"transition " + (active ? "text-brand" : "hover:text-brand")}
    >
      {children}
    </Link>
  );
}
