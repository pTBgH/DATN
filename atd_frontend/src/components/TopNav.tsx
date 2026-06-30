"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useMockAuth } from "@/lib/auth/mock";
import { useState, useRef, useEffect } from "react";
import { Briefcase, ChevronDown, LogOut, User } from "lucide-react";

export function TopNav() {
  const path = usePathname();
  const router = useRouter();
  const { email, name, signOut } = useMockAuth();
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
    router.push("/");
  };

  return (
    <header className="border-b border-slate-100 bg-white sticky top-0 z-40">
      <div className="mx-auto flex max-w-6xl items-center gap-8 px-4 py-4">
        <Link href="/" className="flex items-center gap-2 flex-shrink-0 hover:opacity-80 transition-opacity duration-300">
          <div className="w-8 h-8 bg-brand rounded-[10px] flex items-center justify-center text-white text-sm font-bold">
            J
          </div>
          <span className="text-brand font-semibold">Job7189</span>
        </Link>

        <nav className="flex items-center gap-8 text-sm">
          <NavLink href="/jobs" active={path === "/" || path?.startsWith("/jobs")}>
            <Briefcase className="w-4 h-4" />
            Việc làm
          </NavLink>
        </nav>

        <div className="ml-auto flex items-center gap-3">
          {email ? (
            <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => setOpenDropdown(!openDropdown)}
                className="flex items-center gap-2 px-3.5 py-2.5 rounded-[12px] hover:bg-slate-50 transition-all duration-300 ease-in-out text-slate-700 font-medium text-sm"
              >
                <div className="w-6 h-6 rounded-full bg-brand/15 flex items-center justify-center text-xs font-bold text-brand">
                  {name?.charAt(0).toUpperCase() ?? email?.charAt(0).toUpperCase()}
                </div>
                <span className="hidden sm:inline">{name ?? email}</span>
                <ChevronDown className={`w-4 h-4 transition-transform duration-300 ${openDropdown ? "rotate-180" : ""}`} />
              </button>

              {openDropdown && (
                <div className="absolute right-0 mt-2 w-56 bg-white rounded-[12px] shadow-md border border-slate-100 py-2 z-50">
                  <Link
                    href="/applications"
                    onClick={() => setOpenDropdown(false)}
                    className="flex items-center gap-3 px-4 py-2.5 hover:bg-slate-50 transition-colors duration-200 text-slate-700 text-sm"
                  >
                    <Briefcase className="w-4 h-4 text-slate-400" />
                    Đã ứng tuyển
                  </Link>
                  <Link
                    href="/saved"
                    onClick={() => setOpenDropdown(false)}
                    className="flex items-center gap-3 px-4 py-2.5 hover:bg-slate-50 transition-colors duration-200 text-slate-700 text-sm"
                  >
                    <svg className="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h6a2 2 0 012 2v16l-7-3.5L5 21V5z" />
                    </svg>
                    Đã lưu
                  </Link>
                  <Link
                    href="/cvs"
                    onClick={() => setOpenDropdown(false)}
                    className="flex items-center gap-3 px-4 py-2.5 hover:bg-slate-50 transition-colors duration-200 text-slate-700 text-sm"
                  >
                    <svg className="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                    </svg>
                    CV
                  </Link>
                  <Link
                    href="/messages"
                    onClick={() => setOpenDropdown(false)}
                    className="flex items-center gap-3 px-4 py-2.5 hover:bg-slate-50 transition-colors duration-200 text-slate-700 text-sm"
                  >
                    <svg className="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                    Tin nhắn
                  </Link>
                  <hr className="my-2 border-slate-100" />
                  <Link
                    href="/profile"
                    onClick={() => setOpenDropdown(false)}
                    className="flex items-center gap-3 px-4 py-2.5 hover:bg-slate-50 transition-colors duration-200 text-slate-700 text-sm"
                  >
                    <User className="w-4 h-4 text-slate-400" />
                    Hồ sơ
                  </Link>
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
        active
          ? "text-brand font-semibold"
          : "text-slate-600 hover:text-brand"
      }`}
    >
      {children}
    </Link>
  );
}
