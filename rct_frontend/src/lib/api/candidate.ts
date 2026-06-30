import { config } from "@/lib/config";
import { mockApplicationHistory, mockCvs } from "@/mocks/candidate";
import type {
  ApplicationHistoryResponse,
  ApplyJobInput,
  CreateCvInput,
  CvResource,
  HideJobInput,
  SaveJobInput,
} from "@/types/candidate";
import { apiFetch } from "./client";

export async function listResumes(): Promise<CvResource[]> {
  if (config.useMock) return Promise.resolve(mockCvs);
  const r = await apiFetch<{ data: CvResource[] }>("/api/resumes");
  return r.data;
}

export async function createResume(input: CreateCvInput): Promise<CvResource> {
  if (config.useMock) {
    return Promise.resolve({
      ...mockCvs[0],
      cv_id: `cv_mock_${Date.now()}`,
      title: input.title,
      cv_path: input.cv_path,
      is_default: false,
    });
  }
  return apiFetch<CvResource>("/api/resumes", { method: "POST", body: input });
}

export async function setDefaultResume(id: string): Promise<CvResource> {
  if (config.useMock) {
    const c = mockCvs.find((x) => x.cv_id === id);
    if (!c) throw new Error("CV not found");
    return Promise.resolve({ ...c, is_default: true });
  }
  const r = await apiFetch<{ message: string; data: CvResource }>(
    `/api/resumes/${encodeURIComponent(id)}/default`,
    { method: "PATCH" },
  );
  return r.data;
}

export async function deleteResume(id: string): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch<void>(`/api/resumes/${encodeURIComponent(id)}`, {
    method: "DELETE",
  });
}

export async function applyToJob(
  jobId: string,
  input: ApplyJobInput,
): Promise<{ message: string; application_id: string }> {
  if (config.useMock) {
    return Promise.resolve({
      message: "Application created successfully",
      application_id: `app_mock_${Date.now()}`,
    });
  }
  return apiFetch(`/api/jobs/${encodeURIComponent(jobId)}/apply`, {
    method: "POST",
    body: input,
  });
}

export async function getMyApplications(): Promise<ApplicationHistoryResponse> {
  if (config.useMock) return Promise.resolve(mockApplicationHistory);
  return apiFetch<ApplicationHistoryResponse>("/api/my-applications");
}

export async function toggleSavedJob(input: SaveJobInput): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch("/api/interactions/saved-jobs", {
    method: "POST",
    body: input,
  });
}

export async function toggleHiddenJob(input: HideJobInput): Promise<void> {
  if (config.useMock) return Promise.resolve();
  await apiFetch("/api/interactions/hidden-jobs", {
    method: "POST",
    body: input,
  });
}
