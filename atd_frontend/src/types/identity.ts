/**
 * Identity Service — DTOs
 *
 * Mirrors src/identity_service/laravel_back/app/Http/Resources/*.php exactly.
 * Field names use snake_case because Laravel Resources transform PascalCase
 * Eloquent attributes before serialization.
 */

import type { WorkspaceMinimal } from "./workspace";

export interface RecruiterResource {
  recruiter_id: string;
  email: string;
  phone_number: string | null;
  user_name: string;
  first_name: string;
  last_name: string;
  avatar?: string | null;
  status_id: number;
  workspaces?: WorkspaceMinimal[];
}

/** GET /api/recruiters/profile — RecruiterController@getMyProfile */
export interface RecruiterFullProfile {
  recruiter_id: string;
  email: string;
  phone_number: string | null;
  user_name: string;
  first_name: string;
  last_name: string;
  avatar: string | null;
  status_id: number;
  workspaces: WorkspaceMinimal[];
}

export interface CandidateProfileResource {
  user_id: string;
  email: string;
  user_name: string | null;
  first_name: string | null;
  last_name: string | null;
  phone_number: string | null;
  sex_id: number | null;
  birth: string | null;
  avatar: string | null;
  experience_years: number | null;
  status_id: number;
  created_at: string;
  updated_at: string;
}

export interface UpdateRecruiterProfileInput {
  user_name?: string;
  phone_number?: string;
  first_name?: string;
  last_name?: string;
}

export interface UpdateCandidateProfileInput {
  user_name?: string;
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  sex_id?: number;
  birth?: string;
  avatar?: string;
  experience_years?: number;
}
