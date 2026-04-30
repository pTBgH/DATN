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
  return apiFetch<RecruiterFullProfile>("/api/recruiters/profile");
}

export async function updateRecruiterProfile(
  input: UpdateRecruiterProfileInput,
): Promise<RecruiterFullProfile> {
  if (config.useMock) {
    return Promise.resolve({ ...mockRecruiterProfile, ...input });
  }
  return apiFetch<RecruiterFullProfile>("/api/recruiters/profile", {
    method: "PUT",
    body: input,
  });
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
