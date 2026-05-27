import Link from "next/link";

export default function RecruiterLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex h-full gap-3 overflow-hidden">
      <aside className="rounded-lg border bg-white p-3 text-sm flex-shrink-0 overflow-y-auto">
        <div className="px-2 py-1 text-xs uppercase tracking-wide text-slate-500">
          Recruiter
        </div>
        <nav className="mt-1 flex flex-col gap-0.5">
          <SideLink href="/recruiter">Workspaces</SideLink>
          <SideLink href="/recruiter/profile">Hồ sơ của tôi</SideLink>
          <SideLink href="/recruiter/messages">Hộp thư</SideLink>
        </nav>
      </aside>
      <section className="flex-1 overflow-hidden">{children}</section>
    </div>
  );
}

function SideLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded px-2 py-1.5 text-slate-700 hover:bg-slate-50"
    >
      {children}
    </Link>
  );
}
