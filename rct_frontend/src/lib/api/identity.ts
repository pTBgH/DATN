/**
 * Identity Service client.
 * Routes prefix: /api/recruiters/profile, /api/candidates/profile.
 * Backed by Kong consumer `keycloak-user` (JWT plugin).
 */

import { config } from "@/lib/config";
import type {
  CandidateProfileResource,
  RecruiterFullProfile,
  UpdateCandidateProfileInput,
  UpdateRecruiterProfileInput,
} from "@/types/identity";
import { mockCandidateProfile, mockRecruiterProfile } from "@/mocks/identity";
import { apiFetch } from "./client";

export async function getRecruiterProfile(): Promise<RecruiterFullProfile> {
  if (config.useMock) return Promise.resolve(mockRecruiterProfile);
  const r = await apiFetch<any>("/api/recruiters/profile");
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function updateRecruiterProfile(
  input: UpdateRecruiterProfileInput,
): Promise<RecruiterFullProfile> {
  if (config.useMock) {
    return Promise.resolve({ ...mockRecruiterProfile, ...input });
  }
  const r = await apiFetch<any>("/api/recruiters/profile", {
    method: "PUT",
    body: input,
  });
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}

export async function getCandidateProfile(): Promise<CandidateProfileResource> {
  if (config.useMock) return Promise.resolve(mockCandidateProfile);
  return apiFetch<CandidateProfileResource>("/api/candidates/profile");
}

export async function updateCandidateProfile(
  input: UpdateCandidateProfileInput,
): Promise<CandidateProfileResource> {
  if (config.useMock) {
    return Promise.resolve({ ...mockCandidateProfile, ...input });
  }
  return apiFetch<CandidateProfileResource>("/api/candidates/profile", {
    method: "PUT",
    body: input,
  });
}
