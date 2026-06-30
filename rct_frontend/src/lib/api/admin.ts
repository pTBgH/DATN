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
import { ApiClientError, apiFetch } from "./client";

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

export async function rejectJob(
  jobId: string,
  reason?: string,
): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch(`/api/admin/jobs/${encodeURIComponent(jobId)}/reject`, {
    method: "PATCH",
    body: reason ? { reason } : undefined,
  });
}

export async function listSectors(): Promise<SectorCategory[]> {
  if (config.useMock) return Promise.resolve(mockSectors);
  const r = await apiFetch<unknown>(
    "/api/admin/categories/sectors",
  );
  return readCollection(r).map(normalizeSector);
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
  const r = await apiFetch<unknown>("/api/admin/categories/sectors", {
    method: "POST",
    body: input,
  });
  return normalizeSector(isRecord(r) ? r : {});
}

export async function listAdminUsers(): Promise<AdminUserSummary[]> {
  if (config.useMock) return Promise.resolve(mockAdminUsers);
  try {
    const r = await apiFetch<unknown>("/api/admin/users");
    return readCollection(r).map((item) => item as unknown as AdminUserSummary);
  } catch (error) {
    if (error instanceof ApiClientError && error.status === 404) return [];
    throw error;
  }
}

export async function listAdminCompanies(): Promise<AdminCompanySummary[]> {
  if (config.useMock) return Promise.resolve(mockAdminCompanies);
  try {
    const r = await apiFetch<unknown>("/api/admin/companies");
    return readCollection(r).map((item) => item as unknown as AdminCompanySummary);
  } catch (error) {
    if (error instanceof ApiClientError && error.status === 404) return [];
    throw error;
  }
}

function readCollection(response: unknown): Record<string, unknown>[] {
  const payload = isRecord(response) && Array.isArray(response.data)
    ? response.data
    : response;
  return Array.isArray(payload)
    ? payload.filter(isRecord)
    : [];
}

function normalizeSector(raw: Record<string, unknown>): SectorCategory {
  const id = readNumber(raw, "id") ?? readNumber(raw, "JobSectorID") ?? 0;
  const name =
    readString(raw, "name") ??
    readString(raw, "JobSectorName") ??
    readString(raw, "Name") ??
    "Chưa đặt tên";

  return {
    id,
    name,
    code: readString(raw, "code") ?? readString(raw, "Code") ?? `SECTOR-${id}`,
    active: readBoolean(raw, "active") ?? readBoolean(raw, "IsActive") ?? true,
    job_count: readNumber(raw, "job_count") ?? readNumber(raw, "jobs_count") ?? 0,
    created_at:
      readString(raw, "created_at") ??
      readString(raw, "CreatedAt") ??
      new Date().toISOString(),
  };
}

function readString(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "string" ? value : undefined;
}

function readNumber(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "number" ? value : undefined;
}

function readBoolean(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "boolean" ? value : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
