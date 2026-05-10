import { identityApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function RecruiterProfilePage() {
  const profile = await identityApi.getRecruiterProfile();
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Hồ sơ Recruiter</h1>
      <section className="rounded-lg border bg-white p-6">
        <dl className="grid gap-3 text-sm md:grid-cols-2">
          <Row label="Họ tên">
            {profile.first_name} {profile.last_name}
          </Row>
          <Row label="Username">{profile.user_name}</Row>
          <Row label="Email">{profile.email}</Row>
          <Row label="Số điện thoại">{profile.phone_number ?? "—"}</Row>
          <Row label="Recruiter ID">
            <code className="text-xs">{profile.recruiter_id}</code>
          </Row>
          <Row label="Trạng thái">{profile.status_id}</Row>
        </dl>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Workspace tham gia</h2>
        <ul className="space-y-2 text-sm">
          {profile.workspaces.map((w) => (
            <li
              key={w.workspace_id}
              className="flex items-center justify-between rounded border bg-white p-3"
            >
              <div>
                <div className="font-medium">{w.company.name}</div>
                <div className="text-xs text-slate-500">
                  {w.email} · {w.member_status} · {w.permissions.length} permissions
                </div>
              </div>
              <div className="text-right text-xs text-slate-500">
                {w.company.active_jobs} jobs · {w.company.applications} applications
              </div>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-slate-500">{label}</dt>
      <dd className="mt-0.5 text-slate-900">{children}</dd>
    </div>
  );
}
