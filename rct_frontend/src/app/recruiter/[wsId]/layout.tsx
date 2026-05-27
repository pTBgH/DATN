import Link from "next/link";
import { workspaceApi } from "@/lib/api";
import { WorkspaceMenuButton } from "@/components/WorkspaceMenuButton";

export default async function WorkspaceLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { wsId: string };
}) {
  const ws = await workspaceApi.getWorkspace(params.wsId);
  return (
    <div className="flex h-full flex-col gap-3 bg-slate-50 p-3">
      <header className="flex items-center justify-between rounded-lg border bg-white px-4 py-3">
        <div className="flex items-center gap-3">
          <Link href="/recruiter" className="text-xs text-slate-500 hover:underline">
            ← Workspaces
          </Link>
          <div>
            <h1 className="text-base font-semibold">{ws.name}</h1>
            <div className="text-xs text-slate-500">{ws.email}</div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Link
            href={`/recruiter/${ws.id}/jobs/new`}
            className="rounded bg-brand px-3 py-1.5 text-xs font-medium text-white hover:bg-brand-dark transition"
          >
            Đăng tin mới
          </Link>
          <WorkspaceMenuButton wsId={params.wsId} location={ws.location} plan={ws.plan} />
        </div>
      </header>

      <nav className="flex gap-1 rounded-lg border bg-white p-1 text-xs overflow-x-auto">
        <Tab href={`/recruiter/${params.wsId}`}>Tổng quan</Tab>
        <Tab href={`/recruiter/${params.wsId}/jobs`}>Tin tuyển dụng</Tab>
        <Tab href={`/recruiter/${params.wsId}/pipelines`}>Pipeline</Tab>
      </nav>

      <div className="flex-1 overflow-auto">{children}</div>
    </div>
  );
}

function Tab({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded px-3 py-1.5 text-slate-700 hover:bg-slate-50 whitespace-nowrap transition"
    >
      {children}
    </Link>
  );
}
