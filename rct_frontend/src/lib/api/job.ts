import { config } from "@/lib/config";
import {
  mockDistrictsByCity,
  mockGeneralOptions,
  mockMetadataCommon,
  mockPublicJobs,
  mockPublicJobsPage,
  mockRecruiterJobs,
  mockRecruiterJobsPage,
} from "@/mocks/job";
import type {
  CommonMetadataResponse,
  DistrictsResponse,
  GeneralOptionsResponse,
  JobInput,
  JobJdResource,
  JobListFilters,
  JobSubJdResource,
  Paginated,
} from "@/types/job";
import { apiFetch } from "./client";

export async function listPublicJobs(
  query: { q?: string; location_id?: number; limit?: number; page?: number } = {},
): Promise<Paginated<JobJdResource>> {
  if (config.useMock) {
    const filtered = mockPublicJobs.filter(
      (j) =>
        !query.q ||
        j.title.toLowerCase().includes(query.q.toLowerCase()) ||
        j.company_name?.toLowerCase().includes(query.q.toLowerCase()),
    );
    return Promise.resolve({
      data: filtered,
      meta: {
        current_page: 1,
        last_page: 1,
        per_page: 20,
        total: filtered.length,
      },
    });
  }
  return apiFetch<Paginated<JobJdResource>>("/api/public/jobs", {
    query: query as Record<string, string | number>,
  });
}

export async function getPublicJobDetail(idOrSlug: string): Promise<JobJdResource> {
  if (config.useMock) {
    const j = mockPublicJobs.find(
      (x) => x.job_id === idOrSlug || x.slug === idOrSlug,
    );
    if (!j) throw new Error("Job not found");
    return Promise.resolve(j);
  }
  return apiFetch<JobJdResource>(`/api/public/jobs/${encodeURIComponent(idOrSlug)}`);
}

export async function getGeneralOptions(): Promise<GeneralOptionsResponse> {
  if (config.useMock) return Promise.resolve(mockGeneralOptions);
  return apiFetch<GeneralOptionsResponse>("/api/options/general");
}

export async function getMetadataCommon(): Promise<CommonMetadataResponse> {
  if (config.useMock) return Promise.resolve(mockMetadataCommon);
  return apiFetch<CommonMetadataResponse>("/api/public/metadata/common");
}

export async function getDistrictsByCity(
  cityId: number,
): Promise<DistrictsResponse> {
  if (config.useMock) {
    return Promise.resolve(
      mockDistrictsByCity[cityId] ?? { city_id: cityId, districts: [] },
    );
  }
  return apiFetch<DistrictsResponse>(
    `/api/public/metadata/districts/${cityId}`,
  );
}

export async function listWorkspaceJobs(
  wsId: string,
  filters: JobListFilters = {},
): Promise<Paginated<JobSubJdResource>> {
  if (config.useMock) return Promise.resolve(mockRecruiterJobsPage);
  const query: Record<string, string | number | undefined> = {
    q: filters.q,
    status: filters.status,
    exp_years: filters.exp_years,
    location_id: filters.location_id,
    sort_by: filters.sort_by,
    page: filters.page,
  };
  // Laravel expects array as job_types[]=1&job_types[]=2
  const url = new URL(
    `${config.apiBaseUrl.replace(/\/$/, "")}/api/workspaces/${wsId}/jobs`,
  );
  for (const [k, v] of Object.entries(query)) {
    if (v !== undefined) url.searchParams.append(k, String(v));
  }
  for (const id of filters.job_types ?? []) url.searchParams.append("job_types[]", String(id));
  for (const id of filters.sectors ?? []) url.searchParams.append("sectors[]", String(id));
  return apiFetch<Paginated<JobSubJdResource>>(url.pathname + url.search);
}

export async function getWorkspaceJob(
  wsId: string,
  jobId: string,
): Promise<JobSubJdResource> {
  if (config.useMock) {
    const j = mockRecruiterJobs.find((x) => x.job_id === jobId);
    if (!j) throw new Error("Job not found");
    return Promise.resolve(j);
  }
  const r = await apiFetch<any>(
    `/api/workspaces/${wsId}/jobs/${encodeURIComponent(jobId)}`,
  );
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function createDraftJob(
  wsId: string,
  input: JobInput,
): Promise<JobSubJdResource> {
  if (config.useMock) return Promise.resolve(mockRecruiterJobs[0]);
  const r = await apiFetch<any>(`/api/workspaces/${wsId}/jobs/draft`, {
    method: "POST",
    body: input,
  });
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function submitNewJob(
  wsId: string,
  input: JobInput,
): Promise<JobSubJdResource> {
  if (config.useMock) return Promise.resolve(mockRecruiterJobs[0]);
  const r = await apiFetch<any>(`/api/workspaces/${wsId}/jobs/submit`, {
    method: "POST",
    body: input,
  });
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function updateJob(
  wsId: string,
  jobId: string,
  input: JobInput,
): Promise<JobSubJdResource> {
  if (config.useMock) return Promise.resolve(mockRecruiterJobs[0]);
  const r = await apiFetch<any>(
    `/api/workspaces/${wsId}/jobs/${encodeURIComponent(jobId)}`,
    { method: "PUT", body: input },
  );
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

/**
 * Status transitions on an existing job:
 *   - submit  : Draft   -> Pending
 *   - archive : Published/Closed -> Archived
 *   - restore : Archived -> Closed
 */
async function patchJobStatus(
  wsId: string,
  jobId: string,
  action: "submit" | "archive" | "restore",
): Promise<JobSubJdResource> {
  if (config.useMock) return Promise.resolve(mockRecruiterJobs[0]);
  const r = await apiFetch<any>(
    `/api/workspaces/${wsId}/jobs/${encodeURIComponent(jobId)}/${action}`,
    { method: "PATCH" },
  );
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export const submitExistingJob = (wsId: string, jobId: string) =>
  patchJobStatus(wsId, jobId, "submit");
export const archiveJob = (wsId: string, jobId: string) =>
  patchJobStatus(wsId, jobId, "archive");
export const restoreJob = (wsId: string, jobId: string) =>
  patchJobStatus(wsId, jobId, "restore");
