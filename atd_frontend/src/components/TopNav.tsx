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
    <header className="border-b bg-white">
      <div className="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3">
        <Link href="/" className="text-lg font-semibold text-brand">
          Job7189 <span className="text-slate-400">/ ATD</span>
        </Link>

        <nav className="flex items-center gap-4 text-sm text-slate-600">
          <NavLink href="/jobs" active={path === "/" || path?.startsWith("/jobs")}>
            Việc làm
          </NavLink>
          {email ? (
            <>
              <NavLink href="/applications" active={path?.startsWith("/applications")}>
                Đã ứng tuyển
              </NavLink>
              <NavLink href="/saved" active={path?.startsWith("/saved")}>
                Đã lưu
              </NavLink>
              <NavLink href="/cvs" active={path?.startsWith("/cvs")}>
                CV
              </NavLink>
              <NavLink href="/messages" active={path?.startsWith("/messages")}>
                Tin nhắn
              </NavLink>
            </>
          ) : null}
        </nav>

        <div className="ml-auto flex items-center gap-3 text-sm">
          {config.useMock ? (
            <span className="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
              MOCK MODE
            </span>
          ) : null}
          {email ? (
            <>
              <Link
                href="/profile"
                className="rounded bg-slate-100 px-2 py-1 text-xs hover:bg-slate-200"
              >
                {name ?? email}
              </Link>
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
