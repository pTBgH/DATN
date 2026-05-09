import { config } from "@/lib/config";
import {
  mockAdminCompanies,
  mockAdminUsers,
  mockPendingJobs,
  mockSectors,
} from "@/mocks/admin";
import type {
  AdminCompanySummary,
  AdminPendingJob,
  AdminUserSummary,
  SectorCategory,
} from "@/types/admin";
import { apiFetch } from "./client";

export async function listPendingJobs(): Promise<AdminPendingJob[]> {
  if (config.useMock) return Promise.resolve(mockPendingJobs);
  const r = await apiFetch<{ data: AdminPendingJob[] }>("/api/admin/jobs");
  return r.data;
}

export async function approveJob(jobId: string): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch(`/api/admin/jobs/${encodeURIComponent(jobId)}/approve`, {
    method: "PATCH",
  });
}

export async function listSectors(): Promise<SectorCategory[]> {
  if (config.useMock) return Promise.resolve(mockSectors);
  const r = await apiFetch<{ data: SectorCategory[] }>(
    "/api/admin/categories/sectors",
  );
  return r.data;
}

export async function createSector(
  input: { name: string; code: string },
): Promise<SectorCategory> {
  if (config.useMock) {
    return Promise.resolve({
      id: Math.max(...mockSectors.map((s) => s.id)) + 1,
      name: input.name,
      code: input.code,
      active: true,
      job_count: 0,
      created_at: new Date().toISOString(),
    });
  }
  return apiFetch<SectorCategory>("/api/admin/categories/sectors", {
    method: "POST",
    body: input,
  });
}

export async function listAdminUsers(): Promise<AdminUserSummary[]> {
  if (config.useMock) return Promise.resolve(mockAdminUsers);
  const r = await apiFetch<{ data: AdminUserSummary[] }>("/api/admin/users");
  return r.data;
}

export async function listAdminCompanies(): Promise<AdminCompanySummary[]> {
  if (config.useMock) return Promise.resolve(mockAdminCompanies);
  const r = await apiFetch<{ data: AdminCompanySummary[] }>(
    "/api/admin/companies",
  );
  return r.data;
}
