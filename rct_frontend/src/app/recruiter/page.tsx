import Link from "next/link";
import { workspaceApi } from "@/lib/api";
import { Stat } from "@/components/Stat";

export const dynamic = "force-dynamic";

export default async function RecruiterHomePage() {
  const workspaces = await workspaceApi.getMyWorkspaces();

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-2xl font-semibold">Workspace của bạn</h1>
        <Link
          href="/recruiter/new-workspace"
          className="rounded border px-3 py-1.5 text-sm hover:bg-slate-50"
        >
          + Tạo workspace
        </Link>
      </header>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {workspaces.map((w) => (
          <Link
            key={w.id}
            href={`/recruiter/${w.id}`}
            className="block rounded-lg border bg-white p-5 transition hover:border-brand"
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <div className="text-base font-semibold text-slate-900">{w.name}</div>
                <div className="text-sm text-slate-500">{w.email}</div>
              </div>
              <span className="rounded bg-brand-50 px-2 py-0.5 text-xs font-medium text-brand">
                {w.plan ?? "Free"}
              </span>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-2 text-xs">
              <Stat label="Active jobs" value={w.active_jobs} />
              <Stat label="Views" value={w.views} />
              <Stat label="Apply rate" value={`${w.apply_rate}%`} />
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
