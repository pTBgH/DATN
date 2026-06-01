"use client";

import { useParams } from "next/navigation";
import { workspaceApi } from "@/lib/api";
import { useAuthedFetch } from "@/lib/auth/guard";
import { PageLoading, PageError } from "@/components/PageState";

export default function WorkspaceSettingsPage() {
  const params = useParams<{ wsId: string }>();
  const { wsId } = params ?? {};

  const { data, loading, error } = useAuthedFetch(
    () =>
      Promise.all([
        workspaceApi.getWorkspace(wsId!),
        workspaceApi.getCompanyOptions(),
      ]),
    [wsId],
  );

  if (loading) return <PageLoading label="Đang tải cài đặt..." />;
  if (error) return <PageError message={error} />;
  if (!data) return null;

  const [ws, opts] = data;
  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h2 className="text-lg font-semibold">Cài đặt workspace</h2>
      <p className="text-sm text-slate-500">
        Submit thật sẽ gọi `PUT /api/workspaces/{ws.id}` (workspace-service §2.3).
      </p>

      <form className="space-y-4 rounded-lg border bg-white p-6">
        <Field label="Tên workspace">
          <input defaultValue={ws.name} className="w-full rounded border px-3 py-2" />
        </Field>
        <Field label="Email liên hệ">
          <input defaultValue={ws.email} className="w-full rounded border px-3 py-2" />
        </Field>
        <Field label="Địa điểm">
          <input
            defaultValue={ws.location ?? ""}
            className="w-full rounded border px-3 py-2"
          />
        </Field>
        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Quy mô">
            <select className="w-full rounded border px-3 py-2">
              {opts.sizes.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Ngành">
            <select className="w-full rounded border px-3 py-2">
              {opts.industries.map((i) => (
                <option key={i.id} value={i.id}>
                  {i.name}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="flex justify-end">
          <button className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
            Lưu
          </button>
        </div>
      </form>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block text-sm">
      <span className="font-medium text-slate-700">{label}</span>
      <div className="mt-1">{children}</div>
    </label>
  );
}
