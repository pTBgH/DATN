"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { workspaceApi } from "@/lib/api";
import { WorkspaceMenuButton } from "@/components/WorkspaceMenuButton";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function WorkspaceLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const params = useParams<{ wsId: string }>();
  const { wsId } = params ?? {};

  const { data: ws, loading, error } = useAuthedFetch(
    () => workspaceApi.getWorkspace(wsId!),
    [wsId],
  );

  if (loading) return <PageLoading label="Đang tải workspace..." />;
  if (error) return <PageError message={error} />;
  if (!ws) return null;

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
          <WorkspaceMenuButton wsId={wsId!} location={ws.location} plan={ws.plan} />
        </div>
      </header>

      <nav className="flex gap-1 rounded-lg border bg-white p-1 text-xs overflow-x-auto">
        <Tab href={`/recruiter/${wsId}`}>Tổng quan</Tab>
        <Tab href={`/recruiter/${wsId}/jobs`}>Tin tuyển dụng</Tab>
        <Tab href={`/recruiter/${wsId}/pipelines`}>Pipeline</Tab>
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
