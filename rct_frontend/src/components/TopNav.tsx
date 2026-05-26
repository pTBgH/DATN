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
    <header className="border-b border-slate-200 bg-white sticky top-0 z-40">
      <div className="mx-auto flex max-w-7xl items-center gap-8 px-4 py-4">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2 text-lg font-bold">
          <div className="w-8 h-8 bg-brand rounded-lg flex items-center justify-center text-white text-sm font-bold">
            J
          </div>
          <span className="text-brand">Job7189</span>
          <span className="text-slate-400 text-sm ml-1">/ RCT</span>
        </Link>

        {/* Navigation - Recruiter */}
        {role === "recruiter" && (
          <nav className="flex items-center gap-6 text-sm text-slate-600 font-medium">
            <NavLink href="/recruiter" active={path === "/recruiter" || path === "/"}>
              🏢 Workspace
            </NavLink>
          </nav>
        )}

        {/* Navigation - Admin */}
        {role === "admin" && (
          <nav className="flex items-center gap-6 text-sm text-slate-600 font-medium">
            <NavLink href="/admin" active={path === "/admin"}>
              📊 Dashboard
            </NavLink>
            <NavLink href="/admin/jobs" active={path?.startsWith("/admin/jobs")}>
              💼 Duyệt Công Việc
            </NavLink>
            <NavLink href="/admin/companies" active={path?.startsWith("/admin/companies")}>
              🏢 Công Ty
            </NavLink>
            <NavLink href="/admin/users" active={path?.startsWith("/admin/users")}>
              👤 Người Dùng
            </NavLink>
            <NavLink href="/admin/sectors" active={path?.startsWith("/admin/sectors")}>
              📁 Ngành Nghề
            </NavLink>
          </nav>
        )}

        {/* User Section */}
        <div className="ml-auto flex items-center gap-4 text-sm">
          {config.useMock && (
            <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-800">
              MOCK
            </span>
          )}
          {role && email ? (
            <>
              <div className="flex items-center gap-3 px-3 py-2 rounded-lg bg-slate-50 border border-slate-200">
                <div className="w-6 h-6 rounded-full bg-brand/20 flex items-center justify-center text-xs font-bold text-brand">
                  {email.charAt(0).toUpperCase()}
                </div>
                <div className="text-right">
                  <span className="text-slate-700 font-medium text-xs block">{email}</span>
                  <span className="text-slate-500 text-xs">
                    {role === "admin" ? "👑 Quản Trị" : "💼 NTD"}
                  </span>
                </div>
              </div>
              <button
                onClick={handleSignOut}
                className="text-slate-600 hover:text-red-600 hover:bg-red-50 px-3 py-2 rounded-lg transition border border-transparent hover:border-red-200 font-medium"
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
      className={active ? "text-brand font-semibold transition" : "hover:text-brand transition"}
    >
      {children}
    </Link>
  );
}
