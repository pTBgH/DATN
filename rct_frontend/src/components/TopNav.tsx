"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useMockAuth } from "@/lib/auth/mock";
import { useState, useRef, useEffect } from "react";
import { Building2, LayoutDashboard, FileText, Users, Folder, ChevronDown, LogOut } from "lucide-react";

export function TopNav() {
  const path = usePathname();
  const router = useRouter();
  const { role, email, signOut } = useMockAuth();
  const [openDropdown, setOpenDropdown] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setOpenDropdown(false);
      }
    }

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleSignOut = () => {
    signOut();
    router.push("/login");
  };

  return (
    <header className="border-b border-slate-100 bg-white sticky top-0 z-40">
      <div className="mx-auto flex max-w-7xl items-center gap-8 px-4 py-4">
        <Link href="/" className="flex items-center gap-2 flex-shrink-0 hover:opacity-80 transition-opacity duration-300">
          <div className="w-8 h-8 bg-brand rounded-[10px] flex items-center justify-center text-white text-sm font-bold">
            J
          </div>
          <span className="text-brand font-semibold">Job7189</span>
        </Link>

        {role === "recruiter" && (
          <nav className="flex items-center gap-8 text-sm">
            <NavLink href="/recruiter" active={path === "/recruiter" || path === "/"}>
              <Building2 className="w-4 h-4" />
              Workspace
            </NavLink>
          </nav>
        )}

        {role === "admin" && (
          <nav className="flex items-center gap-8 text-sm">
            <NavLink href="/admin" active={path === "/admin"}>
              <LayoutDashboard className="w-4 h-4" />
              Dashboard
            </NavLink>
            <NavLink href="/admin/jobs" active={path?.startsWith("/admin/jobs")}>
              <FileText className="w-4 h-4" />
              Duyệt Tin
            </NavLink>
            <NavLink href="/admin/companies" active={path?.startsWith("/admin/companies")}>
              <Building2 className="w-4 h-4" />
              Công Ty
            </NavLink>
            <NavLink href="/admin/users" active={path?.startsWith("/admin/users")}>
              <Users className="w-4 h-4" />
              Người Dùng
            </NavLink>
            <NavLink href="/admin/sectors" active={path?.startsWith("/admin/sectors")}>
              <Folder className="w-4 h-4" />
              Ngành
            </NavLink>
          </nav>
        )}

        <div className="ml-auto flex items-center gap-3">
          {role && email ? (
            <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => setOpenDropdown(!openDropdown)}
                className="flex items-center gap-2 px-3.5 py-2.5 rounded-[12px] hover:bg-slate-50 transition-all duration-300 ease-in-out text-slate-700 font-medium text-sm"
              >
                <div className="w-6 h-6 rounded-full bg-brand/15 flex items-center justify-center text-xs font-bold text-brand">
                  {email.charAt(0).toUpperCase()}
                </div>
                <span className="hidden sm:inline max-w-[100px] truncate">{email}</span>
                <ChevronDown className={`w-4 h-4 transition-transform duration-300 ${openDropdown ? "rotate-180" : ""}`} />
              </button>

              {openDropdown && (
                <div className="absolute right-0 mt-2 w-48 bg-white rounded-[12px] shadow-md border border-slate-100 py-2 z-50">
                  <div className="px-4 py-2.5 border-b border-slate-100">
                    <span className="text-xs text-slate-500 block">{email}</span>
                    <span className="text-xs font-semibold text-slate-700">
                      {role === "admin" ? "Quản Trị" : "Nhà Tuyển Dụng"}
                    </span>
                  </div>
                  <button
                    onClick={() => {
                      setOpenDropdown(false);
                      handleSignOut();
                    }}
                    className="w-full text-left flex items-center gap-3 px-4 py-2.5 hover:bg-red-50 transition-colors duration-200 text-red-600 text-sm"
                  >
                    <LogOut className="w-4 h-4" />
                    Đăng xuất
                  </button>
                </div>
              )}
            </div>
          ) : (
            <Link
              href="/login"
              className="rounded-[12px] bg-brand px-4 py-2.5 text-white font-semibold hover:bg-brand-dark transition-all duration-300 ease-in-out active:scale-95 text-sm"
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
      className={`flex items-center gap-2 transition-colors duration-300 ${
        active ? "text-brand font-semibold" : "text-slate-600 hover:text-brand"
      }`}
    >
      {children}
    </Link>
  );
}
