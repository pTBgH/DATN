import { config } from "@/lib/config";
import { mockCompanyOptions, mockMyWorkspaces } from "@/mocks/workspace";
import type {
  CompanyOptionsResponse,
  CreateWorkspaceInput,
  InvitationCodeResponse,
  UpdateWorkspaceInput,
  WorkspaceResource,
} from "@/types/workspace";
import { apiFetch } from "./client";

export async function getMyWorkspaces(): Promise<WorkspaceResource[]> {
  if (config.useMock) return Promise.resolve(mockMyWorkspaces);
  const r = await apiFetch<{ data: WorkspaceResource[] }>("/api/my-workspaces");
  return Array.isArray(r) ? r : r.data; // Hỗ trợ cả 2 dạng bọc và không bọc
}

export async function createWorkspace(
  input: CreateWorkspaceInput,
): Promise<WorkspaceResource> {
  if (config.useMock) {
    return Promise.resolve({
      ...mockMyWorkspaces[0],
      id: `ws_mock_${Date.now()}`,
      name: input.name,
      email: input.email,
    });
  }
  const r = await apiFetch<any>("/api/workspaces", {
    method: "POST",
    body: input,
  });
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function getWorkspace(id: string): Promise<WorkspaceResource> {
  if (config.useMock) {
    const m = mockMyWorkspaces.find((w) => w.id === id);
    if (!m) throw new Error("Workspace not found");
    return Promise.resolve(m);
  }
  const r = await apiFetch<any>(`/api/workspaces/${id}`);
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function updateWorkspace(
  id: string,
  input: UpdateWorkspaceInput,
): Promise<WorkspaceResource> {
  if (config.useMock) {
    const m = mockMyWorkspaces.find((w) => w.id === id) ?? mockMyWorkspaces[0];
    return Promise.resolve({ ...m, ...input });
  }
  const r = await apiFetch<any>(`/api/workspaces/${id}`, {
    method: "PUT",
    body: input,
  });
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function getCompanyOptions(): Promise<CompanyOptionsResponse> {
  if (config.useMock) return Promise.resolve(mockCompanyOptions);
  return apiFetch<CompanyOptionsResponse>("/api/options/company-types");
}

export async function createInviteCode(
  workspaceId: string,
  expiresInHours = 48,
): Promise<InvitationCodeResponse> {
  if (config.useMock) {
    return Promise.resolve({
      ivitetation_id: `inv_${Date.now()}`,
      code: "AB12CD",
      expires_at: new Date(Date.now() + expiresInHours * 3600_000).toISOString(),
    });
  }
  return apiFetch<InvitationCodeResponse>(
    `/api/workspaces/${workspaceId}/invite-code`,
    { method: "POST", body: { expires_in_hours: expiresInHours } },
  );
}
