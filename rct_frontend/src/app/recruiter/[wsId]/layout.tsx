import Link from "next/link";
import { workspaceApi } from "@/lib/api";

export default async function WorkspaceLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { wsId: string };
}) {
  const ws = await workspaceApi.getWorkspace(params.wsId);
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between rounded-lg border bg-white p-5">
        <div>
          <Link href="/recruiter" className="text-xs text-slate-500 hover:underline">
            ← Workspaces
          </Link>
          <h1 className="mt-1 text-2xl font-semibold">{ws.name}</h1>
          <div className="text-sm text-slate-500">
            {ws.email} · {ws.location ?? "—"} · plan {ws.plan ?? "Free"}
          </div>
        </div>
        <Link
          href={`/recruiter/${ws.id}/jobs/new`}
          className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark"
        >
          Đăng tin mới
        </Link>
      </header>

      <nav className="flex gap-1 overflow-x-auto rounded-lg border bg-white p-1 text-sm">
        <Tab href={`/recruiter/${params.wsId}`}>Tổng quan</Tab>
        <Tab href={`/recruiter/${params.wsId}/jobs`}>Tin tuyển dụng</Tab>
        <Tab href={`/recruiter/${params.wsId}/pipelines`}>Pipeline</Tab>
        <Tab href={`/recruiter/${params.wsId}/members`}>Thành viên</Tab>
        <Tab href={`/recruiter/${params.wsId}/settings`}>Cài đặt</Tab>
      </nav>

      <div>{children}</div>
    </div>
  );
}

function Tab({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded px-3 py-1.5 text-slate-700 hover:bg-slate-50"
    >
      {children}
    </Link>
  );
}
