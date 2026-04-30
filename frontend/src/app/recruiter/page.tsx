import Link from "next/link";
import { workspaceApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function RecruiterHomePage() {
  const workspaces = await workspaceApi.getMyWorkspaces();

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Workspace của bạn</h1>
      <div className="grid gap-4 md:grid-cols-2">
        {workspaces.map((w) => (
          <Link
            key={w.id}
            href={`/recruiter/${w.id}`}
            className="rounded-lg border bg-white p-5 hover:border-brand"
          >
            <div className="text-base font-semibold">{w.name}</div>
            <div className="text-sm text-slate-500">{w.email}</div>
            <div className="mt-3 grid grid-cols-3 gap-3 text-xs text-slate-600">
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

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded border p-2 text-center">
      <div className="font-semibold">{value}</div>
      <div className="text-[10px] uppercase tracking-wide text-slate-500">
        {label}
      </div>
    </div>
  );
}
