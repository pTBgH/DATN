import { workspaceApi } from "@/lib/api";

export const dynamic = "force-dynamic";

export default async function MembersPage({
  params,
}: {
  params: { wsId: string };
}) {
  // Reuse `getRecruiterProfile.workspaces` style from API_INVENTORY §2.3.
  const ws = await workspaceApi.getWorkspace(params.wsId);
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h2 className="text-lg font-semibold">Thành viên workspace</h2>
        <div className="flex gap-2 text-sm">
          <button className="rounded border px-3 py-1.5 hover:bg-slate-50">
            Tạo invite code
          </button>
          <button className="rounded bg-brand px-3 py-1.5 text-white hover:bg-brand-dark">
            Mời qua email
          </button>
        </div>
      </header>

      <p className="text-sm text-slate-500">
        Endpoint: `GET /api/workspaces/{ws.id}/members` (workspace-service §2.3) — skeleton hiện hiển thị mock data từ recruiter profile.
      </p>

      <ul className="divide-y rounded-lg border bg-white">
        <Member name="Anna Nguyen" email="anna@acme.io" status="Active" perms="OWNER" />
        <Member name="Bao Tran" email="bao@globex.com" status="Active" perms="CREATE_JOB" />
        <Member name="Linh Pham" email="linh@initech.vn" status="Pending" perms="—" />
      </ul>
    </div>
  );
}

function Member({
  name,
  email,
  status,
  perms,
}: {
  name: string;
  email: string;
  status: string;
  perms: string;
}) {
  return (
    <li className="flex items-center justify-between gap-4 p-4 text-sm">
      <div>
        <div className="font-medium">{name}</div>
        <div className="text-xs text-slate-500">{email}</div>
      </div>
      <span className="rounded bg-slate-100 px-2 py-0.5 text-xs">{status}</span>
      <span className="text-xs text-slate-500">{perms}</span>
      <button className="text-xs text-slate-500 hover:text-red-600">Xoá</button>
    </li>
  );
}
