"use client";

import { useParams } from "next/navigation";
import { workspaceApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function MembersPage() {
  const params = useParams<{ wsId: string }>();
  const { wsId } = params ?? {};

  // Reuse `getRecruiterProfile.workspaces` style from API_INVENTORY §2.3.
  const { data: ws, loading, error } = useAuthedFetch(
    () => workspaceApi.getWorkspace(wsId!),
    [wsId],
  );

  if (loading) return <PageLoading label="Đang tải thành viên..." />;
  if (error) return <PageError message={error} />;
  if (!ws) return null;
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
        Quản lý quyền truy cập của các thành viên trong {ws.name}.
      </p>

      <ul className="divide-y rounded-lg border bg-white">
        <Member name="Anna Nguyen" email="anna@acme.io" status="Đang hoạt động" perms="Chủ sở hữu" />
        <Member name="Bao Tran" email="bao@globex.com" status="Đang hoạt động" perms="Đăng tin" />
        <Member name="Linh Pham" email="linh@initech.vn" status="Chờ xác nhận" perms="—" />
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
