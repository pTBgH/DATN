/**
 * Workspace Service — DTOs
 * Source: src/workspace_service/laravel_back/app/Http/Resources/WorkspaceResource.php
 */

export interface WorkspaceResource {
  /** = WorkspaceID */
  id: string;
  name: string;
  logo: string | null;
  permissions: number;
  location: string | null;
  active_jobs: number;
  views: number;
  applications: number;
  apply_rate: number;
  email: string;
  plan: string | null;
  usage: number | null;
}

/**
 * Identity service shape (recruiter profile.workspaces[]).
 * Source: src/identity_service/laravel_back/app/Http/Resources/WorkspaceResource.php
 */
export interface WorkspaceMinimal {
  workspace_id: string;
  email: string;
  member_status: string;
  permissions: string[];
  company: {
    name: string;
    logo: string | null;
    active_jobs: number;
    views: number;
    applications: number;
    apply_rate: number;
  };
  created_at: string;
}

export interface CreateWorkspaceInput {
  name: string;
  email: string;
  location?: string;
  size?: number;
  industry?: number;
  city?: number;
  district?: number;
  logo?: string;
  website?: string;
}

export interface UpdateWorkspaceInput {
  name?: string;
  logo?: string;
  location?: string;
  size?: number;
  city?: number;
  district?: number;
  industry?: number;
  website?: string;
}

export interface CompanyOption {
  id: number;
  name: string;
  code?: string;
}

export interface CompanyOptionsResponse {
  sizes: CompanyOption[];
  industries: CompanyOption[];
}

export interface InvitationCodeResponse {
  /** Note: typo preserved from Laravel controller */
  ivitetation_id: string;
  code: string;
  expires_at: string;
}
