import { config } from "@/lib/config";
import { mockMyWorkspaces, mockCompanyOptions, addMockWorkspace } from "@/mocks/workspace";
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
  return r.data;
}

export async function createWorkspace(
  input: CreateWorkspaceInput,
): Promise<WorkspaceResource> {
  if (config.useMock) {
    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const newWorkspace: WorkspaceResource = {
      ...mockMyWorkspaces[0],
      id: `ws_mock_${Date.now()}`,
      name: input.name,
      email: input.email,
      location: input.location || null,
      active_jobs: 0,
      views: 0,
      applications: 0,
      apply_rate: 0,
      plan: "Free",
      usage: 0,
    };
    
    // Add to mock data so getMyWorkspaces returns the new workspace
    addMockWorkspace(newWorkspace);
    
    return Promise.resolve(newWorkspace);
  }
  return apiFetch<WorkspaceResource>("/api/workspaces", {
    method: "POST",
    body: input,
  });
}

export async function getWorkspace(id: string): Promise<WorkspaceResource> {
  if (config.useMock) {
    const m = mockMyWorkspaces.find((w) => w.id === id);
    if (!m) throw new Error("Workspace not found");
    return Promise.resolve(m);
  }
  return apiFetch<WorkspaceResource>(`/api/workspaces/${id}`);
}

export async function updateWorkspace(
  id: string,
  input: UpdateWorkspaceInput,
): Promise<WorkspaceResource> {
  if (config.useMock) {
    const m = mockMyWorkspaces.find((w) => w.id === id) ?? mockMyWorkspaces[0];
    return Promise.resolve({ ...m, ...input });
  }
  return apiFetch<WorkspaceResource>(`/api/workspaces/${id}`, {
    method: "PUT",
    body: input,
  });
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
